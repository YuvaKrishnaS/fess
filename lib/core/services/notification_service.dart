import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/notification_item.dart';
import 'firebase_service.dart';
import 'local_storage_service.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String _historyBoxName = 'fess_notification_history';
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  Box? _historyBox;

  final Map<String, StreamSubscription> _convoListeners = {};
  StreamSubscription? _conversationsListSub;
  Timer? _streakCheckTimer;
  GlobalKey<NavigatorState>? _navigatorKey;

  bool _initialized = false;

  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    if (_initialized) return;
    _initialized = true;
    _navigatorKey = navigatorKey;

    _historyBox = await Hive.openBox(_historyBoxName);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _startWatchingInbox();
    _startStreakScheduler();
  }

  Box get historyBox {
    if (_historyBox == null || !_historyBox!.isOpen) {
      throw Exception('Notification history box not initialized');
    }
    return _historyBox!;
  }

  List<NotificationItem> getHistory() {
    return historyBox.values
        .map((raw) => NotificationItem.fromMap(Map.from(raw as Map)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  int getUnreadCount() {
    return getHistory().where((n) => !n.isRead).length;
  }

  Future<void> markAsRead(String id) async {
    final raw = historyBox.get(id);
    if (raw == null) return;
    final item = NotificationItem.fromMap(Map.from(raw as Map));
    item.isRead = true;
    await historyBox.put(id, item.toMap());
  }

  Future<void> markAllAsRead() async {
    for (final key in historyBox.keys.toList()) {
      final raw = historyBox.get(key);
      if (raw == null) continue;
      final item = NotificationItem.fromMap(Map.from(raw as Map));
      item.isRead = true;
      await historyBox.put(key, item.toMap());
    }
  }

  Future<void> deleteNotification(String id) async {
    await historyBox.delete(id);
  }

  Future<void> clearAll() async {
    await historyBox.clear();
  }

  Future<void> _persistAndFire({
    required NotificationType type,
    required String title,
    required String body,
    String? peerId,
    String? avatarUrl,
    String? routePath,
    required bool masterEnabled,
    required bool categoryEnabled,
  }) async {
    final item = NotificationItem(
      id: const Uuid().v4(),
      type: type,
      title: title,
      body: body,
      peerId: peerId,
      avatarUrl: avatarUrl,
      routePath: routePath,
      createdAt: DateTime.now(),
    );

    await historyBox.put(item.id, item.toMap());

    if (!masterEnabled || !categoryEnabled) return;

    await _plugin.show(
      id: item.id.hashCode,
      title : title,
      body : body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'fess_default_channel',
          'Fess Notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: item.routePath,
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    final path = response.payload;
    if (path == null || path.isEmpty) return;
    _navigatorKey?.currentContext?.let((ctx) => GoRouter.of(ctx).push(path));
  }

  void _startWatchingInbox() {
    final myId = LocalStorageService.getCachedAnonId();
    if (myId == null) return;

    _conversationsListSub?.cancel();
    _conversationsListSub = FirebaseService.firestore
        .collection('conversations')
        .where('participants', arrayContains: myId)
        .snapshots()
        .listen((snapshot) {
      for (final doc in snapshot.docs) {
        _attachMessageListener(doc.id, myId);
      }
    });
  }

  void _attachMessageListener(String convoId, String myId) {
    if (_convoListeners.containsKey(convoId)) return;

    DateTime lastSeen = DateTime.now();

    _convoListeners[convoId] = FirebaseService.firestore
        .collection('conversations')
        .doc(convoId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isEmpty) return;
      final msgDoc = snapshot.docs.first;
      final data = msgDoc.data();
      final senderId = data['senderId'] as String?;
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

      if (senderId == null || senderId == myId) return;
      if (createdAt == null || !createdAt.isAfter(lastSeen)) return;
      lastSeen = createdAt;

      final settings = await _readNotificationSettings();
      final profile = await FirebaseService.firestore
          .collection('public_profiles')
          .doc(senderId)
          .get();
      final username = profile.data()?['username'] as String? ?? 'anon';

      await _persistAndFire(
        type: NotificationType.chatMessage,
        title: '@$username',
        body: (data['text'] as String? ?? '').trim(),
        peerId: senderId,
        routePath: '/dm/$senderId',
        masterEnabled: settings.$1,
        categoryEnabled: settings.$2,
      );
    });
  }

  void _startStreakScheduler() {
    _streakCheckTimer?.cancel();
    _streakCheckTimer = Timer.periodic(const Duration(minutes: 30), (_) => _checkStreakRisk());
    _checkStreakRisk();
  }

  Future<void> _checkStreakRisk() async {
    final now = DateTime.now();
    if (now.hour != 20) return;

    final lastActivityMillis = LocalStorageService.appBox.get('last_activity_at') as int?;
    if (lastActivityMillis == null) return;

    final lastActivity = DateTime.fromMillisecondsSinceEpoch(lastActivityMillis);
    final hoursSince = now.difference(lastActivity).inHours;
    if (hoursSince < 20) return;

    final alreadyFiredKey = 'streak_risk_fired_${now.year}_${now.month}_${now.day}';
    if (LocalStorageService.appBox.get(alreadyFiredKey) == true) return;

    final settings = await _readNotificationSettings(streak: true);

    await _persistAndFire(
      type: NotificationType.streakRisk,
      title: 'Your streak is at risk',
      body: 'You have not been active today. Do something now to keep your streak alive.',
      routePath: '/home',
      masterEnabled: settings.$1,
      categoryEnabled: settings.$2,
    );

    await LocalStorageService.appBox.put(alreadyFiredKey, true);
  }

  Future<void> fireStreakMilestone(int days) async {
    final settings = await _readNotificationSettings(streak: true);
    await _persistAndFire(
      type: NotificationType.streakMilestone,
      title: '$days day streak!',
      body: 'You have kept your streak alive for $days days. Keep going.',
      routePath: '/home',
      masterEnabled: settings.$1,
      categoryEnabled: settings.$2,
    );
  }

  Future<(bool, bool)> _readNotificationSettings({bool streak = false}) async {
    final master = LocalStorageService.getNotificationsEnabled();
    final category = streak
        ? LocalStorageService.getStreakNotificationsEnabled()
        : LocalStorageService.getChatNotificationsEnabled();
    return (master, category);
  }

  void recordActivity() {
    LocalStorageService.appBox.put('last_activity_at', DateTime.now().millisecondsSinceEpoch);
  }

  void dispose() {
    for (final sub in _convoListeners.values) {
      sub.cancel();
    }
    _convoListeners.clear();
    _conversationsListSub?.cancel();
    _streakCheckTimer?.cancel();
  }
}

extension _Let<T> on T {
  void let(void Function(T) fn) => fn(this);
}
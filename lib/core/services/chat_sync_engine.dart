import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/local_message.dart';
import 'firebase_service.dart';

class ChatSyncEngine {
  ChatSyncEngine._();
  static final ChatSyncEngine instance = ChatSyncEngine._();

  final Map<String, Box> _convoBoxes = {};
  final Map<String, StreamController<List<LocalMessage>>> _controllers = {};
  final Map<String, StreamSubscription> _remoteSubs = {};
  StreamSubscription? _connectivitySub;
  bool _flushing = false;

  Future<Box> _boxFor(String convoId) async {
    if (_convoBoxes.containsKey(convoId)) return _convoBoxes[convoId]!;
    final box = await Hive.openBox('chat_$convoId');
    _convoBoxes[convoId] = box;
    return box;
  }

  Stream<List<LocalMessage>> watchConversation(String convoId, String myId) {
    if (_controllers.containsKey(convoId)) {
      return _controllers[convoId]!.stream;
    }

    final controller = StreamController<List<LocalMessage>>.broadcast();
    _controllers[convoId] = controller;

    _boxFor(convoId).then((box) {
      _emit(convoId);
      _attachRemoteListener(convoId, myId);
    });

    _connectivitySub ??= Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) flushAllQueues();
    });

    return controller.stream;
  }

  void _emit(String convoId) {
    final box = _convoBoxes[convoId];
    if (box == null) return;
    final messages = box.values
        .map((raw) => LocalMessage.fromMap(Map.from(raw as Map)))
        .where((m) => !(m.isDeleteOp))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _controllers[convoId]?.add(messages);
  }

  void _attachRemoteListener(String convoId, String myId) {
    if (_remoteSubs.containsKey(convoId)) return;

    _remoteSubs[convoId] = FirebaseService.firestore
        .collection('conversations')
        .doc(convoId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) async {
      final box = await _boxFor(convoId);
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final remote = LocalMessage(
          id: doc.id,
          convoId: convoId,
          senderId: data['senderId'] as String,
          text: data['text'] as String? ?? '',
          createdAt: createdAt,
          isDeleted: data['isDeleted'] as bool? ?? false,
          reactions: Map<String, String>.from(data['reactions'] as Map? ?? {}),
          syncState: MessageSyncState.synced,
        );

        final existingRaw = box.get(doc.id);
        if (existingRaw != null) {
          final existing = LocalMessage.fromMap(Map.from(existingRaw as Map));
          if (existing.syncState == MessageSyncState.pending) continue;
        }

        await box.put(doc.id, remote.toMap());
      }
      _emit(convoId);
    });
  }

  Future<void> sendMessage(String convoId, String senderId, String text) async {
    final box = await _boxFor(convoId);
    final id = const Uuid().v4();
    final localMsg = LocalMessage(
      id: id,
      convoId: convoId,
      senderId: senderId,
      text: text,
      createdAt: DateTime.now(),
      syncState: MessageSyncState.pending,
    );

    await box.put(id, localMsg.toMap());
    _emit(convoId);
    await _flushMessage(convoId, id);
  }

  Future<void> editMessage(String convoId, String messageId, String newText) async {
    final box = await _boxFor(convoId);
    final raw = box.get(messageId);
    if (raw == null) return;
    final msg = LocalMessage.fromMap(Map.from(raw as Map));
    final updated = msg.copyWith(text: newText, syncState: MessageSyncState.pending);
    await box.put(messageId, updated.toMap());
    _emit(convoId);
    await _flushMessage(convoId, messageId);
  }

  Future<void> deleteMessage(String convoId, String messageId) async {
    final box = await _boxFor(convoId);
    final raw = box.get(messageId);
    if (raw == null) return;
    final msg = LocalMessage.fromMap(Map.from(raw as Map));
    final updated = msg.copyWith(isDeleted: true, syncState: MessageSyncState.pending);
    await box.put(messageId, updated.toMap());
    _emit(convoId);
    await _flushMessage(convoId, messageId);
  }

  Future<void> toggleReaction(String convoId, String messageId, String userId, String emoji) async {
    final box = await _boxFor(convoId);
    final raw = box.get(messageId);
    if (raw == null) return;
    final msg = LocalMessage.fromMap(Map.from(raw as Map));
    final reactions = Map<String, String>.from(msg.reactions);
    if (reactions[userId] == emoji) {
      reactions.remove(userId);
    } else {
      reactions[userId] = emoji;
    }
    final updated = msg.copyWith(reactions: reactions, syncState: MessageSyncState.pending);
    await box.put(messageId, updated.toMap());
    _emit(convoId);
    await _flushMessage(convoId, messageId);
  }

  Future<void> _flushMessage(String convoId, String messageId) async {
    final box = await _boxFor(convoId);
    final raw = box.get(messageId);
    if (raw == null) return;
    final msg = LocalMessage.fromMap(Map.from(raw as Map));
    if (msg.syncState != MessageSyncState.pending) return;

    final docRef = FirebaseService.firestore
        .collection('conversations')
        .doc(convoId)
        .collection('messages')
        .doc(messageId);

    try {
      final exists = (await docRef.get()).exists;
      if (!exists) {
        await docRef.set({
          'senderId': msg.senderId,
          'text': msg.text,
          'createdAt': Timestamp.fromDate(msg.createdAt),
          'isDeleted': msg.isDeleted,
          'reactions': msg.reactions,
        });
      } else {
        await docRef.update({
          'text': msg.text,
          'isDeleted': msg.isDeleted,
          'reactions': msg.reactions,
        });
      }

      await FirebaseService.firestore.collection('conversations').doc(convoId).set({
        'lastMessage': msg.isDeleted ? 'Message deleted' : msg.text,
        'lastMessageAt': Timestamp.fromDate(msg.createdAt),
        'lastSenderId': msg.senderId,
      }, SetOptions(merge: true));

      final synced = msg.copyWith(syncState: MessageSyncState.synced);
      await box.put(messageId, synced.toMap());
    } catch (_) {
      final failed = msg.copyWith(syncState: MessageSyncState.failed);
      await box.put(messageId, failed.toMap());
    }
    _emit(convoId);
  }

  Future<void> retryMessage(String convoId, String messageId) async {
    final box = await _boxFor(convoId);
    final raw = box.get(messageId);
    if (raw == null) return;
    final msg = LocalMessage.fromMap(Map.from(raw as Map));
    final pending = msg.copyWith(syncState: MessageSyncState.pending);
    await box.put(messageId, pending.toMap());
    _emit(convoId);
    await _flushMessage(convoId, messageId);
  }

  Future<void> flushAllQueues() async {
    if (_flushing) return;
    _flushing = true;
    try {
      for (final entry in _convoBoxes.entries) {
        final convoId = entry.key;
        final box = entry.value;
        for (final key in box.keys.toList()) {
          final raw = box.get(key);
          if (raw == null) continue;
          final msg = LocalMessage.fromMap(Map.from(raw as Map));
          if (msg.syncState == MessageSyncState.pending || msg.syncState == MessageSyncState.failed) {
            await _flushMessage(convoId, msg.id);
          }
        }
      }
    } finally {
      _flushing = false;
    }
  }

  void disposeConversation(String convoId) {
    _remoteSubs[convoId]?.cancel();
    _remoteSubs.remove(convoId);
    _controllers[convoId]?.close();
    _controllers.remove(convoId);
  }
}
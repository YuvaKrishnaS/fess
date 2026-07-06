import 'package:hive/hive.dart';

enum NotificationType { chatMessage, streakRisk, streakMilestone, reaction, systemAnnouncement }

class NotificationItem {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final String? peerId;
  final String? avatarUrl;
  final String? routePath;
  final DateTime createdAt;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.peerId,
    this.avatarUrl,
    this.routePath,
    required this.createdAt,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'title': title,
    'body': body,
    'peerId': peerId,
    'avatarUrl': avatarUrl,
    'routePath': routePath,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'isRead': isRead,
  };

  factory NotificationItem.fromMap(Map map) {
    return NotificationItem(
      id: map['id'] as String,
      type: NotificationType.values.firstWhere(
            (t) => t.name == map['type'],
        orElse: () => NotificationType.systemAnnouncement,
      ),
      title: map['title'] as String,
      body: map['body'] as String,
      peerId: map['peerId'] as String?,
      avatarUrl: map['avatarUrl'] as String?,
      routePath: map['routePath'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      isRead: map['isRead'] as bool? ?? false,
    );
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';

// MessageSource tells us which collection this message belongs to.
// World -> world_message/{messageId}
// Dm -> dm_messages/{conversationId}/messages/{messageId}
enum MessageSource { world, dm }

class ChatMessageModel {
  final String messageId;
  final String authorId;          //anonId of sender
  final String authorUsername;    // denormalized from public_profiles
  final Map<String, dynamic> authorAvatarConfig;
  final String text;
  final DateTime createdAt;
  final bool isDeleted;
  final MessageSource source;

  // World-only: emoji reactions map e.g. {"🔥": 12, "💀": 3}
  final Map<String, int> reactions;

  // DM-only: list of anonIds who have seen this message
  final List<String> readBy;

  const ChatMessageModel({
    required this.messageId,
    required this.authorId,
    required this.authorUsername,
    required this.authorAvatarConfig,
    required this.text,
    required this.createdAt,
    this.isDeleted = false,
    required this.source,
    this.reactions = const {},
    this.readBy = const [],
  });

  // Firestore deserialization

  factory ChatMessageModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc,
      MessageSource source,
      ) {
    final data = doc.data()!;
    return ChatMessageModel(
      messageId: doc.id,
      authorId: data['authorId'] as String? ?? '',
      authorUsername: data['authorUsername'] as String? ?? 'anon',
      authorAvatarConfig: Map<String, dynamic>.from(
          (data['authorAvatarConfig'] as Map?) ?? {},
      ),
      text: data['text'] as String? ?? '',
      createdAt: (data['createAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDeleted: data['isDeleted'] as bool? ?? false,
      source: source,
      reactions: Map<String, int>.from(
          (data ['reactions'] as Map?)
              ?.map((k, v) => MapEntry(k as String, (v as num).toInt())) ??
              {}
      ),
      readBy: List<String>.from((data['readBy'] as List?) ?? [])
    );
  }

  // Firestore Sserialixation (for writes)

  Map<String, dynamic> toFirestore() {
    return {
      'authorId': authorId,
      'authorUsername': authorUsername,
      'authorAvatarConfig': authorAvatarConfig,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'isDeleted': isDeleted,
      if (source == MessageSource.world) 'reactions': reactions,
      if (source == MessageSource.dm) 'readBy': readBy,
    };
  }

  // copyWith

  ChatMessageModel copyWith ({
    bool? isDeleted,
    Map<String, int>? reactions,
    List<String>? readBy,
    String? text
  }) {
    return ChatMessageModel(
      messageId: messageId,
      authorId: authorId,
      authorUsername: authorUsername,
      authorAvatarConfig: authorAvatarConfig,
      text: text ?? this.text,
      createdAt: createdAt,
      isDeleted: isDeleted ?? this.isDeleted,
      source: source,
      reactions: reactions ?? this.reactions,
      readBy: readBy ?? this.readBy
    );
  }

  // Helpers

  /// Whether this message has been seen by a given user
  bool isReadBy(String anonId) => readBy.contains(anonId);

  /// Relative timestamp string - "just now", "2m ago", "3h ago", "Mon"
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[createdAt.weekday - 1];
    }
    return '${createdAt.day}/${createdAt.month}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
        other is ChatMessageModel && other.messageId == messageId;

  @override
  int get hashCode => messageId.hashCode;
}
import 'package:cloud_firestore/cloud_firestore.dart';

class DmConversationModel {
  final String conversationId;       // "{smallerId}_{largerId}" - deterministic
  final List<String> participantIds; // exactly 2 anonIds
  final Map<String, dynamic> participantProfiles;
  // ^ shape: { anonId: { username: "...", avatarConfig: {...} } }

  final String lastMessage;          // preview text
  final DateTime? lastMessageAt;
  final String lastMessageSenderId;  // anonId of last sender
  final Map<String, int> unreadCount;
  // ^ shape: { anonId: unreadCount } — each participant's unread

  final DateTime? createdAt;

  const DmConversationModel({
    required this.conversationId,
    required this.participantIds,
    required this.participantProfiles,
    required this.lastMessage,
    this.lastMessageAt,
    required this.lastMessageSenderId,
    required this.unreadCount,
    this.createdAt,
  });

  //  Firestore deserialization

  factory DmConversationModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data()!;
    return DmConversationModel(
      conversationId: doc.id,
      participantIds: List<String>.from(
        (data['participantIds'] as List?) ?? [],
      ),
      participantProfiles: Map<String, dynamic>.from(
        (data['participantProfiles'] as Map?) ?? {},
      ),
      lastMessage: data['lastMessage'] as String? ?? '',
      lastMessageAt:
      (data['lastMessageAt'] as Timestamp?)?.toDate(),
      lastMessageSenderId: data['lastMessageSenderId'] as String? ?? '',
      unreadCount: Map<String, int>.from(
        (data['unreadCount'] as Map?)
            ?.map((k, v) => MapEntry(k as String, (v as num).toInt())) ??
            {},
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  // Firestore serialization

  Map<String, dynamic> toFirestore() {
    return {
      'participantIds': participantIds,
      'participantProfiles': participantProfiles,
      'lastMessage': lastMessage,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSenderId': lastMessageSenderId,
      'unreadCount': unreadCount,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // copyWith

  DmConversationModel copyWith({
    String? lastMessage,
    DateTime? lastMessageAt,
    String? lastMessageSenderId,
    Map<String, int>? unreadCount,
    Map<String, dynamic>? participantProfiles,
  }) {
    return DmConversationModel(
      conversationId: conversationId,
      participantIds: participantIds,
      participantProfiles:
      participantProfiles ?? this.participantProfiles,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageSenderId:
      lastMessageSenderId ?? this.lastMessageSenderId,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt,
    );
  }

  // Helpers

  /// Build deterministic conversation ID from any two anonIds.
  static String buildId(String anonIdA, String anonIdB) {
    final sorted = [anonIdA, anonIdB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  /// Get the OTHER participant's anonId (not the current user).
  String otherParticipantId(String myAnonId) {
    return participantIds.firstWhere(
          (id) => id != myAnonId,
      orElse: () => '',
    );
  }

  /// Get other participant's username for display.
  String otherUsername(String myAnonId) {
    final otherId = otherParticipantId(myAnonId);
    if (otherId.isEmpty) return 'anon';
    final profile = participantProfiles[otherId] as Map?;
    return profile?['username'] as String? ?? 'anon';
  }

  /// Get other participant's avatarConfig map.
  Map<String, dynamic> otherAvatarConfig(String myAnonId) {
    final otherId = otherParticipantId(myAnonId);
    if (otherId.isEmpty) return {};
    final profile = participantProfiles[otherId] as Map?;
    return Map<String, dynamic>.from(
      (profile?['avatarConfig'] as Map?) ?? {},
    );
  }

  /// How many unread messages for a given user.
  int unreadFor(String anonId) => unreadCount[anonId] ?? 0;

  /// Whether the last message was sent by ME.
  bool isMine(String myAnonId) => lastMessageSenderId == myAnonId;

  /// Relative timestamp (same helper as ChatMessageModel).
  String get timeAgo {
    if (lastMessageAt == null) return '';
    final diff = DateTime.now().difference(lastMessageAt!);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${lastMessageAt!.day}/${lastMessageAt!.month}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is DmConversationModel &&
              other.conversationId == conversationId;

  @override
  int get hashCode => conversationId.hashCode;
}
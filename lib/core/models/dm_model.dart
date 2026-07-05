import 'package:cloud_firestore/cloud_firestore.dart';

enum DmMessageStatus { sending, sent, failed }

class DmReplyTo {
  final String messageId;
  final String senderId;
  final String text;

  const DmReplyTo({
    required this.messageId,
    required this.senderId,
    required this.text,
  });

  factory DmReplyTo.fromMap(Map<String, dynamic> map) {
    return DmReplyTo(
      messageId: map['messageId'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      text: map['text'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'messageId': messageId,
    'senderId': senderId,
    'text': text,
  };
}

class DmMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final bool isEdited;
  final bool isDeleted;
  final DmReplyTo? replyTo;
  final Map<String, String> reactions;
  final DmMessageStatus status;

  const DmMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.isEdited = false,
    this.isDeleted = false,
    this.replyTo,
    this.reactions = const {},
    this.status = DmMessageStatus.sent,
  });

  factory DmMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final replyMap = data['replyTo'] as Map<String, dynamic>?;
    final reactionsMap = data['reactions'] as Map<String, dynamic>?;
    final ts = data['createdAt'] as Timestamp?;
    return DmMessage(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt: ts?.toDate() ?? DateTime.now(),
      isEdited: data['isEdited'] as bool? ?? false,
      isDeleted: data['isDeleted'] as bool? ?? false,
      replyTo: replyMap != null ? DmReplyTo.fromMap(replyMap) : null,
      reactions: reactionsMap != null
          ? reactionsMap.map((k, v) => MapEntry(k, v as String))
          : const {},
      status: DmMessageStatus.sent,
    );
  }

  DmMessage copyWith({
    DmMessageStatus? status,
    String? id,
    Map<String, String>? reactions,
  }) {
    return DmMessage(
      id: id ?? this.id,
      senderId: senderId,
      text: text,
      createdAt: createdAt,
      isEdited: isEdited,
      isDeleted: isDeleted,
      replyTo: replyTo,
      reactions: reactions ?? this.reactions,
      status: status ?? this.status,
    );
  }

  bool isReadBy(DateTime? peerLastRead) {
    if (peerLastRead == null) return false;
    return createdAt.isBefore(peerLastRead) ||
        createdAt.isAtSameMomentAs(peerLastRead);
  }
}

class DmConversation {
  final String id;
  final List<String> participants;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastSenderId;
  final Map<String, DateTime> lastRead;
  final List<String> pinnedBy;
  final Map<String, DateTime> typingUsers;

  const DmConversation({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.lastMessageAt,
    this.lastSenderId,
    this.lastRead = const {},
    this.pinnedBy = const [],
    this.typingUsers = const {},
  });

  factory DmConversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final lastReadMap = data['lastRead'] as Map<String, dynamic>?;
    final typingMap = data['typingUsers'] as Map<String, dynamic>?;
    final pinned = data['pinnedBy'] as List<dynamic>?;
    return DmConversation(
      id: doc.id,
      participants: List<String>.from(data['participants'] as List? ?? []),
      lastMessage: data['lastMessage'] as String?,
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      lastSenderId: data['lastSenderId'] as String?,
      lastRead: lastReadMap != null
          ? lastReadMap.map(
            (k, v) => MapEntry(k, (v as Timestamp).toDate()),
      )
          : const {},
      pinnedBy: pinned != null ? List<String>.from(pinned) : const [],
      typingUsers: typingMap != null
          ? typingMap.map(
            (k, v) => MapEntry(k, (v as Timestamp).toDate()),
      )
          : const {},
    );
  }

  String otherParticipant(String myId) =>
      participants.firstWhere((p) => p != myId, orElse: () => '');

  bool isUnreadFor(String myId) {
    if (lastMessageAt == null || lastSenderId == myId) return false;
    final myLastRead = lastRead[myId];
    if (myLastRead == null) return true;
    return lastMessageAt!.isAfter(myLastRead);
  }

  bool isPinnedFor(String myId) => pinnedBy.contains(myId);

  bool peerIsTyping(String peerId) {
    final ts = typingUsers[peerId];
    if (ts == null) return false;
    return DateTime.now().difference(ts).inSeconds < 6;
  }
}
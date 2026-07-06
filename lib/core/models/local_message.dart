enum MessageSyncState { synced, pending, failed }

class LocalMessage {
  final String id;
  final String convoId;
  final String senderId;
  String text;
  final DateTime createdAt;
  bool isDeleted;
  Map<String, String> reactions;
  MessageSyncState syncState;
  final bool isEdit;
  final bool isReactionUpdate;
  final bool isDeleteOp;

  LocalMessage({
    required this.id,
    required this.convoId,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.isDeleted = false,
    Map<String, String>? reactions,
    this.syncState = MessageSyncState.pending,
    this.isEdit = false,
    this.isReactionUpdate = false,
    this.isDeleteOp = false,
  }) : reactions = reactions ?? {};

  Map<String, dynamic> toMap() => {
    'id': id,
    'convoId': convoId,
    'senderId': senderId,
    'text': text,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'isDeleted': isDeleted,
    'reactions': reactions,
    'syncState': syncState.name,
  };

  factory LocalMessage.fromMap(Map map) {
    return LocalMessage(
      id: map['id'] as String,
      convoId: map['convoId'] as String,
      senderId: map['senderId'] as String,
      text: map['text'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      isDeleted: map['isDeleted'] as bool? ?? false,
      reactions: Map<String, String>.from(map['reactions'] as Map? ?? {}),
      syncState: MessageSyncState.values.firstWhere(
            (s) => s.name == map['syncState'],
        orElse: () => MessageSyncState.synced,
      ),
    );
  }

  LocalMessage copyWith({
    String? text,
    bool? isDeleted,
    Map<String, String>? reactions,
    MessageSyncState? syncState,
  }) {
    return LocalMessage(
      id: id,
      convoId: convoId,
      senderId: senderId,
      text: text ?? this.text,
      createdAt: createdAt,
      isDeleted: isDeleted ?? this.isDeleted,
      reactions: reactions ?? this.reactions,
      syncState: syncState ?? this.syncState,
    );
  }
}
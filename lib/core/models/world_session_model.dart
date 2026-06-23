import 'package:cloud_firestore/cloud_firestore.dart';

class WorldSessionModel {
  final String sessionId;
  final List<String> participantIds; // [anonId1, anonId2]
  final Map<String, dynamic> participantProfiles; // {anonId: {username, avatarConfig}}
  final String moodA; // mood of participantIds[0]
  final String moodB; // mood of participantIds[1]
  final DateTime startedAt;
  final DateTime expiresAt; // startedAt + 5 min
  final String status; // 'active' | 'ended' | 'skipped'
  final String? endedBy; // anonId of whoever skipped; null if timer

  const WorldSessionModel({
    required this.sessionId,
    required this.participantIds,
    required this.participantProfiles,
    required this.moodA,
    required this.moodB,
    required this.startedAt,
    required this.expiresAt,
    required this.status,
    this.endedBy,
  });

  factory WorldSessionModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snap) {
    final d = snap.data()!;
    return WorldSessionModel(
      sessionId: snap.id,
      participantIds: List<String>.from(d['participantIds'] ?? []),
      participantProfiles:
      Map<String, dynamic>.from(d['participantProfiles'] ?? {}),
      moodA: d['moodA'] as String? ?? '',
      moodB: d['moodB'] as String? ?? '',
      startedAt: (d['startedAt'] as Timestamp).toDate(),
      expiresAt: (d['expiresAt'] as Timestamp).toDate(),
      status: d['status'] as String? ?? 'ended',
      endedBy: d['endedBy'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'sessionId': sessionId,
    'participantIds': participantIds,
    'participantProfiles': participantProfiles,
    'moodA': moodA,
    'moodB': moodB,
    'startedAt': Timestamp.fromDate(startedAt),
    'expiresAt': Timestamp.fromDate(expiresAt),
    'status': status,
    'endedBy': endedBy,
  };

  // Seconds remaining from now
  int get secondsRemaining {
    final diff = expiresAt.difference(DateTime.now()).inSeconds;
    return diff < 0 ? 0 : diff;
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class WorldMessageModel {
  final String messageId;
  final String senderAnonId;
  final String text;
  final DateTime sentAt;

  const WorldMessageModel({
    required this.messageId,
    required this.senderAnonId,
    required this.text,
    required this.sentAt,
  });

  factory WorldMessageModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snap) {
    final d = snap.data()!;
    return WorldMessageModel(
      messageId: snap.id,
      senderAnonId: d['senderAnonId'] as String? ?? '',
      text: d['text'] as String? ?? '',
      sentAt: (d['sentAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'senderAnonId' : senderAnonId,
    'text': text,
    'sentAt': Timestamp.fromDate(sentAt)
  };
}
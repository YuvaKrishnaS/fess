import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart';

class DmConversation {
  final String id;
  final List<String> participants;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastSenderId;
  final Map<String, int> unreadCounts;

  const DmConversation({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.lastMessageAt,
    this.lastSenderId,
    this.unreadCounts = const {},
  });

  factory DmConversation.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final raw = (d['unreadCounts'] as Map<String, dynamic>?) ?? {};
    return DmConversation(
      id: doc.id,
      participants: List<String>.from(d['participants'] ?? []),
      lastMessage: d['lastMessage'] as String?,
      lastMessageAt: (d['lastMessageAt'] as Timestamp?)?.toDate(),
      lastSenderId: d['lastSenderId'] as String?,
      unreadCounts: raw.map((k, v) => MapEntry(k, (v as num).toInt()))
    );
  }

  int unreadFor(String anonId) => unreadCounts[anonId] ?? 0;

  String otherParticipant(String myId) =>
      participants.firstWhere((p) => p != myId, orElse: () => '');
}

class DmMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final DateTime? readAt;

  const DmMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.readAt,
  });

  bool get isRead => readAt != null;

  factory DmMessage.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return DmMessage(
      id: doc.id,
      senderId: d['senderId'] as String? ?? '',
      text: d['text'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readAt: (d['readAt'] as Timestamp?)?.toDate(),
    );
  }
}
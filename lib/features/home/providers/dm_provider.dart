import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/dm_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/local_storage_service.dart';
import 'feed_provider.dart';

// Deterministic conversation ID

String conversationId(String a, String b) {
  final sorted = [a, b]..sort();
  return '${sorted[0]}_${sorted[1]}';
}

// Inbox: real-time streak of all conversation for current user

final dmInboxProvider =
StreamProvider<List<DmConversation>>((ref) async* {
  final anonId = await ref.watch(currentAnonIdProvider.future);
  if (anonId == null) {
    yield [];
    return;
  }

  yield* FirebaseService.firestore
      .collection('conversations')
      .where('participants', arrayContains: anonId)
      .orderBy('lastMessageAt', descending: true)
      .snapshots()
      .map((snap) =>
      snap.docs.map(DmConversation.fromFirestore).toList());
});

// Total unread count across all conversations

final totalUnreadProvider = Provider<int>((ref) {
  final inbox = ref.watch(dmInboxProvider);
  final anonId = LocalStorageService.getCachedAnonId();
  if (anonId == null) return 0;
  return inbox.when(
    data: (convos) =>
        convos.fold(0, (sum, c) => sum + c.unreadFor(anonId)),
    loading: () => 0,
    error: (_, __) => 0
  );
});

// Single conversation messages: real-time stream

final dmMessageProvider = StreamProvider.family<List<DmMessage>, String>((ref, convoId) {
  return FirebaseService.firestore
      .collection('conversations')
      .doc(convoId)
      .collection('messages')
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((snap) => snap.docs.map(DmMessage.fromFirestore).toList());
});

// Peer profile for conversation header

final dmPeerProfileProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, peerId) async {
  if (peerId.isEmpty) return null;
  try {
    final doc = await FirebaseService.firestore
        .collection('public_profiles')
        .doc(peerId)
        .get();
    return doc.data();
  } catch (e) {
    debugPrint('[dmPeerProfile] $e');
    return null;
  }
});

// Send Messages

class DmSendNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  Future<bool> send({
    required String peerId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    final myId = LocalStorageService.getCachedAnonId();
    if (myId == null) return false;

    state = true;
    final convoId = conversationId(myId, peerId);
    final convoRef = FirebaseService.firestore.collection('conversations').doc(convoId);

    try {
      final batch = FirebaseService.firestore.batch();

      // Upsert conversation doc
      batch.set(
        convoRef,
        {
          'participants': [myId, peerId],
          'lastMessage': trimmed,
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastSenderId': myId,
          // increment peer unread, reset mine to 0
          'unreadCounts.$peerId': FieldValue.increment(1),
          'unreadCounts.$myId': 0,
        },
        SetOptions(merge: true),
      );

      // Add message
      final msgRef = convoRef.collection('messages').doc();
      batch.set(msgRef, {
        'senderId': myId,
        'text': trimmed,
        'createAt': FieldValue.serverTimestamp(),
        'readAt': null,
      });

      await batch.commit();
      state = false;
      return true;
    } catch (e) {
      debugPrint('[DmSend] $e');
      state = false;
      return false;
    }
  }
}

final dmSendProvider = NotifierProvider<DmSendNotifier, bool>(DmSendNotifier.new);

// Mark conversation as read

Future<void> markConversationRead(String convoId, String myId) async {
  try {
    await FirebaseService.firestore
        .collection('conversations')
        .doc(convoId)
        .update({'unreadCounts.$myId': 0});

    // Mark all unread messages from peer as read
    final unread = await FirebaseService.firestore
        .collection('coversations')
        .doc(convoId)
        .collection('messages')
        .where('senderId', isNotEqualTo: myId)
        .where('readAt', isNull: true)
        .get();

    if (unread.docs.isEmpty) return;

    final batch = FirebaseService.firestore.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'readAt': FieldValue.serverTimestamp()});
    }
    await batch.commit();
  } catch (e) {
    debugPrint('[markRead] $e');
  }
}


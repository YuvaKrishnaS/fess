import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/dm_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/local_storage_service.dart';
import 'feed_provider.dart';

// ─── Conversation ID ───────────────────────────────────────────────────────────
String conversationId(String a, String b) {
  final sorted = [a, b]..sort();
  return '${sorted[0]}_${sorted[1]}';
}

// ─── Global Unread Badge ───────────────────────────────────────────────────────
final totalUnreadNotifier = ValueNotifier<int>(0);

// ─── Active Conversation Guard ─────────────────────────────────────────────────
// Tracks whichever convoId is currently open. Null when not in a chat screen.
final activeConversationIdProvider = StateProvider<String?>((ref) => null);

// ─── Inbox Stream ──────────────────────────────────────────────────────────────
final dmInboxProvider = StreamProvider<List<DmConversation>>((ref) async* {
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
      .map((snap) {
    final convos = snap.docs.map(DmConversation.fromFirestore).toList();
    final total =
    convos.fold<int>(0, (sum, c) => sum + c.unreadFor(anonId));
    totalUnreadNotifier.value = total;
    return convos;
  });
});

// ─── Dynamic Message Limit (Pagination) ───────────────────────────────────────
// Instead of merging two lists, we just expand the Firestore window reactively.
final dmMessageLimitProvider =
StateProvider.family<int, String>((ref, convoId) => 25);

// ─── Messages Stream ───────────────────────────────────────────────────────────
// descending: true + reverse: true on the ListView = naturally bottom-anchored.
final dmMessagesProvider =
StreamProvider.family<List<DmMessage>, String>((ref, convoId) {
  if (convoId.isEmpty) return const Stream.empty();
  final limit = ref.watch(dmMessageLimitProvider(convoId));
  return FirebaseService.firestore
      .collection('conversations')
      .doc(convoId)
      .collection('messages')
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((snap) => snap.docs.map(DmMessage.fromFirestore).toList());
});

// ─── Peer Profile ──────────────────────────────────────────────────────────────
final dmPeerProfileProvider =
FutureProvider.family<Map<String, dynamic>?, String>((ref, peerId) async {
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

// ─── Send / Edit / Delete Notifier ────────────────────────────────────────────
class DmSendNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  Future<bool> send({
    required String peerId,
    required String text,
    DmReplyTo? replyTo,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    final myId = LocalStorageService.getCachedAnonId();
    if (myId == null) return false;

    state = true;
    final convoId = conversationId(myId, peerId);
    final convoRef =
    FirebaseService.firestore.collection('conversations').doc(convoId);

    try {
      final msgRef = convoRef.collection('messages').doc();
      final msgData = <String, dynamic>{
        'senderId': myId,
        'text': trimmed,
        'createdAt': FieldValue.serverTimestamp(),
        'readAt': null,
        'isEdited': false,
        'isDeleted': false,
      };
      if (replyTo != null) {
        msgData['replyTo'] = replyTo.toMap();
      }

      final batch = FirebaseService.firestore.batch();
      batch.set(
        convoRef,
        {
          'participants': [myId, peerId],
          'lastMessage': trimmed,
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastSenderId': myId,
          'unreadCounts.$peerId': FieldValue.increment(1),
          'unreadCounts.$myId': 0,
        },
        SetOptions(merge: true),
      );
      batch.set(msgRef, msgData);
      await batch.commit();

      state = false;
      return true;
    } catch (e) {
      debugPrint('[DmSend] $e');
      state = false;
      return false;
    }
  }

  Future<bool> edit({
    required String convoId,
    required String messageId,
    required String newText,
  }) async {
    final trimmed = newText.trim();
    if (trimmed.isEmpty) return false;
    try {
      await FirebaseService.firestore
          .collection('conversations')
          .doc(convoId)
          .collection('messages')
          .doc(messageId)
          .update({'text': trimmed, 'isEdited': true});
      return true;
    } catch (e) {
      debugPrint('[DmEdit] $e');
      return false;
    }
  }

  Future<bool> delete({
    required String convoId,
    required String messageId,
  }) async {
    try {
      await FirebaseService.firestore
          .collection('conversations')
          .doc(convoId)
          .collection('messages')
          .doc(messageId)
          .update({
        'isDeleted': true,
        'text': 'This message was deleted',
      });
      return true;
    } catch (e) {
      debugPrint('[DmDelete] $e');
      return false;
    }
  }
}

final dmSendProvider =
NotifierProvider<DmSendNotifier, bool>(DmSendNotifier.new);

// ─── Mark Read (Batch-Safe, 450 chunk limit) ───────────────────────────────────
Future<void> markConversationRead(String convoId, String myId) async {
  try {
    // Zero out the counter in parent document immediately
    await FirebaseService.firestore
        .collection('conversations')
        .doc(convoId)
        .update({'unreadCounts.$myId': 0});

    final snap = await FirebaseService.firestore
        .collection('conversations')
        .doc(convoId)
        .collection('messages')
        .where('senderId', isNotEqualTo: myId)
        .get();

    final unreadDocs =
    snap.docs.where((d) => d.data()['readAt'] == null).toList();
    if (unreadDocs.isEmpty) return;

    // Chunk into groups of 450 to stay under Firestore's 500-op batch limit
    for (var i = 0; i < unreadDocs.length; i += 450) {
      final end =
      (i + 450) > unreadDocs.length ? unreadDocs.length : i + 450;
      final chunk = unreadDocs.sublist(i, end);
      final batch = FirebaseService.firestore.batch();
      for (final doc in chunk) {
        batch.update(
            doc.reference, {'readAt': FieldValue.serverTimestamp()});
      }
      await batch.commit();
    }
  } catch (e) {
    debugPrint('[markRead] $e');
  }
}
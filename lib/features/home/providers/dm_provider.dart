import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/dm_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/local_storage_service.dart';
import 'feed_provider.dart';

String conversationId(String a, String b) {
  final sorted = [a, b]..sort();
  return '${sorted[0]}_${sorted[1]}';
}

final totalUnreadNotifier = ValueNotifier<int>(0);

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
    final total = convos.fold<int>(0, (sum, c) => sum + c.unreadFor(anonId));
    totalUnreadNotifier.value = total;
    return convos;
  });
});

final dmMessagesProvider =
StreamProvider.family<List<DmMessage>, String>((ref, convoId) {
  return FirebaseService.firestore
      .collection('conversations')
      .doc(convoId)
      .collection('messages')
      .orderBy('createdAt', descending: false)
      .limitToLast(25)
      .snapshots()
      .map((snap) => snap.docs.map(DmMessage.fromFirestore).toList());
});

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
          .update({'isDeleted': true, 'text': ''});
      return true;
    } catch (e) {
      debugPrint('[DmDelete] $e');
      return false;
    }
  }
}

final dmSendProvider =
NotifierProvider<DmSendNotifier, bool>(DmSendNotifier.new);

Future<void> markConversationRead(String convoId, String myId) async {
  try {
    await FirebaseService.firestore
        .collection('conversations')
        .doc(convoId)
        .update({'unreadCounts.$myId': 0});

    final unread = await FirebaseService.firestore
        .collection('conversations')
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

Future<List<DmMessage>> loadOlderMessages({
  required String convoId,
  required DocumentSnapshot beforeDoc,
  int limit = 25,
}) async {
  try {
    final snap = await FirebaseService.firestore
        .collection('conversations')
        .doc(convoId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .endBeforeDocument(beforeDoc)
        .limitToLast(limit)
        .get();
    return snap.docs.map(DmMessage.fromFirestore).toList();
  } catch (e) {
    debugPrint('[loadOlderMessages] $e');
    return [];
  }
}
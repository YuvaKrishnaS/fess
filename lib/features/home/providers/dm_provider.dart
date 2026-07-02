import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/dm_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/local_storage_service.dart';
import 'feed_provider.dart';

String conversationId(String a, String b) {
  final sorted = [a, b]..sort();
  return '${sorted[0]}_${sorted[1]}';
}

final totalUnreadNotifier = ValueNotifier<int>(0);
final activeConversationIdProvider = StateProvider<String?>((ref) => null);

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
    final unreadCount = convos.where((c) => c.isUnreadFor(anonId)).length;
    totalUnreadNotifier.value = unreadCount;
    return convos;
  });
});

final dmConversationDocProvider =
StreamProvider.family<DmConversation?, String>((ref, convoId) {
  if (convoId.isEmpty) return const Stream.empty();
  return FirebaseService.firestore
      .collection('conversations')
      .doc(convoId)
      .snapshots()
      .map((doc) => doc.exists ? DmConversation.fromFirestore(doc) : null);
});

final dmLiveMessagesProvider =
StreamProvider.family<List<DmMessage>, String>((ref, convoId) {
  if (convoId.isEmpty) return const Stream.empty();
  return FirebaseService.firestore
      .collection('conversations')
      .doc(convoId)
      .collection('messages')
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map((snap) => snap.docs.map(DmMessage.fromFirestore).toList());
});

class PendingMessagesNotifier extends StateNotifier<List<DmMessage>> {
  PendingMessagesNotifier() : super([]);

  void addPending(DmMessage msg) {
    state = [msg, ...state];
  }

  void removePending(String id) {
    state = state.where((m) => m.id != id).toList();
  }

  void markFailed(String id) {
    state = state
        .map((m) =>
    m.id == id ? m.copyWith(status: DmMessageStatus.failed) : m)
        .toList();
  }

  void markSending(String id) {
    state = state
        .map((m) =>
    m.id == id ? m.copyWith(status: DmMessageStatus.sending) : m)
        .toList();
  }
}

final pendingMessagesProvider = StateNotifierProvider.family<
    PendingMessagesNotifier, List<DmMessage>, String>(
      (ref, convoId) => PendingMessagesNotifier(),
);

Future<List<DmMessage>> fetchOlderMessages({
  required String convoId,
  required DocumentSnapshot afterDoc,
  int limit = 25,
}) async {
  try {
    final snap = await FirebaseService.firestore
        .collection('conversations')
        .doc(convoId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .startAfterDocument(afterDoc)
        .limit(limit)
        .get();
    return snap.docs.map(DmMessage.fromFirestore).toList();
  } catch (e) {
    debugPrint('[fetchOlderMessages] $e');
    return [];
  }
}

class DmSendNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> send({
    required String peerId,
    required String text,
    DmReplyTo? replyTo,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final myId = LocalStorageService.getCachedAnonId();
    if (myId == null) return;

    final convoId = conversationId(myId, peerId);
    final localId = const Uuid().v4();
    final pendingMsg = DmMessage(
      id: localId,
      senderId: myId,
      text: trimmed,
      createdAt: DateTime.now(),
      replyTo: replyTo,
      status: DmMessageStatus.sending,
    );

    ref.read(pendingMessagesProvider(convoId).notifier).addPending(pendingMsg);

    final convoRef =
    FirebaseService.firestore.collection('conversations').doc(convoId);

    try {
      final msgRef = convoRef.collection('messages').doc();
      final msgData = <String, dynamic>{
        'senderId': myId,
        'text': trimmed,
        'createdAt': FieldValue.serverTimestamp(),
        'isEdited': false,
        'isDeleted': false,
        'reactions': <String, String>{},
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
          'lastRead.$myId': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      batch.set(msgRef, msgData);
      await batch.commit();

      ref.read(pendingMessagesProvider(convoId).notifier).removePending(localId);
    } catch (e) {
      debugPrint('[DmSend] $e');
      ref.read(pendingMessagesProvider(convoId).notifier).markFailed(localId);
    }
  }

  Future<void> retry({
    required String convoId,
    required String peerId,
    required DmMessage failedMsg,
  }) async {
    ref.read(pendingMessagesProvider(convoId).notifier).markSending(failedMsg.id);
    final myId = LocalStorageService.getCachedAnonId();
    if (myId == null) return;

    final convoRef =
    FirebaseService.firestore.collection('conversations').doc(convoId);

    try {
      final msgRef = convoRef.collection('messages').doc();
      final msgData = <String, dynamic>{
        'senderId': myId,
        'text': failedMsg.text,
        'createdAt': FieldValue.serverTimestamp(),
        'isEdited': false,
        'isDeleted': false,
        'reactions': <String, String>{},
      };
      if (failedMsg.replyTo != null) {
        msgData['replyTo'] = failedMsg.replyTo!.toMap();
      }

      final batch = FirebaseService.firestore.batch();
      batch.set(
        convoRef,
        {
          'lastMessage': failedMsg.text,
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastSenderId': myId,
          'lastRead.$myId': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      batch.set(msgRef, msgData);
      await batch.commit();

      ref.read(pendingMessagesProvider(convoId).notifier).removePending(failedMsg.id);
    } catch (e) {
      debugPrint('[DmRetry] $e');
      ref.read(pendingMessagesProvider(convoId).notifier).markFailed(failedMsg.id);
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
          .update({'isDeleted': true, 'text': 'This message was deleted'});
      return true;
    } catch (e) {
      debugPrint('[DmDelete] $e');
      return false;
    }
  }

  Future<bool> react({
    required String convoId,
    required String messageId,
    required String myId,
    required String emoji,
  }) async {
    try {
      await FirebaseService.firestore
          .collection('conversations')
          .doc(convoId)
          .collection('messages')
          .doc(messageId)
          .update({'reactions.$myId': emoji});
      return true;
    } catch (e) {
      debugPrint('[DmReact] $e');
      return false;
    }
  }

  Future<bool> removeReaction({
    required String convoId,
    required String messageId,
    required String myId,
  }) async {
    try {
      await FirebaseService.firestore
          .collection('conversations')
          .doc(convoId)
          .collection('messages')
          .doc(messageId)
          .update({'reactions.$myId': FieldValue.delete()});
      return true;
    } catch (e) {
      debugPrint('[DmRemoveReaction] $e');
      return false;
    }
  }
}

final dmSendProvider =
NotifierProvider<DmSendNotifier, bool>(DmSendNotifier.new);

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

Future<void> markConversationRead(String convoId, String myId) async {
  try {
    await FirebaseService.firestore
        .collection('conversations')
        .doc(convoId)
        .update({'lastRead.$myId': FieldValue.serverTimestamp()});
  } catch (e) {
    debugPrint('[markRead] $e');
  }
}

Future<void> togglePinConversation(String convoId, String myId, bool pin) async {
  try {
    await FirebaseService.firestore.collection('conversations').doc(convoId).update({
      'pinnedBy': pin
          ? FieldValue.arrayUnion([myId])
          : FieldValue.arrayRemove([myId]),
    });
  } catch (e) {
    debugPrint('[togglePin] $e');
  }
}

Future<void> setTypingState(String convoId, String myId, bool isTyping) async {
  try {
    await FirebaseService.firestore.collection('conversations').doc(convoId).update({
      'typingUsers.$myId': isTyping ? FieldValue.serverTimestamp() : FieldValue.delete(),
    });
  } catch (e) {
    debugPrint('[setTyping] $e');
  }
}
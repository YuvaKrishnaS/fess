import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/local_storage_service.dart';

final _firestore = FirebaseService.firestore;

final currentAnonIdProvider = FutureProvider<String?>((ref) async {
  final cached = LocalStorageService.getCachedAnonId();
  if (cached != null) return cached;
  return null;
});

final witnessStateProvider =
StateNotifierProvider.family<WitnessNotifier, bool, String>(
      (ref, targetAnonId) {
    final myAnonIdAsync = ref.watch(currentAnonIdProvider);
    final myAnonId = myAnonIdAsync.value;
    return WitnessNotifier(myAnonId: myAnonId, targetAnonId: targetAnonId);
  },
);

class WitnessNotifier extends StateNotifier<bool> {
  final String? myAnonId;
  final String targetAnonId;

  WitnessNotifier({required this.myAnonId, required this.targetAnonId})
      : super(false) {
    if (myAnonId != null && myAnonId!.isNotEmpty) {
      _loadInitialState();
    }
  }

  Future<void> _loadInitialState() async {
    final docId = '${myAnonId}_$targetAnonId';
    final doc = await _firestore.collection('witnesses').doc(docId).get();
    if (mounted) state = doc.exists;
  }

  Future<void> toggle() async {
    if (myAnonId == null || myAnonId!.isEmpty) return;
    final docId = '${myAnonId}_$targetAnonId';
    final newState = !state;
    state = newState;

    try {
      if (newState) {
        await _firestore.runTransaction((tx) async {
          final witnessRef =
          _firestore.collection('witnesses').doc(docId);
          final myProfileRef =
          _firestore.collection('publicProfiles').doc(myAnonId);
          final theirProfileRef =
          _firestore.collection('publicProfiles').doc(targetAnonId);

          tx.set(witnessRef, {
            'witnesserId': myAnonId,
            'witnessedId': targetAnonId,
            'createdAt': FieldValue.serverTimestamp(),
          });
          tx.update(myProfileRef,
              {'witnessingCount': FieldValue.increment(1)});
          tx.update(theirProfileRef,
              {'witnessCount': FieldValue.increment(1)});
        });
      } else {
        await _firestore.runTransaction((tx) async {
          final witnessRef =
          _firestore.collection('witnesses').doc(docId);
          final myProfileRef =
          _firestore.collection('public_profiles').doc(myAnonId);
          final theirProfileRef =
          _firestore.collection('public_profiles').doc(targetAnonId);

          tx.delete(witnessRef);
          tx.update(myProfileRef,
              {'witnessingCount': FieldValue.increment(-1)});
          tx.update(theirProfileRef,
              {'witnessCount': FieldValue.increment(-1)});
        });
      }
    } catch (_) {
      state = !newState;
    }
  }
}
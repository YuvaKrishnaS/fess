import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/services/firebase_service.dart';
import '../../../core/services/local_storage_service.dart';

final _firestore = FirebaseService.firestore;

// Synchronous provider - LocalStorageService is already laded at startup
// No Future, No race Condition
final myAnonIdProvider = Provider<String?>((ref) {
  return LocalStorageService.getCachedAnonId();
});

// family key = targetAnonId (the person being witnessed)
// myAnonId is read synchronously from myAnonIdProvider.
final witnessStateProvider =
    StateNotifierProvider.family<WitnessNotifier, bool, String>(
        (ref, targetAnonId) {
          final myAnonId = ref.watch(myAnonIdProvider); // sync, always available
          return WitnessNotifier(myAnonId: myAnonId, targetAnonId: targetAnonId);
        }
    );

class WitnessNotifier extends StateNotifier<bool> {
  final String? myAnonId;
  final String targetAnonId;

  WitnessNotifier({required this.myAnonId, required this.targetAnonId}) : super(false) {
    if (myAnonId != null && myAnonId!.isNotEmpty) {
      _loadInitialState();
    }
  }

  Future<void> _loadInitialState() async {
    try {
      final docId = '${myAnonId}_$targetAnonId';
      final doc = await _firestore.collection('witness').doc(docId).get();
      if (mounted) state = doc.exists;
    } catch (e) {
      debugPrint('[WitnessNotifier] _loadInitialState error: $e');
    }
  }

  Future<void> toggle() async {
    if (myAnonId == null || myAnonId!.isEmpty) {
      debugPrint('[WitnessNotifier] toffle: myAnonId null - aborting');
      return;
    }
    if(myAnonId == targetAnonId) return; // Can't witness yourself

    final docId = '${myAnonId}_$targetAnonId';
    final newState = !state;
    state = newState; // optimistic update

    try {
      if(newState) {
        await _firestore.collection('witness').doc(docId).set({
          'witnesserId': myAnonId,
          'witnessedId': targetAnonId,
          'createAt': FieldValue.serverTimestamp(),
        });
        await _firestore.collection('public_profiles').doc(myAnonId).set({'witnessingCount' : FieldValue.increment(1)}, SetOptions(merge: true));
        await _firestore.collection('public_profiles').doc(targetAnonId).set({'witnessCount': FieldValue.increment(1)}, SetOptions(merge: true));
      } else {
        await _firestore.collection('witness').doc(docId).delete();
        await _firestore.collection('public_profiles').doc(myAnonId).set({'witnessingCount': FieldValue.increment(-1)}, SetOptions(merge: true));
        await _firestore.collection('public_profiles').doc(targetAnonId).set({'witnessCount': FieldValue.increment(-1)}, SetOptions(merge: true));
      }
      debugPrint('[WitnessNotifier] toggle OK -> $newState($targetAnonId)');
    } catch (e) {
      debugPrint('[WitnessNotifier] toggle FAILED: $e');
      if (mounted) state = !newState; //rollback
    }
  }
}
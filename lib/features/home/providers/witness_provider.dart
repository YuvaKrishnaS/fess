import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/local_storage_service.dart';

final _firestore = FirebaseService.firestore;

// Separate provider - Not watched inside the notifier factory
final currentAnonIdProvider = FutureProvider<String?>((ref) async {
  final cached = LocalStorageService.getCachedAnonId();
  if (cached != null) return cached;
  return null;
});

// Fix Read anonId once at creation time, don't watch it
final witnessStateProvider = StateNotifierProvider.family<WitnessNotifier, bool, String>(
    (ref, targetAnonId) {
      // use .read not .watch - prevents notifier recreation on anonId resolve
      final myAnonId = ref.read(currentAnonIdProvider).value;
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
      final doc = await _firestore.collection('witnesses').doc(docId).get();
      if (mounted) state = doc.exists;
    } catch (e) {
      debugPrint('[WitnessNotifier] _loadInitialState error: $e');
    }
  }

  Future<void> toggle() async {
    if (myAnonId == null || myAnonId!.isEmpty) {
      debugPrint('[WitnessNotifier] toggle: myAnonId is null.empty, aborting');
      return;
    }

    final docId = '${myAnonId}_$targetAnonId';
    final newState = !state;
    state = newState;

    try {
      if (newState) {
        // Fix: simple set + set(merge) instead of transaction with update()
        // update() throws if doc doesn't exists; set (merge:true) is safe
        await _firestore.collection('witnesses').doc(docId).set({
          'witnesserId': myAnonId,
          'witnessesId': targetAnonId,
          'createdAt': FieldValue.serverTimestamp()
        });

        // Update counts seperately - safe even if profile docs are missing
        await _firestore.collection('public_profiles').doc(myAnonId).set({'witnessingCount': FieldValue.increment(1)}, SetOptions(merge: true));

        await _firestore.collection('public_profiles').doc(targetAnonId).set({'witnessCount': FieldValue.increment(1)}, SetOptions(merge: true));
      } else {
        await _firestore.collection('witnesses').doc(docId).delete();

        await _firestore.collection('public_profiles').doc(myAnonId).set({'witnessingCount': FieldValue.increment(-1)}, SetOptions(merge: true));

        await _firestore.collection('public_profiles').doc(targetAnonId).set({'witnessCount': FieldValue.increment(-1)}, SetOptions(merge: true));
      }

      debugPrint('[WitnessNotifier] toggle success -> $newState for $targetAnonId');
    } catch (e) {
      debugPrint('[WitnessNotifier] toggle FAILED: $e');
      if (mounted) state = !newState;
    }
  }
}
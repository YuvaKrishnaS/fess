import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/models/streak_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/local_storage_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/providers/feed_provider.dart';

// ─── Collection ref helper ────────────────────────────────────────────────────

CollectionReference<Map<String, dynamic>> get _streaksCol =>
    FirebaseService.firestore.collection('streaks');

// ─── myStreakProvider ─────────────────────────────────────────────────────────
// Real-time stream of the current user's streak doc.
// Returns null if no streak doc exists yet (new user).

final myStreakProvider = StreamProvider<StreakModel?>((ref) {
  final anonIdAsync = ref.watch(currentAnonIdProvider);

  return anonIdAsync.when(
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
    data: (anonId) {
      if (anonId == null || anonId.isEmpty) return const Stream.empty();

      return _streaksCol.doc(anonId).snapshots().map((snap) {
        if (!snap.exists || snap.data() == null) return null;
        try {
          return StreakModel.fromFirestore(snap);
        } catch (e, st) {
          debugPrint('[myStreakProvider] parse error: $e');
          debugPrint('$st');
          return null;
        }
      });
    },
  );
});

// ─── StreakState ──────────────────────────────────────────────────────────────

enum StreakUpdateStatus { idle, loading, success, error }

class StreakState {
  final StreakUpdateStatus status;
  final String? error;

  const StreakState({
    this.status = StreakUpdateStatus.idle,
    this.error,
  });

  StreakState copyWith({StreakUpdateStatus? status, String? error}) {
    return StreakState(
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}

// ─── StreakNotifier ───────────────────────────────────────────────────────────
// Call recordActivity() after EVERY qualifying action:
//   - post created (confession or tea)
//   - world chat message sent
//   - DM sent
//
// It is safe to call this multiple times per day — the model's computeNext()
// is idempotent for same-day calls (returns unchanged if daysDiff == 0).

class StreakNotifier extends StateNotifier<StreakState> {
  final Ref _ref;

  StreakNotifier(this._ref) : super(const StreakState());

  Future<void> recordActivity() async {
    if (state.status == StreakUpdateStatus.loading) return; // debounce

    state = state.copyWith(status: StreakUpdateStatus.loading);

    try {
      final anonId = LocalStorageService.getCachedAnonId();
      if (anonId == null || anonId.isEmpty) {
        state = state.copyWith(status: StreakUpdateStatus.idle);
        return;
      }

      final docRef = _streaksCol.doc(anonId);

      await FirebaseService.firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);

        late StreakModel next;

        if (!snap.exists || snap.data() == null) {
          // First ever activity — create fresh streak doc
          next = StreakModel(
            anonId: anonId,
            currentStreak: 1,
            longestStreak: 1,
            totalActiveDays: 1,
            lastActiveDate: DateTime.now(),
            graceUsed: false,
          );
        } else {
          final current = StreakModel.fromFirestore(snap);
          next = current.computeNext();

          // Same day — nothing changed, skip write
          if (next == current) {
            state = state.copyWith(status: StreakUpdateStatus.success);
            return;
          }
        }

        tx.set(docRef, next.toFirestore(), SetOptions(merge: true));
      });

      debugPrint('[StreakNotifier] activity recorded');
      state = state.copyWith(status: StreakUpdateStatus.success);
    } catch (e, st) {
      debugPrint('[StreakNotifier] ERROR: $e');
      debugPrint('$st');
      state = state.copyWith(
        status: StreakUpdateStatus.error,
        error: e.toString(),
      );
    }
  }
}

final streakNotifierProvider =
StateNotifierProvider<StreakNotifier, StreakState>((ref) {
  return StreakNotifier(ref);
});

// Convenience provider: is streak alive?
// Use this in widgets that only need a bool (e.g. nav badge dot).

final isStreakAliveProvider = Provider<bool>((ref) {
  final streak = ref.watch(myStreakProvider).asData?.value;
  return streak?.isAlive ?? false;
});
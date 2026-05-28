import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/models/streak_model.dart';
import '../../../core/services/firebase_service.dart';

// Internal helpers

// Returns Firebase UID of the currently signed-in user, or null.
String? get _firebaseUid => FirebaseService.auth.currentUser?.uid;

// The private_users doc ref for the current user.
// Streak lives at private_users/{firebaseUid}.streakData
DocumentReference<Map<String, dynamic>>? get _privateUserDoc {
  final uid = _firebaseUid;
  if (uid == null) return null;
  return FirebaseService.firestore.collection('private_users').doc(uid);
}

// StreakModel extension - parses from the streakData sub-map

extension StreakModelFirestore on StreakModel {
  /// Parse from the `streakData` map inside a private_users document.
  static StreakModel fromMap(Map<String, dynamic> map) {
    return StreakModel(
      anonId: '', // not needed at this level
      currentStreak: (map['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (map['longestStreak'] as num?)?.toInt() ?? 0,
      totalActiveDays: (map['totalActiveDays'] as num?)?.toInt() ?? 0,
      lastActiveDate: (map['lastActiveDate'] as Timestamp?)?.toDate(),
      graceUsed: map['graceUsed'] as bool? ?? false,
    );
  }

  /// Serialize back to the `streakData` map shape.
  Map<String, dynamic> toSubMap() {
    return {
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'totalActiveDays': totalActiveDays,
      'lastActiveDate': lastActiveDate != null
          ? Timestamp.fromDate(lastActiveDate!)
          : null,
      'graceUsed': graceUsed,
    };
  }
}

// myStreakProvider — real-time stream from private_users.streakData
// Listens to the private_users/{uid} doc and extracts the streakData sub-map.
// Emits null when:
//   - user is not signed in
//   - doc doesn't exist yet
//   - streakData field is missing (brand new user)

final myStreakProvider = StreamProvider<StreakModel?>((ref) {
  final uid = _firebaseUid;
  if (uid == null) return const Stream.empty();

  return FirebaseService.firestore
      .collection('private_users')
      .doc(uid)
      .snapshots()
      .map((snap) {
    if (!snap.exists || snap.data() == null) return null;
    final streakMap = snap.data()!['streakData'] as Map<String, dynamic>?;
    if (streakMap == null) return null;
    try {
      return StreakModelFirestore.fromMap(streakMap);
    } catch (e) {
      debugPrint('[myStreakProvider] parse error: $e');
      return null;
    }
  });
});

// StreakState

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

class StreakNotifier extends StateNotifier<StreakState> {
  StreakNotifier() : super(const StreakState());

  Future<void> recordActivity() async {
    if (state.status == StreakUpdateStatus.loading) return;

    final docRef = _privateUserDoc;
    if (docRef == null) {
      debugPrint('[StreakNotifier] no firebase user — skipping');
      return;
    }

    state = state.copyWith(status: StreakUpdateStatus.loading);

    try {
      await FirebaseService.firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);

        if (!snap.exists || snap.data() == null) {
          // Private user doc doesn't exist — shouldn't happen after login,
          // but handle gracefully by doing nothing.
          debugPrint('[StreakNotifier] private_users doc missing — skipping');
          return;
        }

        final data = snap.data()!;
        final streakMap = data['streakData'] as Map<String, dynamic>?;

        late StreakModel next;

        if (streakMap == null) {
          // First ever activity — initialize streak
          next = StreakModel(
            anonId: '',
            currentStreak: 1,
            longestStreak: 1,
            totalActiveDays: 1,
            lastActiveDate: DateTime.now(),
            graceUsed: false,
          );
        } else {
          final current = StreakModelFirestore.fromMap(streakMap);
          next = current.computeNext();

          // Same calendar day — already counted, skip the write entirely
          if (next == current) {
            debugPrint('[StreakNotifier] same-day call — skipping write');
            return;
          }
        }

        // Write only the streakData field — leave everything else untouched
        tx.update(docRef, {'streakData': next.toSubMap()});
      });

      debugPrint('[StreakNotifier] activity recorded ✓');
      state = state.copyWith(status: StreakUpdateStatus.success);
    } catch (e, st) {
      debugPrint('[StreakNotifier] ERROR: $e\n$st');
      state = state.copyWith(
        status: StreakUpdateStatus.error,
        error: e.toString(),
      );
    }
  }
}

final streakNotifierProvider =
StateNotifierProvider<StreakNotifier, StreakState>((ref) {
  return StreakNotifier();
});

// Convenience providers

/// True if the streak is alive (active today or yesterday).
final isStreakAliveProvider = Provider<bool>((ref) {
  final streak = ref.watch(myStreakProvider).asData?.value;
  return streak?.isAlive ?? false;
});
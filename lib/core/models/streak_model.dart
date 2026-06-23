import 'package:cloud_firestore/cloud_firestore.dart';

class StreakModel {
  final String anonId;
  final int currentStreak;    // current consecutive active days
  final int longestStreak;    // all-time best streak
  final int totalActiveDays;  // cumulative active days ever
  final DateTime? lastActiveDate; // calendar date of last qualifying activity
  final bool graceUsed;       // true if grace period already consumed this break
  final DateTime? updatedAt;

  const StreakModel({
    required this.anonId,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalActiveDays,
    this.lastActiveDate,
    required this.graceUsed,
    this.updatedAt,
  });

  // Firestore deserialization

  factory StreakModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data()!;
    return StreakModel(
      anonId: doc.id,
      currentStreak: (data['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (data['longestStreak'] as num?)?.toInt() ?? 0,
      totalActiveDays: (data['totalActiveDays'] as num?)?.toInt() ?? 0,
      lastActiveDate:
      (data['lastActiveDate'] as Timestamp?)?.toDate(),
      graceUsed: data['graceUsed'] as bool? ?? false,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  // Firestore Serialization

  Map<String, dynamic> toFirestore() {
    return {
      'anonId': anonId,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'totalActiveDays': totalActiveDays,
      'lastActiveDate': lastActiveDate != null
          ? Timestamp.fromDate(lastActiveDate!)
          : null,
      'graceUsed': graceUsed,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // copyWith

  StreakModel copyWith({
    int? currentStreak,
    int? longestStreak,
    int? totalActiveDays,
    DateTime? lastActiveDate,
    bool? graceUsed,
    DateTime? updatedAt,
  }) {
    return StreakModel(
      anonId: anonId,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalActiveDays: totalActiveDays ?? this.totalActiveDays,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      graceUsed: graceUsed ?? this.graceUsed,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Core streak computation logic
  //
  // Called by streak_provider.dart inside recordActivity().
  // Returns the NEW StreakModel that should be written to Firestore.
  //
  // Rules (from the master plan):
  //   daysDiff == 0  - same day, return unchanged (idempotent)
  //   daysDiff == 1  - extend streak
  //   daysDiff == 2 && !graceUsed - grace period: preserve streak, mark grace
  //   daysDiff > 2  OR (daysDiff == 2 && graceUsed) - reset to 1
  //
  // "daysDiff" is measured in CALENDAR DAYS (not 24h), so posting at 11:59 PM
  // then at 12:01 AM still counts as consecutive.

  StreakModel computeNext() {
    final today = _dateOnly(DateTime.now());
    final lastActive =
    lastActiveDate != null ? _dateOnly(lastActiveDate!) : null;

    // First activity ever
    if (lastActive == null) {
      return copyWith(
        currentStreak: 1,
        longestStreak: 1,
        totalActiveDays: 1,
        lastActiveDate: today,
        graceUsed: false,
      );
    }

    final daysDiff = today.difference(lastActive).inDays;

    // Same calendar day → already counted, no change
    if (daysDiff == 0) return this;

    int newCurrent;
    bool newGraceUsed;
    int newTotal;

    if (daysDiff == 1) {
      // Perfect consecutive day
      newCurrent = currentStreak + 1;
      newGraceUsed = false; // reset grace after each good day
      newTotal = totalActiveDays + 1;
    } else if (daysDiff == 2 && !graceUsed) {
      // Missed 1 day, grace period available — streak preserved
      newCurrent = currentStreak; // NOT incremented — gap day
      newGraceUsed = true;
      newTotal = totalActiveDays + 1;
    } else {
      // Streak broken — reset
      newCurrent = 1;
      newGraceUsed = false;
      newTotal = totalActiveDays + 1;
    }

    final newLongest =
    newCurrent > longestStreak ? newCurrent : longestStreak;

    return copyWith(
      currentStreak: newCurrent,
      longestStreak: newLongest,
      totalActiveDays: newTotal,
      lastActiveDate: today,
      graceUsed: newGraceUsed,
    );
  }

  //  - - Display helpers  - - ---------------------------------

  /// True if the streak is "alive" - user was active today or yesterday.
  bool get isAlive {
    if (lastActiveDate == null) return false;
    final today = _dateOnly(DateTime.now());
    final last = _dateOnly(lastActiveDate!);
    return today.difference(last).inDays <= 1;
  }

  /// Show 🔥 badge only when streak ≥ 2 and alive.
  bool get shouldShowBadge => isAlive && currentStreak >= 2;

  /// Label for the streak badge - e.g. "12🔥" or "1d"
  String get badgeLabel => '$currentStreak';

  // ── Private ----------───

  /// Strip time component - gives midnight of the given date
  static DateTime _dateOnly(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is StreakModel &&
              other.currentStreak == currentStreak &&
              other.longestStreak == longestStreak &&
              other.totalActiveDays == totalActiveDays &&
              other.lastActiveDate?.day == lastActiveDate?.day &&
              other.lastActiveDate?.month == lastActiveDate?.month &&
              other.lastActiveDate?.year == lastActiveDate?.year &&
              other.graceUsed == graceUsed;

  @override
  int get hashCode => Object.hash(
      currentStreak,
      longestStreak,
      totalActiveDays,
      lastActiveDate?.day,
      graceUsed
  );
}
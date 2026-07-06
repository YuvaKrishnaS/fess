import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../providers/streak_provider.dart';

/// Flame badge shown in app bars. Renders nothing if streak < 2 or broken.
/// Usage: place inside an app bar Row or actions list.
class StreakBadge extends ConsumerWidget {
  /// If true, shows a larger pill variant (for profile stats row).
  final bool large;

  const StreakBadge({super.key, this.large = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(myStreakProvider);

    return streakAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (streak) {
        if (streak == null || !streak.shouldShowBadge) {
          return const SizedBox.shrink();
        }
        return large ? _LargeBadge(streak.currentStreak) : _SmallBadge(streak.currentStreak);
      },
    );
  }
}

// Small badge - for app bars

class _SmallBadge extends StatelessWidget {
  final int count;
  const _SmallBadge(this.count);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: AppTypography.labelMedium.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFFF6B35),
            ),
          ),
        ],
      ),
    );
  }
}


class _LargeBadge extends StatelessWidget {
  final int count;
  const _LargeBadge(this.count);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: AppTypography.bodyMedium.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            const Text('🔥', style: TextStyle(fontSize: 16)),
          ]
        ),
        Text(
          'DayStreak',
          style: AppTypography.bodySmall.copyWith(
            fontSize: 11,
            color: AppColors.textSecondary,
          )
        )
      ]
    );
  }
}
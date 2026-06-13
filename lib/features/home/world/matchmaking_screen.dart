import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import 'providers/world_provider.dart';

class MatchmakingScreen extends ConsumerStatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  ConsumerState<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends ConsumerState<MatchmakingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final worldState = ref.watch(worldProvider);
    final moodId = worldState.selectedMood ?? 'neutral';
    final mood = kMoodOptions.firstWhere((m) => m.id == moodId,
        orElse: () => kMoodOptions.last);

    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 60),

              // Pulsing emoji orb
              AnimatedBuilder(
                animation: _pulse,
                builder: (ctx, _) {
                  final scale = 1.0 + _pulse.value * 0.08;
                  final glow = _pulse.value * 0.35;
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accentPrimary.withOpacity(0.08 + glow),
                        border: Border.all(
                          color: AppColors.accentPrimary.withOpacity(0.3 + glow),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(mood.emoji,
                            style: const TextStyle(fontSize: 44)),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              Text(
                'Finding someone\nfor you...',
                style: AppTypography.h3.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Looking for someone who vibes with\nyour ${mood.label.toLowerCase()} mood ${mood.emoji}',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              // Error state
              if (worldState.error != null) ...[
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A26),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF2A2A3A), width: 0.8),
                  ),
                  child: Text(
                    worldState.error!,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(worldProvider.notifier).findNext();
                  },
                  child: Text(
                    'Try again',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.accentPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],

              const Spacer(),

              // Change mood
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(worldProvider.notifier).changeMood();
                },
                child: Text(
                  'Change mood',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
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
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _entryCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _entryFade;
  late Animation<Offset> _entrySlide;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(worldProvider);
    final mood = state.selectedMood ?? 'neutral';
    final moodLabel = kMoodOptions
        .firstWhere((m) => m.id == mood, orElse: () => kMoodOptions.last)
        .label
        .toLowerCase();

    final hasError = state.error != null;

    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      body: SafeArea(
        child: FadeTransition(
          opacity: _entryFade,
          child: SlideTransition(
            position: _entrySlide,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),

                  // headline
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: hasError
                        ? _buildErrorHeadline()
                        : _buildSearchingHeadline(moodLabel),
                  ),

                  const Spacer(),

                  // visual anchor
                  Center(
                    child: hasError
                        ? _buildErrorVisual()
                        : _buildPulseRing(),
                  ),

                  const Spacer(),

                  // bottom actions
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 360),
                    child: hasError
                        ? _buildErrorActions()
                        : _buildSearchingBottom(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchingHeadline(String moodLabel) {
    return Column(
      key: const ValueKey('searching'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Looking for\nsomeone',
          style: const TextStyle(
            fontFamily: 'DM Sans',
            fontSize: 40,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            height: 1.05,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'who feels $moodLabel today',
          style: const TextStyle(
            fontFamily: 'DM Serif Display',
            fontStyle: FontStyle.italic,
            fontSize: 20,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
            height: 1.3,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorHeadline() {
    return Column(
      key: const ValueKey('error'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Too quiet\nright now.',
          style: const TextStyle(
            fontFamily: 'DM Sans',
            fontSize: 40,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            height: 1.05,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'come back when the world wakes up',
          style: const TextStyle(
            fontFamily: 'DM Serif Display',
            fontStyle: FontStyle.italic,
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Nobody matched your mood right now. The app is still early, more people are joining every day.',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.hintText,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildPulseRing() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (ctx, _) {
        return SizedBox(
          width: 160,
          height: 160,
          child: CustomPaint(
            painter: _PulseRingPainter(progress: _pulseAnim.value),
          ),
        );
      },
    );
  }

  Widget _buildErrorVisual() {
    return SizedBox(
      width: 80,
      height: 80,
      child: CustomPaint(
        painter: _StaticRingPainter(),
      ),
    );
  }

  Widget _buildSearchingBottom() {
    return Column(
      key: const ValueKey('searching_bottom'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Anonymous. Mood-matched. 5 minutes.',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.hintText,
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            ref.read(worldProvider.notifier).changeMood();
          },
          child: Text(
            'Change mood',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorActions() {
    return Column(
      key: const ValueKey('error_bottom'),
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              ref.read(worldProvider.notifier).findNext();
            },
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  'Try again',
                  style: const TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.backgroundMain,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            ref.read(worldProvider.notifier).changeMood();
          },
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: Center(
              child: Text(
                'Back to selection',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---- painters ---------------------------------------------------------------

class _PulseRingPainter extends CustomPainter {
  final double progress;
  _PulseRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 3 rings at different phases
    for (int i = 0; i < 3; i++) {
      final phase = (progress + i * 0.33) % 1.0;
      final radius = (size.width * 0.18) + (size.width * 0.32 * phase);
      final opacity = (1.0 - phase) * 0.35;

      final paint = Paint()
        ..color = const Color(0xFF1DE9B6).withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawCircle(center, radius, paint);
    }

    // center dot
    final dotPaint = Paint()
      ..color = const Color(0xFF1DE9B6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 5, dotPaint);
  }

  @override
  bool shouldRepaint(_PulseRingPainter old) => old.progress != progress;
}

class _StaticRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = const Color(0xFF2A2A3E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, size.width * 0.42, paint);

    final dotPaint = Paint()
      ..color = const Color(0xFF2A2A3E)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, dotPaint);
  }

  @override
  bool shouldRepaint(_StaticRingPainter old) => false;
}
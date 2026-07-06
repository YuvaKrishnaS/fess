import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../providers/streak_provider.dart';

//  Public widget - drop-in replacement for _StreakCup in feed_screen

class StreakCupButton extends ConsumerWidget {
  const StreakCupButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(myStreakProvider);

    return streakAsync.when(
      loading: () => _CupTapTarget(state: CupState.cold, streak: 0, onTap: () {}),
      error: (_, __) => _CupTapTarget(state: CupState.cold, streak: 0, onTap: () {}),
      data: (streak) {
        final state = _resolveCupState(streak);
        final count = streak?.currentStreak ?? 0;
        return _CupTapTarget(
          state: state,
          streak: count,
          onTap: () => _showStreakSheet(context, state, count),
        );
      },
    );
  }

  CupState _resolveCupState(streak) {
    if (streak == null || streak.currentStreak == 0) return CupState.broken;

    final today = DateTime.now();
    final last = streak.lastActiveDate;
    if (last == null) return CupState.broken;

    final daysSince = DateTime(today.year, today.month, today.day)
        .difference(DateTime(last.year, last.month, last.day))
        .inDays;

    if (daysSince > 2) return CupState.cracked;
    if (daysSince == 2 && streak.graceUsed) return CupState.cracked;
    if (daysSince == 2 && !streak.graceUsed) return CupState.cold; // grace still available
    if (daysSince == 1) return CupState.cold;
    // daysSince == 0 → active today
    if (streak.currentStreak >= 3) return CupState.hot;
    return CupState.warm;
  }

  void _showStreakSheet(BuildContext context, CupState state, int count) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _StreakSheet(state: state, streak: count),
    );
  }
}


enum CupState { hot, warm, cold, cracked, broken }

extension CupStateX on CupState {
  String get label {
    switch (this) {
      case CupState.hot: return 'On fire! 🔥';
      case CupState.warm: return 'Going strong ☕';
      case CupState.cold: return 'Getting cold...';
      case CupState.cracked: return 'Almost broken 💔';
      case CupState.broken: return 'Start your streak';
    }
  }

  String get message {
    switch (this) {
      case CupState.hot: return 'Your cup is piping hot. Keep posting every day to keep the steam going!';
      case CupState.warm: return 'Your streak is alive. Post today to keep it warm!';
      case CupState.cold: return 'You missed yesterday. One more miss and your cup cracks. Post now!';
      case CupState.cracked: return 'Your cup is cracking. Post right now before it shatters completely.';
      case CupState.broken: return 'Your cup shattered. Post a spill or tea to start a new streak from scratch.';
    }
  }

  Color get primaryColor {
    switch (this) {
      case CupState.hot: return const Color(0xFFFF6B35);
      case CupState.warm: return const Color(0xFFE8C547);
      case CupState.cold: return const Color(0xFF8BA3B8);
      case CupState.cracked: return const Color(0xFFB85450);
      case CupState.broken: return const Color(0xFF444444);
    }
  }
}


class _CupTapTarget extends StatelessWidget {
  final CupState state;
  final int streak;
  final VoidCallback onTap;

  const _CupTapTarget({
    required this.state,
    required this.streak,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: StreakCupSvg(state: state, size: 26),
        ),
      ),
    );
  }
}

// ─── The actual SVG cup drawn with CustomPainter ─────────────────────────────

class StreakCupSvg extends StatefulWidget {
  final CupState state;
  final double size;

  const StreakCupSvg({super.key, required this.state, required this.size});

  @override
  State<StreakCupSvg> createState() => _StreakCupSvgState();
}

class _StreakCupSvgState extends State<StreakCupSvg>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _steam;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _steam = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (widget.state == CupState.hot || widget.state == CupState.warm) {
      _ctrl.repeat();
    }
  }

  @override
  void didUpdateWidget(StreakCupSvg old) {
    super.didUpdateWidget(old);
    if (widget.state == CupState.hot || widget.state == CupState.warm) {
      if (!_ctrl.isAnimating) _ctrl.repeat();
    } else {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _steam,
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _CupPainter(
            state: widget.state,
            steamProgress: _steam.value,
          ),
        );
      },
    );
  }
}

// CustomPainter — draws the cup in all 5 states

class _CupPainter extends CustomPainter {
  final CupState state;
  final double steamProgress; // 0..1, only used for hot/warm

  const _CupPainter({required this.state, required this.steamProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    switch (state) {
      case CupState.hot:
        _drawCupBody(canvas, w, h, const Color(0xFFFF6B35), full: true);
        _drawHandle(canvas, w, h, const Color(0xFFFF6B35));
        _drawSteam(canvas, w, h, const Color(0xFFFF9A6C), count: 3);
        break;

      case CupState.warm:
        _drawCupBody(canvas, w, h, const Color(0xFFE8C547), full: true);
        _drawHandle(canvas, w, h, const Color(0xFFE8C547));
        _drawSteam(canvas, w, h, const Color(0xFFEDD87A), count: 1);
        break;

      case CupState.cold:
        _drawCupBody(canvas, w, h, const Color(0xFF8BA3B8), full: true);
        _drawHandle(canvas, w, h, const Color(0xFF8BA3B8));
        // no steam
        break;

      case CupState.cracked:
        _drawCupBody(canvas, w, h, const Color(0xFF8B4A48), full: true);
        _drawHandle(canvas, w, h, const Color(0xFF8B4A48));
        _drawCracks(canvas, w, h);
        break;

      case CupState.broken:
        _drawBrokenCup(canvas, w, h);
        break;
    }
  }

  // ── Cup body (trapezoid mug shape) ──────────────────────────────────────────

  void _drawCupBody(Canvas canvas, double w, double h, Color color,
      {required bool full}) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Reserve top 30% of height for steam
    final topY = h * 0.32;
    final botY = h * 0.88;
    final leftTop = w * 0.18;
    final rightTop = w * 0.82;
    final leftBot = w * 0.22;
    final rightBot = w * 0.78;

    final path = Path()
      ..moveTo(leftTop, topY)
      ..lineTo(leftBot, botY)
      ..lineTo(rightBot, botY)
      ..lineTo(rightTop, topY);

    // Bottom arc
    final bottomArc = Path()
      ..moveTo(leftBot, botY)
      ..quadraticBezierTo(w * 0.5, botY + h * 0.06, rightBot, botY);

    // Top rim line
    final rimPath = Path()
      ..moveTo(leftTop - w * 0.02, topY)
      ..lineTo(rightTop + w * 0.02, topY);

    canvas.drawPath(path, paint);
    canvas.drawPath(bottomArc, paint);
    canvas.drawPath(rimPath, paint);
  }

  // ── Handle ──────────────────────────────────────────────────────────────────

  void _drawHandle(Canvas canvas, double w, double h, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.07
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final startX = w * 0.78;
    final startY = h * 0.44;
    final endY = h * 0.68;

    path.moveTo(startX, startY);
    path.cubicTo(
      w * 1.1, startY,
      w * 1.1, endY,
      startX, endY,
    );

    canvas.drawPath(path, paint);
  }

  // ── Steam wisps ─────────────────────────────────────────────────────────────

  void _drawSteam(Canvas canvas, double w, double h, Color color,
      {required int count}) {
    final paint = Paint()
      ..color = color.withOpacity(0.5 + 0.4 * steamProgress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.055
      ..strokeCap = StrokeCap.round;

    final positions = count == 1
        ? [w * 0.5]
        : count == 2
        ? [w * 0.37, w * 0.63]
        : [w * 0.3, w * 0.5, w * 0.7];

    for (int i = 0; i < positions.length; i++) {
      final x = positions[i];
      final phase = (steamProgress + i / positions.length) % 1.0;
      final yOffset = h * 0.28 * phase;
      final topY = h * 0.28 - yOffset;

      final path = Path()
        ..moveTo(x, h * 0.28)
        ..cubicTo(
          x - w * 0.06, h * 0.28 - h * 0.08,
          x + w * 0.06, h * 0.28 - h * 0.16,
          x, topY,
        );

      canvas.drawPath(path, paint..color = color.withOpacity((1 - phase) * 0.7));
    }
  }

  // ── Crack lines ─────────────────────────────────────────────────────────────

  void _drawCracks(Canvas canvas, double w, double h) {
    final paint = Paint()
      ..color = const Color(0xFFFF6B6B).withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045
      ..strokeCap = StrokeCap.round;

    // Main crack — front of cup
    final crack1 = Path()
      ..moveTo(w * 0.42, h * 0.38)
      ..lineTo(w * 0.48, h * 0.52)
      ..lineTo(w * 0.44, h * 0.63)
      ..lineTo(w * 0.50, h * 0.78);

    // Small branch crack
    final crack2 = Path()
      ..moveTo(w * 0.48, h * 0.52)
      ..lineTo(w * 0.56, h * 0.60);

    canvas.drawPath(crack1, paint);
    canvas.drawPath(crack2, paint..strokeWidth = w * 0.03);
  }

  // ── Broken cup (scattered pieces) ───────────────────────────────────────────

  void _drawBrokenCup(Canvas canvas, double w, double h) {
    final paint = Paint()
      ..color = const Color(0xFF555555)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.07
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Bottom fragment — still looks like the base
    final bottom = Path()
      ..moveTo(w * 0.28, h * 0.72)
      ..lineTo(w * 0.35, h * 0.88)
      ..lineTo(w * 0.65, h * 0.88)
      ..lineTo(w * 0.72, h * 0.72);
    canvas.drawPath(bottom, paint);

    // Left wall fragment — tilted left
    canvas.save();
    canvas.translate(w * 0.18, h * 0.5);
    canvas.rotate(-0.35);
    final leftFrag = Path()
      ..moveTo(0, -h * 0.15)
      ..lineTo(-w * 0.02, h * 0.15);
    canvas.drawPath(leftFrag, paint);
    canvas.restore();

    // Right wall fragment — tilted right
    canvas.save();
    canvas.translate(w * 0.78, h * 0.5);
    canvas.rotate(0.35);
    final rightFrag = Path()
      ..moveTo(0, -h * 0.15)
      ..lineTo(w * 0.02, h * 0.15);
    canvas.drawPath(rightFrag, paint);
    canvas.restore();

    // Top rim fragment — floating above, rotated
    canvas.save();
    canvas.translate(w * 0.5, h * 0.2);
    canvas.rotate(0.15);
    final rimFrag = Path()
      ..moveTo(-w * 0.18, 0)
      ..lineTo(w * 0.12, 0);
    canvas.drawPath(rimFrag, paint);
    canvas.restore();

    // Small debris dot
    canvas.drawCircle(Offset(w * 0.62, h * 0.62), w * 0.03, paint..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(w * 0.3, h * 0.65), w * 0.025, paint);
  }

  @override
  bool shouldRepaint(_CupPainter old) =>
      old.state != state || old.steamProgress != steamProgress;
}

// ─── Bottom sheet ─────────────────────────────────────────────────────────────

class _StreakSheet extends StatelessWidget {
  final CupState state;
  final int streak;

  const _StreakSheet({required this.state, required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F0F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A3A),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 32),

            // Animated cup — larger version
            StreakCupSvg(state: state, size: 72),
            const SizedBox(height: 20),

            // Streak count
            if (streak > 0) ...[
              Text(
                '$streak',
                style: AppTypography.h2.copyWith(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: state.primaryColor,
                ),
              ),
              Text(
                streak == 1 ? 'day streak' : 'day streak',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // State label
            Text(
              state.label,
              style: AppTypography.h4.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Message
            Text(
              state.message,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // Streak legend row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _LegendItem(state: CupState.hot, label: '3+ days'),
                _LegendItem(state: CupState.warm, label: 'Active'),
                _LegendItem(state: CupState.cold, label: 'At risk'),
                _LegendItem(state: CupState.cracked, label: 'Cracking'),
                _LegendItem(state: CupState.broken, label: 'Broken'),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final CupState state;
  final String label;
  const _LegendItem({required this.state, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StreakCupSvg(state: state, size: 22),
        const SizedBox(height: 4),
        Text(label,
            style: AppTypography.bodySmall.copyWith(
              fontSize: 9,
              color: AppColors.textSecondary,
            )),
      ],
    );
  }
}
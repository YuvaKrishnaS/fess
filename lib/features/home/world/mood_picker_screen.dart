import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import 'providers/world_provider.dart';

// dat

class _MoodData {
  final String id;
  final String label;
  final String sublabel;
  final String asset;
  final Color bg;

  const _MoodData({
    required this.id,
    required this.label,
    required this.sublabel,
    required this.asset,
    required this.bg,
  });
}

const List<_MoodData> _moods = [
  _MoodData(
    id: 'happy',
    label: 'Happy',
    sublabel: 'Meet someone\nwho needs a lift.',
    asset: 'assets/illustrations/mood_happy.svg',
    bg: Color(0xFFF5F4EF),
  ),
  _MoodData(
    id: 'sad',
    label: 'Sad',
    sublabel: 'Meet someone\nwith warmth to share.',
    asset: 'assets/illustrations/mood_sad.svg',
    bg: Color(0xFFEFF2F7),
  ),
  _MoodData(
    id: 'angry',
    label: 'Angry',
    sublabel: 'Meet someone\ncalm enough to listen.',
    asset: 'assets/illustrations/mood_angry.svg',
    bg: Color(0xFFF7EFEF),
  ),
  _MoodData(
    id: 'calm',
    label: 'Calm',
    sublabel: 'Meet someone\nwho needs your stillness.',
    asset: 'assets/illustrations/mood_calm.svg',
    bg: Color(0xFFEFF7F2),
  ),
  _MoodData(
    id: 'excited',
    label: 'Excited',
    sublabel: 'Meet someone\nto ground your energy.',
    asset: 'assets/illustrations/mood_excited.svg',
    bg: Color(0xFFF7F2EF),
  ),
  _MoodData(
    id: 'neutral',
    label: 'Neutral',
    sublabel: 'Wide open.\nCould be anyone.',
    asset: 'assets/illustrations/mood_neutral.svg',
    bg: Color(0xFFEEEEEE),
  ),
];

// ---------------------------------------------------------------------------
// screen
// ---------------------------------------------------------------------------

class MoodPickerScreen extends ConsumerStatefulWidget {
  const MoodPickerScreen({super.key});

  @override
  ConsumerState<MoodPickerScreen> createState() => _MoodPickerScreenState();
}

class _MoodPickerScreenState extends ConsumerState<MoodPickerScreen>
    with SingleTickerProviderStateMixin {
  int _topIndex = 0;

  // drag state for top card
  double _dragX = 0;
  double _dragY = 0;
  bool _isDragging = false;
  bool _isFlying = false;
  Offset _flyTarget = Offset.zero;

  late AnimationController _flyCtrl;
  late Animation<Offset> _flyAnim;
  late Animation<double> _flyRotAnim;
  late Animation<double> _flyFadeAnim;
  // scale of the card behind top — grows from 0.92 to 1.0 as top flies out
  late Animation<double> _behindScaleAnim;

  @override
  void initState() {
    super.initState();
    _flyCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _resetFlyAnim();
  }

  void _resetFlyAnim() {
    _flyAnim = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(_flyCtrl);
    _flyRotAnim = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(_flyCtrl);
    _flyFadeAnim = Tween<double>(
      begin: 1,
      end: 0,
    ).animate(CurvedAnimation(parent: _flyCtrl, curve: const Interval(0.5, 1.0)));
    _behindScaleAnim = Tween<double>(
      begin: 0.93,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _flyCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _flyCtrl.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails _) {
    if (_isFlying) return;
    setState(() => _isDragging = true);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_isFlying) return;
    setState(() {
      _dragX += d.delta.dx;
      _dragY += d.delta.dy * 0.4;
    });
  }

  void _onDragEnd(DragEndDetails d) {
    if (_isFlying) return;
    final vx = d.velocity.pixelsPerSecond.dx;
    final threshold = 90.0;

    if (_dragX.abs() > threshold || vx.abs() > 500) {
      _flyCard(toRight: _dragX > 0 || vx > 0);
    } else {
      // snap back with spring
      setState(() {
        _dragX = 0;
        _dragY = 0;
        _isDragging = false;
      });
    }
  }

  void _flyCard({required bool toRight}) {
    HapticFeedback.lightImpact();
    final screenW = MediaQuery.of(context).size.width;
    final endX = toRight ? screenW * 1.6 : -screenW * 1.6;
    final endRot = toRight ? 0.45 : -0.45;

    _flyAnim = Tween<Offset>(
      begin: Offset(_dragX, _dragY),
      end: Offset(endX, _dragY + 40),
    ).animate(CurvedAnimation(parent: _flyCtrl, curve: Curves.easeInCubic));

    _flyRotAnim = Tween<double>(
      begin: (_dragX / 300).clamp(-0.25, 0.25),
      end: endRot,
    ).animate(CurvedAnimation(parent: _flyCtrl, curve: Curves.easeInCubic));

    _flyFadeAnim = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _flyCtrl, curve: const Interval(0.6, 1.0)));

    _behindScaleAnim = Tween<double>(
      begin: 0.93,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _flyCtrl, curve: Curves.easeOutCubic));

    setState(() => _isFlying = true);

    _flyCtrl.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() {
        _topIndex = (_topIndex + 1) % _moods.length;
        _dragX = 0;
        _dragY = 0;
        _isDragging = false;
        _isFlying = false;
      });
      _flyCtrl.reset();
      _resetFlyAnim();
    });
  }

  double get _tiltRad {
    if (_isFlying) return 0;
    return (_dragX / 320.0).clamp(-0.22, 0.22);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cardW = size.width * 0.78;
    final cardH = cardW * 1.25;
    final current = _moods[_topIndex];
    final next = _moods[(_topIndex + 1) % _moods.length];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ----------------------------------------------------------------
            // headline
            // ----------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How are you',
                    style: const TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                      letterSpacing: -1.0,
                    ),
                  ),
                  Text(
                    'feeling today?',
                    style: const TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF444455),
                      height: 1.1,
                      letterSpacing: -1.0,
                    ),
                  ),
                ],
              ),
            ),

            // ----------------------------------------------------------------
            // deck
            // ----------------------------------------------------------------
            Expanded(
              child: Center(
                child: SizedBox(
                  width: cardW,
                  height: cardH + 24,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // card 3 (furthest back) - static
                      _buildStaticBack(
                        mood: _moods[(_topIndex + 2) % _moods.length],
                        w: cardW,
                        h: cardH,
                        angle: 0.09,
                        offsetY: -10,
                        scale: 0.88,
                      ),

                      // card 2 (behind top) - scales up as top flies away
                      AnimatedBuilder(
                        animation: _flyCtrl,
                        builder: (ctx, _) {
                          final s = _isFlying
                              ? _behindScaleAnim.value
                              : 0.93;
                          return Transform.scale(
                            scale: s,
                            child: Transform.translate(
                              offset: const Offset(0, -5),
                              child: _CardFace(
                                mood: next,
                                width: cardW,
                                height: cardH,
                              ),
                            ),
                          );
                        },
                      ),

                      // top card (draggable)
                      GestureDetector(
                        onHorizontalDragStart: _onDragStart,
                        onHorizontalDragUpdate: _onDragUpdate,
                        onHorizontalDragEnd: _onDragEnd,
                        child: AnimatedBuilder(
                          animation: _flyCtrl,
                          builder: (ctx, _) {
                            Offset offset;
                            double rot;
                            double opacity;

                            if (_isFlying) {
                              offset = _flyAnim.value;
                              rot = _flyRotAnim.value;
                              opacity = _flyFadeAnim.value;
                            } else {
                              offset = Offset(
                                _dragX,
                                _dragY + math.sin(_dragX.abs() / 80) * -6,
                              );
                              rot = _tiltRad;
                              opacity = 1.0;
                            }

                            return Opacity(
                              opacity: opacity.clamp(0.0, 1.0),
                              child: Transform.translate(
                                offset: offset,
                                child: Transform.rotate(
                                  angle: rot,
                                  child: _CardFace(
                                    mood: current,
                                    width: cardW,
                                    height: cardH,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ----------------------------------------------------------------
            // dots
            // ----------------------------------------------------------------
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_moods.length, (i) {
                  final active = i == _topIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 18 : 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.white
                          : const Color(0xFF2A2A38),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 20),

            // ----------------------------------------------------------------
            // connect button
            // ----------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  ref.read(worldProvider.notifier).selectMood(current.id);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        'Connect as ${current.label}',
                        key: ValueKey(current.id),
                        style: const TextStyle(
                          fontFamily: 'DM Sans',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            Center(
              child: Text(
                'Swipe the card to explore moods',
                style: const TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 12,
                  color: Color(0xFF333344),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStaticBack({
    required _MoodData mood,
    required double w,
    required double h,
    required double angle,
    required double offsetY,
    required double scale,
  }) {
    return Transform.scale(
      scale: scale,
      child: Transform.translate(
        offset: Offset(0, offsetY),
        child: Transform.rotate(
          angle: angle,
          child: _CardFace(
            mood: mood,
            width: w,
            height: h,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// card face
// ---------------------------------------------------------------------------

class _CardFace extends StatelessWidget {
  final _MoodData mood;
  final double width;
  final double height;

  const _CardFace({
    required this.mood,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: mood.bg,
        borderRadius: BorderRadius.circular(22),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          // illustration — bottom right, clipped, contained in bottom 50%
          Positioned(
            right: 0,
            bottom: 0,
            child: SizedBox(
              width: width * 0.52,
              height: height * 0.50,
              child: SvgPicture.asset(
                mood.asset,
                fit: BoxFit.contain,
                placeholderBuilder: (_) => const SizedBox.shrink(),
              ),
            ),
          ),

          // text — top left, never competes with illustration
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // big mood word
                Text(
                  mood.label,
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0A0A0A),
                    height: 1.0,
                    letterSpacing: -2.0,
                  ),
                ),
                const SizedBox(height: 10),
                // sublabel - constrained width so it never touches illustration
                SizedBox(
                  width: width * 0.55,
                  child: Text(
                    mood.sublabel,
                    style: const TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF666666),
                      height: 1.55,
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import 'providers/world_provider.dart';

// card data

class _MoodCard {
  final String id;
  final String label;
  final String sublabel;
  final String illustrationAsset;
  final Color cardColor;
  final Color textColor;

  const _MoodCard({
    required this.id,
    required this.label,
    required this.sublabel,
    required this.illustrationAsset,
    required this.cardColor,
    required this.textColor,
  });
}

const List<_MoodCard> _cards = [
  _MoodCard(
    id: 'happy',
    label: 'Happy',
    sublabel: 'You will meet someone who needs a lift.',
    illustrationAsset: 'assets/illustrations/mood_happy.png',
    cardColor: Color(0xFFF5F5F0),
    textColor: Color(0xFF0A0A0A),
  ),
  _MoodCard(
    id: 'sad',
    label: 'Sad',
    sublabel: 'You will meet someone with warmth to share.',
    illustrationAsset: 'assets/illustrations/mood_sad.png',
    cardColor: Color(0xFFF0F0F5),
    textColor: Color(0xFF0A0A0A),
  ),
  _MoodCard(
    id: 'angry',
    label: 'Angry',
    sublabel: 'You will meet someone calm enough to listen.',
    illustrationAsset: 'assets/illustrations/mood_angry.png',
    cardColor: Color(0xFFF5F0F0),
    textColor: Color(0xFF0A0A0A),
  ),
  _MoodCard(
    id: 'calm',
    label: 'Calm',
    sublabel: 'You will meet someone who needs your steadiness.',
    illustrationAsset: 'assets/illustrations/mood_calm.png',
    cardColor: Color(0xFFF0F5F2),
    textColor: Color(0xFF0A0A0A),
  ),
  _MoodCard(
    id: 'excited',
    label: 'Excited',
    sublabel: 'You will meet someone to ground your energy.',
    illustrationAsset: 'assets/illustrations/mood_excited.png',
    cardColor: Color(0xFFF5F2EE),
    textColor: Color(0xFF0A0A0A),
  ),
  _MoodCard(
    id: 'neutral',
    label: 'Neutral',
    sublabel: 'You could meet anyone. Wide open.',
    illustrationAsset: 'assets/illustrations/mood_neutral.png',
    cardColor: Color(0xFFEEEEEE),
    textColor: Color(0xFF0A0A0A),
  ),
];

// SCREEN

class MoodPickerScreen extends ConsumerStatefulWidget {
  const MoodPickerScreen({super.key});

  @override
  ConsumerState<MoodPickerScreen> createState() => _MoodPickerScreenState();
}

class _MoodPickerScreenState extends ConsumerState<MoodPickerScreen>
    with TickerProviderStateMixin {
  int _topIndex = 0;

  // swipe drag state
  double _dragX = 0;
  bool _isDragging = false;

  late AnimationController _swipeCtrl;
  late Animation<Offset> _swipeAnim;

  late AnimationController _entryCtrl;
  late Animation<double> _entryFade;
  late Animation<Offset> _entrySlide;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.07),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    _swipeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _swipeAnim = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(_swipeCtrl);

    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _swipeCtrl.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    setState(() {
      _dragX += d.delta.dx;
      _isDragging = true;
    });
  }

  void _onDragEnd(DragEndDetails d) {
    final velocity = d.velocity.pixelsPerSecond.dx;
    final threshold = 80.0;

    if (_dragX < -threshold || velocity < -400) {
      _animateSwipe(left: true);
    } else if (_dragX > threshold || velocity > 400) {
      _animateSwipe(left: false);
    } else {
      // snap back
      setState(() {
        _dragX = 0;
        _isDragging = false;
      });
    }
  }

  void _animateSwipe({required bool left}) {
    HapticFeedback.selectionClick();
    final endX = left ? -1.5 : 1.5;

    _swipeAnim = Tween<Offset>(
      begin: Offset(_dragX / 400, 0),
      end: Offset(endX, 0),
    ).animate(CurvedAnimation(parent: _swipeCtrl, curve: Curves.easeInCubic));

    _swipeCtrl.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() {
        _topIndex =
            (_topIndex + (left ? 1 : -1) + _cards.length) % _cards.length;
        _dragX = 0;
        _isDragging = false;
      });
      _swipeCtrl.reset();
    });
  }

  void _goNext() => _animateSwipe(left: true);
  void _goPrev() => _animateSwipe(left: false);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cardW = size.width - 48.0;
    final cardH = cardW * 1.28;
    final current = _cards[_topIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: FadeTransition(
        opacity: _entryFade,
        child: SlideTransition(
          position: _entrySlide,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TOP LABEL
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WORLD',
                        style: const TextStyle(
                          fontFamily: 'DM Sans',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF555566),
                          letterSpacing: 2.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'How are you\nfeeling today?',
                        style: const TextStyle(
                          fontFamily: 'DM Sans',
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.15,
                          letterSpacing: -0.8,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // DECK
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: cardW,
                      height: cardH + 40,
                      child: GestureDetector(
                        onHorizontalDragUpdate: _onDragUpdate,
                        onHorizontalDragEnd: _onDragEnd,
                        child: Stack(
                          alignment: Alignment.topCenter,
                          clipBehavior: Clip.none,
                          children: [
                            // back cards (static, fanned)
                            ..._buildBackCards(cardW, cardH),
                            // top card (draggable)
                            _buildTopCard(cardW, cardH, current),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // PAGINATION DOTS
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_cards.length, (i) {
                      final active = i == _topIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOut,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: active ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white
                              : const Color(0xFF333340),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 28),

                // NAV ARROWS + CONNECT
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      //prev arrow
                      _ArrowBtn(icon: LucideIcons.arrowLeft, onTap: _goPrev),
                      const SizedBox(width: 12),
                      // connect button
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            ref
                                .read(worldProvider.notifier)
                                .selectMood(current.id);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 280),
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Text(
                                  'Connected as ${current.label}',
                                  key: ValueKey(current.id),
                                  style: const TextStyle(
                                    fontFamily: 'DM Sans',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // FOOTER NOTE
                Center(
                  child: Text(
                    'Your mood resets at midnight.',
                    style: const TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 12,
                      color: Color(0xFF444455),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // BACK CARDS: FAN BEHIND TOP CARD
  List<Widget> _buildBackCards(double w, double h) {
    // show up to 3 cards behind
    final result = <Widget>[];
    for (int offset = 3; offset >= 1; offset--) {
      final idx = (_topIndex + offset) % _cards.length;
      final card = _cards[idx];

      //fan angle: alternates left/right based on position
      final angle = (offset % 2 == 0 ? 1 : -1) * offset * 0.055;
      final scaleDown = 1.0 - offset * 0.04;
      final verticalOffset = offset * 6.0;

      result.add(
        Positioned(
          top: verticalOffset,
          child: Transform.rotate(
            angle: angle,
            child: Transform.scale(
              scale: scaleDown,
              child: _CardBody(
                card: card,
                width: w,
                height: h,
                dragX: 0,
                isTop: false,
              ),
            ),
          ),
        ),
      );
    }
    return result;
  }

  // ---- top card: draggable with tilt ---------------------------------------
  Widget _buildTopCard(double w, double h, _MoodCard card) {
    // calc tilt from drag
    final tiltAngle = (_dragX / 320.0).clamp(-0.18, 0.18);

    // swipe-out transform
    if (_swipeCtrl.isAnimating || _swipeCtrl.isCompleted) {
      return AnimatedBuilder(
        animation: _swipeCtrl,
        builder: (ctx, _) {
          final offset = _swipeAnim.value;
          return Transform.translate(
            offset: Offset(offset.dx * 400, offset.dy * 400),
            child: Transform.rotate(
              angle: offset.dx * 0.3,
              child: _CardBody(
                card: card,
                width: w,
                height: h,
                dragX: _dragX,
                isTop: true,
              ),
            ),
          );
        },
      );
    }

    return Transform.rotate(
      angle: tiltAngle,
      child: Transform.translate(
        offset: Offset(_dragX, math.sin(_dragX / 100).abs() * -8),
        child: _CardBody(
          card: card,
          width: w,
          height: h,
          dragX: _dragX,
          isTop: true,
        ),
      ),
    );
  }
}

// ---- card body ---------------------------------------------------------------

class _CardBody extends StatelessWidget {
  final _MoodCard card;
  final double width;
  final double height;
  final double dragX;
  final bool isTop;

  const _CardBody({
    required this.card,
    required this.width,
    required this.height,
    required this.dragX,
    required this.isTop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: card.cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          // ---- illustration bottom-right, cropped --------------------------
          Positioned(
            right: -20,
            bottom: -10,
            child: SizedBox(
              width: width * 0.68,
              height: width * 0.68,
              child: Image.asset(
                card.illustrationAsset,
                fit: BoxFit.contain,
                // graceful fallback if asset not yet added
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),

          // ---- text content ------------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // category chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'mood',
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: card.textColor.withOpacity(0.5),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                const Spacer(),

                // big mood word
                Text(
                  card.label,
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 58,
                    fontWeight: FontWeight.w900,
                    color: card.textColor,
                    height: 0.95,
                    letterSpacing: -2.0,
                  ),
                ),

                const SizedBox(height: 10),

                // sublabel
                SizedBox(
                  width: width * 0.58,
                  child: Text(
                    card.sublabel,
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: card.textColor.withOpacity(0.45),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ---- swipe hint arrows on top card only --------------------------
          if (isTop)
            Positioned(
              top: 22,
              right: 18,
              child: Row(
                children: [
                  Icon(
                    Icons.chevron_left_rounded,
                    size: 16,
                    color: card.textColor.withOpacity(0.18),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: card.textColor.withOpacity(0.18),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---- arrow button -----------------------------------------------------------

class _ArrowBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ArrowBtn({required this.icon, required this.onTap});

  @override
  State<_ArrowBtn> createState() => _ArrowBtnState();
}

class _ArrowBtnState extends State<_ArrowBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF111118),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF222230), width: 1.0),
          ),
          child: Icon(widget.icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/firebase_service.dart';
import '../../core/services/local_storage_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await Future.delayed(const Duration(milliseconds: 2600));
    if (!mounted) return;

    final hasSeenOnboarding = LocalStorageService.getHasSeenOnboarding();
    final user = FirebaseService.currentUser;

    if (!hasSeenOnboarding) {
      context.go('/onboarding');
    } else if (user == null) {
      context.go('/auth/login');
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      body: Stack(
        children: [
          // Purple glow behind logo — centered, large, soft
          Center(
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accentSecondary.withOpacity(0.28),
                    AppColors.accentSecondary.withOpacity(0.08),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            )
                .animate(
              onPlay: (controller) => controller.repeat(reverse: true),
            )
                .scaleXY(
              begin: 0.88,
              end: 1.08,
              duration: 2200.ms,
              curve: Curves.easeInOut,
            )
                .fadeIn(duration: 800.ms),
          ),

          // Logo centered
          Center(
            child: Image.asset(
              'assets/images/logo.png',
              width: 90,
              height: 90,
            )
                .animate()
                .fadeIn(duration: 650.ms, curve: Curves.easeOut)
                .scale(
              begin: const Offset(0.55, 0.55),
              end: const Offset(1.0, 1.0),
              duration: 700.ms,
              curve: Curves.easeOutBack,
            ),
          ),

          // 3 pulsing dots at bottom
          Positioned(
            bottom: 72,
            left: 0,
            right: 0,
            child: Center(
              child: _PulsingDots(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 3 pulsing dots ───────────────────────────────────────────────────────────
class _PulsingDots extends StatefulWidget {
  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  static const int _dotCount = 3;
  static const Duration _pulseDuration = Duration(milliseconds: 600);
  static const Duration _stagger = Duration(milliseconds: 180);

  @override
  void initState() {
    super.initState();

    _controllers = List.generate(
      _dotCount,
          (i) => AnimationController(vsync: this, duration: _pulseDuration),
    );

    _animations = _controllers.map((c) {
      return Tween<double>(begin: 0.35, end: 1.0).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      );
    }).toList();

    _startSequence();
  }

  Future<void> _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    _runLoop();
  }

  Future<void> _runLoop() async {
    while (mounted) {
      for (int i = 0; i < _dotCount; i++) {
        if (!mounted) return;
        _controllers[i].forward(from: 0.0);
        await Future.delayed(_stagger);
      }
      await Future.delayed(
          Duration(milliseconds: _pulseDuration.inMilliseconds + 120));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_dotCount, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: AnimatedBuilder(
            animation: _animations[i],
            builder: (context, _) {
              return Opacity(
                opacity: _animations[i].value,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accentPrimary,
                  ),
                ),
              );
            },
          ),
        );
      }),
    )
        .animate()
        .fadeIn(delay: 900.ms, duration: 400.ms);
  }
}
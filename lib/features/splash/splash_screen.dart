import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/firebase_service.dart';
import '../../core/services/local_storage_service.dart';
import '../auth/providers/auth_provider.dart';

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
      final authService = AuthService();
      final anonId = await authService.getAnonId();
      if (!mounted) return;
      if (anonId == null) {
        context.go('/persona/create');
      } else {
        context.go('/home');
      }
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
          )
        ],
      ),
    );
  }
}

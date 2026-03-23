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
    await Future.delayed(const Duration(milliseconds: 2400));
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 88,
              height: 88,
            )
                .animate()
                .fadeIn(duration: 700.ms, curve: Curves.easeOut)
                .scale(
              begin: const Offset(0.65, 0.65),
              end: const Offset(1.0, 1.0),
              duration: 700.ms,
              curve: Curves.easeOutBack,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.accentPrimary.withOpacity(0.6),
                ),
              ),
            ).animate().fadeIn(delay: 900.ms, duration: 400.ms),
          ],
        ),
      ),
    );
  }
}
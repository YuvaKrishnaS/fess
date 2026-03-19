import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/local_storage_service.dart';
import '../../core/services/firebase_service.dart';

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
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final hasSeenOnboarding = LocalStorageService.getHasSeenOnboarding();
    final user = FirebaseService.currentUser;

    if (!hasSeenOnboarding) {
      context.go('/onboarding');
      return;
    }

    if (user == null) {
      // Not authenticated - go to email verification
      context.go('/auth/login');
    } else {
      // Authenticated (later we’ll also check persona)
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
              width: 80,
              height: 80,
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.accentPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

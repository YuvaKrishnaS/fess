import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';

class OnboardingPage4 extends StatelessWidget {
  const OnboardingPage4({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),

          // Heart in glass illustration
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: RadialGradient(
                colors: [
                  AppColors.accentSecondary.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              size: 100,
              color: AppColors.accentSecondary,
            ),
          ),

          const SizedBox(height: 48),

          // Title with gradient
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: AppTypography.h1,
              children: [
                const TextSpan(text: 'Welcome to '),
                TextSpan(
                  text: 'Fess',
                  style: AppTypography.h1.copyWith(
                    color: AppColors.accentPrimary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Description
          Text(
            'A safe space for honest stories, hidden feelings, and real connections. We value vulnerability over vanity. You are anonymous here, but you are never alone.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),

          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

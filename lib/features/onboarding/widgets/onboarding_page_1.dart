import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';

class OnboardingPage1 extends StatelessWidget {
  const OnboardingPage1({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),

          // Shield illustration
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.accentSecondary.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              size: 120,
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
                const TextSpan(text: 'You Have the '),
                TextSpan(
                  text: 'Power',
                  style: AppTypography.h1.copyWith(
                    foreground: Paint()
                      ..shader = const LinearGradient(
                        colors: [
                          AppColors.accentSecondary,
                          AppColors.accentPrimary,
                        ],
                      ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Description
          Text(
            'Anonymity is a responsibility. Own your posts and report toxicity if you see it. By entering, you agree to keep Fess safe for everyone.',
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

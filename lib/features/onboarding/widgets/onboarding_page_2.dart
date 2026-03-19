import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';

class OnboardingPage2 extends StatelessWidget {
  const OnboardingPage2({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),

          // Shield with eye illustration
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.accentPrimary.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
            child: const Icon(
              Icons.remove_red_eye_outlined,
              size: 120,
              color: AppColors.accentPrimary,
            ),
          ),

          const SizedBox(height: 48),

          // Title with gradient
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: AppTypography.h1,
              children: [
                const TextSpan(text: 'Keep It '),
                TextSpan(
                  text: 'Safe',
                  style: AppTypography.h1.copyWith(
                    color: AppColors.accentPrimary,
                  ),
                ),
                const TextSpan(text: ' & '),
                TextSpan(
                  text: 'Clean',
                  style: AppTypography.h1.copyWith(
                    color: AppColors.accentSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Description
          Text(
            'No graphic violence, nudity, or illegal content. Keep shares emotional, not explicit. We strictly prohibit content that harms minors or promotes self-harm.',
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

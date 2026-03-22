import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';

class OnboardingBase extends StatelessWidget {
  final String imagePath;
  final String title;
  final String? highlightWord;
  final String body;

  const OnboardingBase({
    super.key,
    required this.imagePath,
    required this.title,
    this.highlightWord,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final parts = (highlightWord != null && title.contains(highlightWord!))
        ? title.split(highlightWord!)
        : null;

    return Column(
      children: [
        const SizedBox(height: 16),
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                imagePath,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms, curve: Curves.easeOut),
        ),
        const SizedBox(height: 32),
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: AppTypography.h2,
                    children: parts != null
                        ? [
                      TextSpan(text: parts[0]),
                      TextSpan(
                        text: highlightWord!,
                        style: AppTypography.h2.copyWith(
                          color: AppColors.accentSecondary,
                        ),
                      ),
                      if (parts.length > 1) TextSpan(text: parts[1]),
                    ]
                        : [TextSpan(text: title)],
                  ),
                )
                    .animate()
                    .fadeIn(delay: 150.ms, duration: 350.ms)
                    .slideY(begin: 0.15, end: 0, delay: 150.ms, duration: 350.ms, curve: Curves.easeOut),
                const SizedBox(height: 16),
                Text(
                  body,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                )
                    .animate()
                    .fadeIn(delay: 250.ms, duration: 350.ms)
                    .slideY(begin: 0.1, end: 0, delay: 250.ms, duration: 350.ms, curve: Curves.easeOut),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
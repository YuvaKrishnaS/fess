import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';

class _GuidelineSection {
  final String title;
  final String body;
  const _GuidelineSection(this.title, this.body);
}

const _sections = [
  _GuidelineSection(
    'Respect anonymity',
    'Do not attempt to reveal, guess, or expose the real identity of any user. Anonymity is the foundation of Fess and applies to everyone equally.',
  ),
  _GuidelineSection(
    'No harassment or bullying',
    'Targeted harassment, threats, or repeated unwanted contact toward another user will result in a permanent ban, regardless of anonymity.',
  ),
  _GuidelineSection(
    'No hate speech',
    'Content that attacks people based on race, religion, gender, sexuality, or disability is not tolerated anywhere on the platform.',
  ),
  _GuidelineSection(
    'No illegal content',
    'Do not post, request, or share anything illegal, including but not limited to explicit content involving minors, violence, or illegal substances.',
  ),
  _GuidelineSection(
    'No spam or impersonation',
    'Do not impersonate other users, public figures, or Fess staff. Do not use the platform to spam links, scams, or repetitive content.',
  ),
  _GuidelineSection(
    'Reporting',
    'If you encounter content or behavior that violates these guidelines, use Report a Problem in Settings. Every report is reviewed directly by our team.',
  ),
];

class CommunityGuidelinesScreen extends StatelessWidget {
  const CommunityGuidelinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(LucideIcons.arrowLeft,
                        color: AppColors.textPrimary, size: 20),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Community Guidelines',
                    style: AppTypography.h3.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: _sections.length,
                separatorBuilder: (_, __) => const SizedBox(height: 20),
                itemBuilder: (ctx, i) {
                  final s = _sections[i];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.title,
                        style: AppTypography.bodyMedium.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        s.body,
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.7,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
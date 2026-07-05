import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';

class _FaqItem {
  final String question;
  final String answer;
  const _FaqItem(this.question, this.answer);
}

const _faqs = [
  _FaqItem(
    'Is Fess really anonymous?',
    'Yes. Your identity is never tied to your real name, phone number, or email anywhere in the app. Your persona (username and avatar) is the only thing others ever see.',
  ),
  _FaqItem(
    'What happens to my streak if I miss a day?',
    'Your streak resets to zero if you go a full 24 hours without posting, commenting, or engaging. You will get a reminder notification before that happens if streak reminders are turned on.',
  ),
  _FaqItem(
    'Can someone find out who I am from a DM?',
    'No. Direct messages use the same anonymous persona system as the rest of the app. There is no way for another user to see your real identity through chat.',
  ),
  _FaqItem(
    'Why can I only change my avatar and not my username?',
    'Your username is your permanent identity inside Fess and is used to keep conversations and posts consistent. Only your avatar persona can be changed at any time.',
  ),
  _FaqItem(
    'How do I report someone or something inappropriate?',
    'Use Report a Problem in Settings, or Contact Us. Both open a pre-filled email to our support inbox so we can review it directly.',
  ),
  _FaqItem(
    'Do you store my messages on a server forever?',
    'Messages are stored securely to allow syncing across sessions. Deleted messages are marked as removed and are no longer visible to anyone in the conversation.',
  ),
];

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  int? _expandedIndex;

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
                    'Help Center',
                    style: AppTypography.h3.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: _faqs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final faq = _faqs[i];
                  final expanded = _expandedIndex == i;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _expandedIndex = expanded ? null : i);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111111),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  faq.question,
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              AnimatedRotation(
                                turns: expanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: const Icon(LucideIcons.chevronDown,
                                    size: 18, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                          AnimatedCrossFade(
                            duration: const Duration(milliseconds: 200),
                            crossFadeState: expanded
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                            firstChild: const SizedBox.shrink(),
                            secondChild: Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                faq.answer,
                                style: AppTypography.bodySmall.copyWith(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
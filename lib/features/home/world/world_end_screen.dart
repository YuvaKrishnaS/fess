import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/local_storage_service.dart';
import 'providers/world_provider.dart';

class WorldEndScreen extends ConsumerWidget {
  const WorldEndScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worldState = ref.watch(worldProvider);
    final session = worldState.session;
    final myAnonId = LocalStorageService.getCachedAnonId() ?? '';

    final wasSkipped = session?.status == 'skipped';
    final iSkipped = wasSkipped && session?.endedBy == myAnonId;

    final partnerAnonId = session?.participantIds
        .firstWhere((id) => id != myAnonId, orElse: () => '');
    final partnerProfile =
    session?.participantProfiles[partnerAnonId] as Map<String, dynamic>?;
    final partnerUsername =
        partnerProfile?['username'] as String? ?? 'someone';

    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 72),

              // Big emoji
              Text(
                iSkipped ? '⏭️' : '⏰',
                style: const TextStyle(fontSize: 56),
              ),
              const SizedBox(height: 24),

              Text(
                iSkipped ? 'You skipped.' : 'Time\'s up!',
                style: AppTypography.h2.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              Text(
                iSkipped
                    ? 'The conversation ended.\nHope you find your vibe next time.'
                    : 'Your 5 minutes with @$partnerUsername just ended.\nDid you vibe?',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.55,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // DM button (placeholder — wires to DM feature later)
              if (!iSkipped && partnerAnonId != null && partnerAnonId.isNotEmpty)
                _ActionBtn(
                  label: 'Send @$partnerUsername a DM',
                  icon: Icons.mail_outline_rounded,
                  primary: true,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    // TODO: wire to DM feature
                    // Navigator.push(context, dmRoute(partnerAnonId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('DMs coming soon!')),
                    );
                  },
                ),

              if (!iSkipped) const SizedBox(height: 12),

              // Find next
              _ActionBtn(
                label: 'Find next person',
                icon: Icons.shuffle_rounded,
                primary: false,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(worldProvider.notifier).findNext();
                },
              ),

              const SizedBox(height: 12),

              // Change mood
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(worldProvider.notifier).changeMood();
                },
                child: Text(
                  'Change my mood',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: primary
              ? AppColors.accentPrimary
              : const Color(0xFF111118),
          borderRadius: BorderRadius.circular(14),
          border: primary
              ? null
              : Border.all(color: const Color(0xFF2A2A3A), width: 0.8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18, color: primary ? Colors.black : AppColors.textPrimary),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: primary ? Colors.black : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
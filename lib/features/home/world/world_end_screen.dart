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
    final state = ref.watch(worldProvider);
    final session = state.session;
    final myAnonId = LocalStorageService.getCachedAnonId() ?? '';

    final partnerId = session?.participantIds
        .firstWhere((id) => id != myAnonId, orElse: () => '') ??
        '';
    final partnerProfile =
        session?.participantProfiles[partnerId] as Map<String, dynamic>? ?? {};
    final partnerUsername =
        partnerProfile['username'] as String? ?? 'them';

    final wasSkipped = session?.status == 'skipped';
    final iSkipped = session?.endedBy == myAnonId;

    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),

              // headline
              Text(
                iSkipped ? 'You left.' : "Time's up.",
                style: const TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  height: 1.0,
                  letterSpacing: -2.0,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                iSkipped
                    ? 'maybe next time'
                    : 'hope it was worth it',
                style: const TextStyle(
                  fontFamily: 'DM Serif Display',
                  fontStyle: FontStyle.italic,
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
              ),

              const Spacer(flex: 3),

              // partner line
              if (partnerId.isNotEmpty && !iSkipped) ...[
                Text(
                  'You talked to @$partnerUsername',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.hintText,
                  ),
                ),
                const SizedBox(height: 28),
              ],

              // DM button - only if session was not skipped by current user
              if (partnerId.isNotEmpty && !iSkipped) ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      // TODO: navigate to DM thread (M11)
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Center(
                        child: Text(
                          'Send @$partnerUsername a message',
                          style: const TextStyle(
                            fontFamily: 'DM Sans',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.backgroundMain,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // find next
              SizedBox(
                width: double.infinity,
                height: 52,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(worldProvider.notifier).findNext();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.borderSubtle,
                        width: 0.8,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Find someone new',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // change mood
              Center(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(worldProvider.notifier).changeMood();
                  },
                  child: Text(
                    'Change my mood',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.hintText,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.hintText,
                    ),
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
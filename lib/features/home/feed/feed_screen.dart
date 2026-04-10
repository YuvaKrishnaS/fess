import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/firebase_service.dart';
import 'widgets/feed_empty_state.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // remove this in M4
    final userEmail = FirebaseService.currentUser?.email ?? 'Anonymous user';

    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundMain,
            border: Border(
              bottom: BorderSide(
                color: AppColors.elevated,
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            child: SizedBox(
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // profile icon left side
                  Positioned(
                    left: 16,
                    child: GestureDetector(
                      onTap: () {
                        // TODO M7: open profile
                      },
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.elevated,
                              border: Border.all(
                                color: AppColors.elevated,
                                width: 0.5,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                LucideIcons.user,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // logo center
                  Image.asset(
                    'assets/images/logo.png',
                    width: 28,
                    height: 28,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // remove this in M4
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.elevated,
                  width: 0.5,
                ),
              ),
            ),
            child: Text(
              userEmail,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.accentPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const Expanded(child: FeedEmptyState()),
        ],
      ),
    );
  }
}
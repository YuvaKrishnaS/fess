// import 'package:flutter/material.dart';
// import '../../../core/constants/app_colors.dart';
// import '../../../core/constants/app_typography.dart';
// import 'widgets/feed_empty_state.dart';
// import '../../../core/services/firebase_service.dart';
//
// class FeedScreen extends StatelessWidget {
//   const FeedScreen({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     // TODO: Replace with actual feed data in later milestones
//     final bool hasContent = false;
//     final userEmail = FirebaseService.currentUser?.email ?? 'Not signed in';
//
//     return Scaffold(
//       backgroundColor: AppColors.backgroundMain,
//       appBar: AppBar(
//         title: Image.asset(
//           'assets/images/logo.png',
//           width: 32,
//           height: 32,
//         ),
//         centerTitle: true,
//       ),
//       body: hasContent
//           ? _buildFeedList()
//           : const FeedEmptyState(),
//     );
//   }
//
//   Widget _buildFeedList() {
//     // Placeholder for actual feed
//     return ListView.builder(
//       itemCount: 10,
//       padding: const EdgeInsets.symmetric(vertical: 8),
//       itemBuilder: (context, index) {
//         return Container(
//           margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//           padding: const EdgeInsets.all(16),
//           decoration: BoxDecoration(
//             color: AppColors.elevated,
//             borderRadius: BorderRadius.circular(12),
//           ),
//           child: Text(
//             'Post placeholder',
//             style: AppTypography.bodyMedium,
//           ),
//         );
//       },
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/firebase_service.dart';
import 'widgets/feed_empty_state.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Remove this in next milestone
    final userEmail = FirebaseService.currentUser?.email ?? 'Not signed in';

    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      appBar: AppBar(
        title: Image.asset(
          'assets/images/logo.png',
          width: 32,
          height: 32,
        ),
        centerTitle: true,
        // TODO: Remove subtitle in next milestone
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Signed in as: $userEmail',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.accentPrimary,
              ),
            ),
          ),
        ),
      ),
      body: const FeedEmptyState(),
    );
  }
}
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import 'widgets/feed_empty_state.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Replace with actual feed data in later milestones
    final bool hasContent = false;

    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      appBar: AppBar(
        title: Image.asset(
          'assets/images/logo.png',
          width: 32,
          height: 32,
        ),
        centerTitle: true,
      ),
      body: hasContent
          ? _buildFeedList()
          : const FeedEmptyState(),
    );
  }

  Widget _buildFeedList() {
    // Placeholder for actual feed
    return ListView.builder(
      itemCount: 10,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.elevated,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Post placeholder',
            style: AppTypography.bodyMedium,
          ),
        );
      },
    );
  }
}

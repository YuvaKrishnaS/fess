import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/models/avatar_config.dart';
import '../../../core/models/post_model.dart';

class ConfessionCard extends StatelessWidget {
  final PostModel post;
  final String? currentAnonId;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onWitness;

  const ConfessionCard({
    super.key,
    required this.post,
    required this.currentAnonId,
    required this.onTap,
    required this.onLike,
    required this.onWitness,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFF1A1A28), width: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(
              post: post,
              currentAnonId: currentAnonId,
              onWitness: onWitness,
            ),
            const SizedBox(height: 10),
            _CardBody(post: post),
            const SizedBox(height: 12),
            _CardReactions(post: post, onLike: onLike),
          ],
        ),
      ),
    );
  }
}

// ─── Header row ───────────────────────────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  final PostModel post;
  final String? currentAnonId;
  final VoidCallback onWitness;

  const _CardHeader({
    required this.post,
    required this.currentAnonId,
    required this.onWitness,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = post.authorAvatarConfig != null
        ? AvatarConfig.fromMap(post.authorAvatarConfig!).buildUrl(size: 36)
        : null;

    return Row(
      children: [
        _AuthorAvatar(avatarUrl: avatarUrl),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '@${post.authorUsername ?? 'anon'}',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '· ${_timeAgo(post.createdAt)}',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Hide Witness button on own posts
        if (post.authorId != currentAnonId)
          _WitnessButton(onTap: onWitness),
      ],
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}w';
  }
}

class _AuthorAvatar extends StatelessWidget {
  final String? avatarUrl;

  const _AuthorAvatar({this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.border,
          width: 1,
        ),
        color: AppColors.elevated,
      ),
      child: ClipOval(
        child: avatarUrl != null
            ? CachedNetworkImage(
          imageUrl: avatarUrl!,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          placeholder: (_, __) => const SizedBox(),
          errorWidget: (_, __, ___) => Center(
            child: Icon(
              LucideIcons.user,
              size: 18,
              color: AppColors.hintText,
            ),
          ),
        )
            : Center(
          child: Icon(
            LucideIcons.user,
            size: 18,
            color: AppColors.hintText,
          ),
        ),
      ),
    );
  }
}

class _WitnessButton extends StatelessWidget {
  final VoidCallback onTap;

  const _WitnessButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 90,
        height: 30,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.accentPrimary, width: 1),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Center(
          child: Text(
            '+ Witness',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.accentPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _CardBody extends StatelessWidget {
  final PostModel post;

  const _CardBody({required this.post});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          post.heading,
          style: AppTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        if (post.body != null && post.body!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            post.body!,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (post.imageUrls.isNotEmpty) ...[
          const SizedBox(height: 10),
          _CardImage(imageUrl: post.imageUrls.first),
        ],
      ],
    );
  }
}

class _CardImage extends StatelessWidget {
  final String imageUrl;

  const _CardImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: AppColors.elevated),
          errorWidget: (_, __, ___) => Container(
            color: AppColors.elevated,
            child: Center(
              child: Icon(
                LucideIcons.imageOff,
                color: AppColors.hintText,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Reactions row ────────────────────────────────────────────────────────────

class _CardReactions extends StatelessWidget {
  final PostModel post;
  final VoidCallback onLike;

  const _CardReactions({required this.post, required this.onLike});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ReactionButton(
          icon: LucideIcons.messageCircle,
          count: post.commentCount,
          color: AppColors.textSecondary,
          onTap: () {},
        ),
        const SizedBox(width: 16),
        _LikeButton(post: post, onLike: onLike),
        const Spacer(),
        _ReactionButton(
          icon: LucideIcons.share2,
          count: null,
          color: AppColors.textSecondary,
          onTap: () {},
        ),
      ],
    );
  }
}

class _ReactionButton extends StatelessWidget {
  final IconData icon;
  final int? count;
  final Color color;
  final VoidCallback onTap;

  const _ReactionButton({
    required this.icon,
    required this.count,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            if (count != null) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: AppTypography.bodySmall.copyWith(color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LikeButton extends StatefulWidget {
  final PostModel post;
  final VoidCallback onLike;

  const _LikeButton({required this.post, required this.onLike});

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.8), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.2), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 30),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.selectionClick();
    _controller.forward(from: 0);
    widget.onLike();
  }

  @override
  Widget build(BuildContext context) {
    final isLiked = widget.post.isLiked;
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _scale,
              builder: (_, __) => Transform.scale(
                scale: _scale.value,
                child: Icon(
                  isLiked ? LucideIcons.heart : LucideIcons.heart,
                  size: 16,
                  color: isLiked
                      ? const Color(0xFFFF6B6B)
                      : AppColors.textSecondary,
                  fill: isLiked ? 1.0 : 0.0,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${widget.post.likeCount}',
              style: AppTypography.bodySmall.copyWith(
                color: isLiked
                    ? const Color(0xFFFF6B6B)
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shimmer loading card ─────────────────────────────────────────────────────

class ConfessionShimmerCard extends StatelessWidget {
  const ConfessionShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF1A1A28), width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Shimmer(width: 36, height: 36, radius: 18),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Shimmer(width: 100, height: 12),
                  const SizedBox(height: 4),
                  _Shimmer(width: 60, height: 10),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Shimmer(width: double.infinity * 0.6, height: 14),
          const SizedBox(height: 6),
          _Shimmer(width: double.infinity, height: 12),
          const SizedBox(height: 4),
          _Shimmer(width: double.infinity * 0.75, height: 12),
          const SizedBox(height: 12),
          Row(
            children: [
              _Shimmer(width: 40, height: 12),
              const SizedBox(width: 16),
              _Shimmer(width: 40, height: 12),
            ],
          ),
        ],
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
      duration: 1500.ms,
      color: AppColors.elevated,
    );
  }
}

class _Shimmer extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _Shimmer({
    required this.width,
    required this.height,
    this.radius = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class FeedEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const FeedEmptyState({
    super.key,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.hintText),
            const SizedBox(height: 16),
            Text(
              message,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOut);
  }
}
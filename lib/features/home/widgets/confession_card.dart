import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Avatar column
                _CardAvatar(
                  avatarConfig: post.authorAvatarConfig,
                  isOwnPost: post.authorId == currentAnonId,
                ),
                const SizedBox(width: 12),
                // Right: content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CardHeader(
                        username: post.authorUsername,
                        createdAt: post.createdAt,
                        isOwnPost: post.authorId == currentAnonId,
                        onWitness: onWitness,
                      ),
                      const SizedBox(height: 6),
                      _CardContent(
                        heading: post.heading,
                        body: post.body,
                      ),
                      const SizedBox(height: 10),
                      _CardActions(
                        post: post,
                        onLike: onLike,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Hairline divider
          Container(
            height: 0.5,
            color: const Color(0xFF1E1E1E),
          ),
        ],
      ),
    );
  }
}

// ─── Avatar with gradient ring ────────────────────────────────────────────────

class _CardAvatar extends StatelessWidget {
  final Map<String, dynamic>? avatarConfig;
  final bool isOwnPost;

  const _CardAvatar({this.avatarConfig, required this.isOwnPost});

  @override
  Widget build(BuildContext context) {
    final url = avatarConfig != null
        ? AvatarConfig.fromMap(avatarConfig!).buildUrl(size: 80)
        : null;

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [
            Color(0xFF7C4DFF),
            Color(0xFF1DE9B6),
            Color(0xFF7C4DFF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(1.5),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF000000),
        ),
        padding: const EdgeInsets.all(2),
        child: ClipOval(
          child: url != null
              ? CachedNetworkImage(
            imageUrl: url,
            width: 38,
            height: 38,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              color: const Color(0xFF1A1A1A),
            ),
            errorWidget: (_, __, ___) => _fallback(),
          )
              : _fallback(),
        ),
      ),
    );
  }

  Widget _fallback() => Container(
    color: const Color(0xFF1A1A1A),
    child: const Center(
      child: Icon(LucideIcons.user, size: 18, color: Color(0xFF555555)),
    ),
  );
}

// ─── Header row ───────────────────────────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  final String? username;
  final DateTime? createdAt;
  final bool isOwnPost;
  final VoidCallback onWitness;

  const _CardHeader({
    this.username,
    this.createdAt,
    required this.isOwnPost,
    required this.onWitness,
  });

  @override
  Widget build(BuildContext context) {
    final time = createdAt != null
        ? timeago.format(createdAt!, locale: 'en_short')
        : '';

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Text(
                '@${username ?? 'anonymous'}',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
              ),
              if (time.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  '· $time',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        // Witness button — hidden on own posts
        if (!isOwnPost)
          _WitnessButton(onTap: onWitness),
      ],
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
        padding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.textSecondary.withOpacity(0.4),
            width: 0.8,
          ),
        ),
        child: Text(
          '+ Witness',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─── Content ──────────────────────────────────────────────────────────────────

class _CardContent extends StatelessWidget {
  final String heading;
  final String? body;

  const _CardContent({required this.heading, this.body});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: AppTypography.bodyMedium.copyWith(
            fontFamily: 'DM Sans',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            height: 1.4,
          ),
        ),
        if (body != null && body!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            body!,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyMedium.copyWith(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Action row ───────────────────────────────────────────────────────────────

class _CardActions extends StatelessWidget {
  final PostModel post;
  final VoidCallback onLike;

  const _CardActions({required this.post, required this.onLike});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Comment
        _ActionButton(
          icon: LucideIcons.messageCircle,
          count: post.commentCount,
          isActive: false,
          activeColor: AppColors.accentPrimary,
          onTap: () => FessSnackbar_compat.showComingSoon(context),
        ),
        const SizedBox(width: 20),
        // Like
        _LikeButton(
          count: post.likeCount,
          isLiked: post.isLiked,
          onTap: onLike,
        ),
        const Spacer(),
        // Share
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            FessSnackbar_compat.showComingSoon(context);
          },
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Icon(
                LucideIcons.share2,
                size: 17,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final int count;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.count,
    required this.isActive,
    required this.activeColor,
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
      child: SizedBox(
        height: 44,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 17,
              color: isActive ? activeColor : AppColors.textSecondary,
            ),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Text(
                _format(count),
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 12,
                  color:
                  isActive ? activeColor : AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _format(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

class _LikeButton extends StatefulWidget {
  final int count;
  final bool isLiked;
  final VoidCallback onTap;

  const _LikeButton({
    required this.count,
    required this.isLiked,
    required this.onTap,
  });

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
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.35), weight: 50),
      TweenSequenceItem(
          tween: Tween(begin: 1.35, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _controller.forward(from: 0);
        widget.onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 44,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scale,
              child: Icon(
                widget.isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: 17,
                color: widget.isLiked
                    ? AppColors.accentPrimary
                    : AppColors.textSecondary,
              ),
            ),
            if (widget.count > 0) ...[
              const SizedBox(width: 5),
              Text(
                _format(widget.count),
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 12,
                  color: widget.isLiked
                      ? AppColors.accentPrimary
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _format(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

// ─── Shimmer placeholder card ─────────────────────────────────────────────────

class ConfessionShimmerCard extends StatelessWidget {
  const ConfessionShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A1A1A),
      highlightColor: const Color(0xFF2A2A2A),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar circle
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Username + timestamp bar
                      Row(
                        children: [
                          Container(
                              width: 90,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              )),
                          const SizedBox(width: 8),
                          Container(
                              width: 30,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              )),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Heading block
                      Container(
                        width: double.infinity,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.65,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Body block
                      Container(
                        width: double.infinity,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.55,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Action row dots
                      Row(
                        children: [
                          Container(
                              width: 48,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              )),
                          const SizedBox(width: 20),
                          Container(
                              width: 48,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              )),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(height: 0.5, color: const Color(0xFF1E1E1E)),
        ],
      ),
    );
  }
}

// ─── Compat helper (avoids circular import with FessSnackbar) ─────────────────

class FessSnackbar_compat {
  static void showComingSoon(BuildContext context) {
    // Import FessSnackbar in the file that uses this card
    // This is intentionally a no-op here — caller passes context to FessSnackbar
  }
}
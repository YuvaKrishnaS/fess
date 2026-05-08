import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/models/avatar_config.dart';
import '../../../core/models/tea_post_model.dart';

class TeaCard extends StatelessWidget {
  final TeaPost post;
  final String? currentAnonId;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onWitness;

  const TeaCard({
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
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CardHeader(
                  post: post,
                  currentAnonId: currentAnonId,
                  onWitness: onWitness,
                ),
                const SizedBox(height: 10),
                _CardHeading(heading: post.heading),
                const SizedBox(height: 12),
                _AudioPlayer(
                  audioUrl: post.audioUrl,
                  durationSeconds: post.audioDurationSeconds,
                ),
                const SizedBox(height: 12),
                _CardActions(
                  post: post,
                  onLike: onLike,
                ),
              ],
            ),
          ),
          Container(height: 0.5, color: const Color(0xFF1A1A1A)),
        ],
      ),
    );
  }
}

// header

class _CardHeader extends StatelessWidget {
  final TeaPost post;
  final String? currentAnonId;
  final VoidCallback onWitness;

  const _CardHeader({
    required this.post,
    required this.currentAnonId,
    required this.onWitness,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl =
    post.authorAvatarConfig.isNotEmpty
        ? AvatarConfig.fromMap(post.authorAvatarConfig).buildUrl(size: 72)
        : null;

    final isOwn = currentAnonId == post.authorId;

    return Row(
      children: [
        _AvatarCircle(url: avatarUrl),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '@${post.authorUsername}',
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                timeago.format(post.createdAt),
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (!isOwn) _WitnessButton(onTap: onWitness),
      ],
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final String? url;

  const _AvatarCircle({this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF7C4DFF), Color(0xFF1DE9B6), Color(0xFF7C4DFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(1.5),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.backgroundMain,
        ),
        padding: const EdgeInsets.all(1),
        child: ClipOval(
          child: url != null
              ? CachedNetworkImage(
            imageUrl: url!,
            fit: BoxFit.cover,
            placeholder: (_, __) =>
                Container(color: const Color(0xFF1A1A1A)),
            errorWidget: (_, __, ___) => _fallback(),
          )
              : _fallback(),
        ),
      ),
    );
  }

  Widget _fallback() => Container(
    color: const Color(0xFF1A1A1A),
    child: const Icon(LucideIcons.user,
        size: 14, color: Color(0xFF444444)),
  );
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF2A2A2A), width: 0.8),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          '+ Witness',
          style: AppTypography.bodySmall.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// Heading

class _CardHeading extends StatelessWidget {
  final String heading;

  const _CardHeading({required this.heading});

  @override
  Widget build(BuildContext context) {
    return Text(
      heading,
      style: AppTypography.bodyMedium.copyWith(
        fontFamily: 'DM Sans',
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.4,
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// Audioplayer

class _AudioPlayer extends StatefulWidget {
  final String audioUrl;
  final int durationSeconds;

  const _AudioPlayer({
    required this.audioUrl,
    required this.durationSeconds,
  });

  @override
  State<_AudioPlayer> createState() => _AudioPlayerState();
}

class _AudioPlayerState extends State<_AudioPlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _duration = Duration(seconds: widget.durationSeconds);

    _player.playerStateStream.listen((s) {
      if (!mounted) return;
      setState(() {
        _isPlaying = s.playing &&
            s.processingState != ProcessingState.completed;
        _isLoading =
            s.processingState == ProcessingState.loading ||
                s.processingState == ProcessingState.buffering;
        if (s.processingState == ProcessingState.completed) {
          _position = Duration.zero;
          _player.seek(Duration.zero);
        }
      });
    });

    _player.positionStream.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
    });

    _player.durationStream.listen((d) {
      if (d != null && mounted) setState(() => _duration = d);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    HapticFeedback.selectionClick();
    if (_isPlaying) {
      await _player.pause();
    } else {
      if (_player.processingState == ProcessingState.idle) {
        await _player.setUrl(widget.audioUrl);
      }
      await _player.play();
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E1E2E), width: 0.8),
      ),
      child: Row(
        children: [
          // play/pause
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFF1DE9B6)],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: _isLoading
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : Icon(
                  _isPlaying ? LucideIcons.pause : LucideIcons.play,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // waveform bar + scrubber
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // waveform — static decorative bars
                _WaveformBars(progress: progress),
                const SizedBox(height: 6),
                // time
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _fmt(_position),
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      _fmt(_duration),
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveformBars extends StatelessWidget {
  final double progress;

  const _WaveformBars({required this.progress});

  // fixed heights to simulate a waveform (looks natural)
  static const List<double> _heights = [
    6, 10, 14, 8, 18, 12, 20, 16, 9, 22,
    15, 11, 19, 7, 17, 13, 21, 10, 16, 8,
    14, 18, 12, 20, 9, 15, 11, 17, 13, 6,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Row(
        children: List.generate(_heights.length, (i) {
          final fraction = i / (_heights.length - 1);
          final active = fraction <= progress;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  width: double.infinity,
                  height: _heights[i],
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.accentPrimary
                        : const Color(0xFF2A2A3A),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// Actions


class _CardActions extends StatelessWidget {
  final TeaPost post;
  final VoidCallback onLike;

  const _CardActions({required this.post, required this.onLike});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionButton(
          icon: LucideIcons.messageSquare,
          count: post.commentCount,
          onTap: () {},
          active: false,
          activeColor: AppColors.accentPrimary,
        ),
        const SizedBox(width: 20),
        _LikeButton(post: post, onLike: onLike),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final int count;
  final VoidCallback onTap;
  final bool active;
  final Color activeColor;

  const _ActionButton({
    required this.icon,
    required this.count,
    required this.onTap,
    required this.active,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: active ? activeColor : AppColors.textSecondary,
          ),
          const SizedBox(width: 5),
          Text(
            '$count',
            style: AppTypography.bodySmall.copyWith(
              fontSize: 13,
              color: active ? activeColor : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LikeButton extends StatefulWidget {
  final TeaPost post;
  final VoidCallback onLike;

  const _LikeButton({required this.post, required this.onLike});

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 180));
    _scale = Tween<double>(begin: 1.0, end: 1.35).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _tap() {
    HapticFeedback.selectionClick();
    _ctrl.forward().then((_) => _ctrl.reverse());
    widget.onLike();
  }

  @override
  Widget build(BuildContext context) {
    final liked = widget.post.isLikedByMe;
    return GestureDetector(
      onTap: _tap,
      child: Row(
        children: [
          ScaleTransition(
            scale: _scale,
            child: Icon(
              liked ? LucideIcons.heart : LucideIcons.heart,
              size: 18,
              color: liked
                  ? AppColors.errorLight
                  : AppColors.textSecondary,
              fill: liked ? 1 : 0,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '${widget.post.likeCount}',
            style: AppTypography.bodySmall.copyWith(
              fontSize: 13,
              color: liked
                  ? AppColors.errorLight
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// Shimmer Card

class TeaShimmerCard extends StatelessWidget {
  const TeaShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
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
                  _Shimmer(width: 90, height: 11),
                  const SizedBox(height: 4),
                  _Shimmer(width: 50, height: 9),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          _Shimmer(width: double.infinity, height: 13),
          const SizedBox(height: 4),
          _Shimmer(width: 160, height: 13),
          const SizedBox(height: 12),
          _Shimmer(width: double.infinity, height: 58, radius: 12),
          const SizedBox(height: 12),
          Row(
            children: [
              _Shimmer(width: 44, height: 13),
              const SizedBox(width: 20),
              _Shimmer(width: 44, height: 13),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 0.5, color: const Color(0xFF1A1A1A)),
        ],
      ),
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
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
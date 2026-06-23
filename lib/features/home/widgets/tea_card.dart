import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/models/avatar_config.dart';
import '../../../core/models/tea_post_model.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/widgets/fess_snackbar.dart';
import '../providers/feed_provider.dart';
import '../providers/profile_provider.dart';

class TeaCard extends ConsumerStatefulWidget {
  final TeaPost post;
  final String? currentAnonId; // the LOGGED-IN user's anonId
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onDelete;

  const TeaCard({
    super.key,
    required this.post,
    required this.currentAnonId,
    required this.onTap,
    required this.onLike,
    this.onAuthorTap,
    this.onDelete,
  });

  @override
  ConsumerState<TeaCard> createState() => _TeaCardState();
}

class _TeaCardState extends ConsumerState<TeaCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  bool _deleted = false;
  late final AnimationController _deleteCtrl;
  late final Animation<double> _deleteFade;

  bool get _isOwn =>
      widget.currentAnonId != null &&
          widget.post.authorId == widget.currentAnonId;

  @override
  void initState() {
    super.initState();
    _deleteCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _deleteFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _deleteCtrl, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _deleteCtrl.dispose();
    super.dispose();
  }

  Future<void> _animateDelete() async {
    setState(() => _deleted = true);
    await _deleteCtrl.forward();
    widget.onDelete?.call();
    ref.invalidate(myTeaProvider(widget.post.authorId));
    ref.read(forYouFeedProvider.notifier).removePost(widget.post.postId);
  }

  void _showDeleteSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _TeaDeleteSheet(
        post: widget.post,
        ref: ref,
        onDeleted: _animateDelete,
      ),
    );
  }

  void _showMoreSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _TeaMoreSheet(post: widget.post),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOut,
      child: _deleted
          ? AnimatedBuilder(
        animation: _deleteFade,
        builder: (_, __) => Opacity(
          opacity: (1 - _deleteFade.value).clamp(0.0, 1.0),
          child: Container(
            color: AppColors.errorLight
                .withOpacity(0.06 * _deleteFade.value),
            height: _deleted && _deleteCtrl.isCompleted ? 0 : null,
            child: _cardBody(context),
          ),
        ),
      )
          : GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          color:
          _pressed ? const Color(0xFF111111) : Colors.transparent,
          child: _cardBody(context),
        ),
      )
          .animate()
          .fadeIn(duration: 280.ms)
          .slideY(begin: 0.04, end: 0, duration: 280.ms, curve: Curves.easeOut),
    );
  }

  Widget _cardBody(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TeaCardHeader(
            post: widget.post,
            onAuthorTap: widget.onAuthorTap,
            isOwn: _isOwn,
            onDeleteTap: _showDeleteSheet,
            onMoreTap: _showMoreSheet,
          ),
          const SizedBox(height: 10),
          Text(
            widget.post.heading,
            style: AppTypography.h4.copyWith(
              fontFamily: 'DM Sans',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          _TeaVoicePlayer(
            key: ValueKey('tea_voice_${widget.post.postId}'),
            audioUrl: widget.post.audioUrl,
            durationSecs: widget.post.audioDurationSeconds,
          ),
          const SizedBox(height: 12),
          _ReactionRow(
            post: widget.post,
            onLike: widget.onLike,
            onComment: widget.onTap,
          ),
          const SizedBox(height: 14),
          const Divider(height: 0.5, thickness: 0.5, color: Color(0xFF1A1A1A)),
        ],
      ),
    );
  }
}

// ── Tea Card Header ───────────────────────────────────────────────────────────

class _TeaCardHeader extends StatelessWidget {
  final TeaPost post;
  final VoidCallback? onAuthorTap;
  final bool isOwn;
  final VoidCallback onDeleteTap;
  final VoidCallback onMoreTap;

  const _TeaCardHeader({
    required this.post,
    required this.isOwn,
    required this.onDeleteTap,
    required this.onMoreTap,
    this.onAuthorTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = post.authorAvatarConfig.isNotEmpty
        ? AvatarConfig.fromMap(post.authorAvatarConfig).buildUrl(size: 72)
        : null;

    final timeStr = timeago.format(post.createdAt, locale: 'en_short');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onAuthorTap,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                _Avatar(url: avatarUrl),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '@${post.authorUsername}',
                        style: AppTypography.bodyMedium.copyWith(
                          fontFamily: 'DM Sans',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 11,
                          color: AppColors.hintText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isOwn)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onDeleteTap();
            },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
              child: Icon(
                LucideIcons.trash2,
                size: 15,
                color: AppColors.errorLight.withOpacity(0.55),
              ),
            ),
          ),
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onMoreTap();
          },
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 0, 4),
            child: Icon(
              LucideIcons.moreHorizontal,
              size: 16,
              color: AppColors.hintText,
            ),
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  const _Avatar({this.url});

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: AppColors.accentPrimary.withOpacity(0.35),
        width: 1.2,
      ),
    ),
    child: ClipOval(
      child: url != null
          ? CachedNetworkImage(
        imageUrl: url!,
        fit: BoxFit.cover,
        placeholder: (_, __) =>
            Container(color: const Color(0xFF1A1A1A)),
        errorWidget: (_, __, ___) => const _AnonAvatar(),
      )
          : const _AnonAvatar(),
    ),
  );
}

class _AnonAvatar extends StatelessWidget {
  const _AnonAvatar();
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFF1A1A1A),
    child:
    const Icon(LucideIcons.user, size: 18, color: AppColors.hintText),
  );
}

// ── Tea Voice Player (unchanged internals) ────────────────────────────────────

class _TeaVoicePlayer extends StatefulWidget {
  final String audioUrl;
  final int durationSecs;

  const _TeaVoicePlayer({
    super.key,
    required this.audioUrl,
    required this.durationSecs,
  });

  @override
  State<_TeaVoicePlayer> createState() => _TeaVoicePlayerState();
}

class _TeaVoicePlayerState extends State<_TeaVoicePlayer> {
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  StreamSubscription? _stateSub;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _duration = Duration(seconds: widget.durationSecs);

    _stateSub = AudioService.instance.playerStateStream.listen((s) {
      if (!mounted) return;
      final currentUrl = AudioService.instance.currentUrl;
      final playing = s.playing &&
          s.processingState != ProcessingState.completed &&
          currentUrl == widget.audioUrl;
      if (s.processingState == ProcessingState.completed &&
          currentUrl == widget.audioUrl) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
        return;
      }
      setState(() => _isPlaying = playing);
      if (!playing && currentUrl != widget.audioUrl) {
        setState(() => _position = Duration.zero);
      }
    });

    _posSub = AudioService.instance.positionStream.listen((p) {
      if (!mounted) return;
      if (AudioService.instance.currentUrl == widget.audioUrl) {
        setState(() => _position = p);
      }
    });

    _durSub = AudioService.instance.durationStream.listen((d) {
      if (!mounted) return;
      if (d != null && AudioService.instance.currentUrl == widget.audioUrl) {
        setState(() => _duration = d);
      }
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    super.dispose();
  }

  Future<void> _toggle() async {
    HapticFeedback.selectionClick();
    if (_isPlaying) {
      await AudioService.instance.pause();
    } else {
      await AudioService.instance.playUrl(widget.audioUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _duration.inMilliseconds > 0
        ? _duration.inMilliseconds
        : (widget.durationSecs * 1000);
    final pct =
    total > 0 ? (_position.inMilliseconds / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.accentPrimary.withOpacity(0.15),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _isPlaying
                    ? AppColors.accentPrimary
                    : AppColors.accentPrimary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    _isPlaying ? LucideIcons.pause : LucideIcons.play,
                    key: ValueKey(_isPlaying),
                    size: 13,
                    color:
                    _isPlaying ? Colors.black : AppColors.accentPrimary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape:
                const RoundSliderThumbShape(enabledThumbRadius: 4),
                overlayShape:
                const RoundSliderOverlayShape(overlayRadius: 10),
                activeTrackColor: AppColors.accentPrimary,
                inactiveTrackColor: const Color(0xFF2A2A38),
                thumbColor: AppColors.accentPrimary,
                overlayColor: AppColors.accentPrimary.withOpacity(0.12),
              ),
              child: Slider(
                value: pct.toDouble(),
                min: 0,
                max: 1,
                onChanged: (v) {
                  if (total == 0 ||
                      AudioService.instance.currentUrl != widget.audioUrl) {
                    return;
                  }
                  AudioService.instance
                      .seekTo(Duration(milliseconds: (v * total).round()));
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _isPlaying && _position.inSeconds > 0
                ? _fmt(_position.inSeconds)
                : _fmt(widget.durationSecs),
            style: AppTypography.bodySmall.copyWith(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reaction Row ──────────────────────────────────────────────────────────────

class _ReactionRow extends StatelessWidget {
  final TeaPost post;
  final VoidCallback onLike;
  final VoidCallback onComment;

  const _ReactionRow({
    required this.post,
    required this.onLike,
    required this.onComment,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _ReactionBtn(
        icon: LucideIcons.messageCircle,
        count: post.commentCount,
        onTap: onComment,
        active: false,
        activeColor: AppColors.accentPrimary,
      ),
      const SizedBox(width: 20),
      _LikeBtn(post: post, onLike: onLike),
      const Spacer(),
      _ReactionBtn(
        icon: LucideIcons.share2,
        count: null,
        onTap: () {},
        active: false,
        activeColor: AppColors.textSecondary,
      ),
    ],
  );
}

class _ReactionBtn extends StatelessWidget {
  final IconData icon;
  final int? count;
  final VoidCallback onTap;
  final bool active;
  final Color activeColor;

  const _ReactionBtn({
    required this.icon,
    required this.count,
    required this.onTap,
    required this.active,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      HapticFeedback.selectionClick();
      onTap();
    },
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 17,
              color: active ? activeColor : AppColors.textSecondary),
          if (count != null) ...[
            const SizedBox(width: 5),
            Text(
              '$count',
              style: AppTypography.bodySmall.copyWith(
                fontSize: 13,
                color: active ? activeColor : AppColors.textSecondary,
                fontFeatures: [const FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _LikeBtn extends StatefulWidget {
  final TeaPost post;
  final VoidCallback onLike;
  const _LikeBtn({required this.post, required this.onLike});

  @override
  State<_LikeBtn> createState() => _LikeBtnState();
}

class _LikeBtnState extends State<_LikeBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      HapticFeedback.mediumImpact();
      _ctrl.forward(from: 0);
      widget.onLike();
    },
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _scale,
            child: Icon(
              widget.post.isLikedByMe
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              size: 17,
              color: widget.post.isLikedByMe
                  ? AppColors.errorLight
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '${widget.post.likeCount}',
            style: AppTypography.bodySmall.copyWith(
              fontSize: 13,
              color: widget.post.isLikedByMe
                  ? AppColors.errorLight
                  : AppColors.textSecondary,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Tea Delete Sheet ──────────────────────────────────────────────────────────

class _TeaDeleteSheet extends ConsumerWidget {
  final TeaPost post;
  final WidgetRef ref;
  final VoidCallback onDeleted;

  const _TeaDeleteSheet({
    required this.post,
    required this.ref,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final isDeleting = ref.watch(deletePostProvider);
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0E0E0E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(0, 12, 0, bottomPad + 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delete this tea?',
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'This removes it from your profile and the tea feed. Cannot be undone.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1A1A1A)),
            ),
            child: Text(
              post.heading,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GestureDetector(
              onTap: isDeleting
                  ? null
                  : () async {
                HapticFeedback.mediumImpact();
                final ok = await ref
                    .read(deletePostProvider.notifier)
                    .delete(
                  postId: post.postId,
                  authorId: post.authorId,
                  type: 'tea',
                );
                if (ok && context.mounted) {
                  Navigator.of(context).pop();
                  onDeleted();
                }
              },
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.errorLight.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.errorLight.withOpacity(0.3),
                  ),
                ),
                child: Center(
                  child: isDeleting
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppColors.errorLight,
                    ),
                  )
                      : const Text(
                    'Delete tea',
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.errorLight,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Keep it',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tea More Sheet ────────────────────────────────────────────────────────────

class _TeaMoreSheet extends StatelessWidget {
  final TeaPost post;
  const _TeaMoreSheet({required this.post});

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0E0E0E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(0, 12, 0, bottomPad + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              post.heading,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(
                fontSize: 12,
                color: AppColors.hintText,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(height: 0.5, color: const Color(0xFF1A1A1A)),
          const SizedBox(height: 8),
          _TeaSheetItem(
            icon: LucideIcons.flag,
            label: 'Report tea',
            subtitle: 'Something about this isn\'t right',
            onTap: () {
              Navigator.of(context).pop();
              FessSnackbar.show(
                context,
                'Report received — we\'ll look into it.',
                type: SnackbarType.info,
              );
            },
          ),
          _TeaSheetItem(
            icon: LucideIcons.userX,
            label: 'Block user',
            subtitle: 'You won\'t see their posts anymore',
            onTap: () {
              Navigator.of(context).pop();
              FessSnackbar.show(
                context,
                'Blocking — coming soon.',
                type: SnackbarType.info,
              );
            },
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Cancel',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeaSheetItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _TeaSheetItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  @override
  State<_TeaSheetItem> createState() => _TeaSheetItemState();
}

class _TeaSheetItemState extends State<_TeaSheetItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        color: _pressed ? const Color(0xFF161616) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(widget.icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: AppTypography.bodyMedium.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (widget.subtitle != null)
                    Text(
                      widget.subtitle!,
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 11,
                        color: AppColors.hintText,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shimmer ───────────────────────────────────────────────────────────────────

class TeaShimmerCard extends StatefulWidget {
  const TeaShimmerCard({super.key});

  @override
  State<TeaShimmerCard> createState() => _TeaShimmerCardState();
}

class _TeaShimmerCardState extends State<TeaShimmerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _Bone(w: 36, h: 36, radius: 18, anim: _anim),
            const SizedBox(width: 9),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Bone(w: 100, h: 12, radius: 4, anim: _anim),
                const SizedBox(height: 4),
                _Bone(w: 50, h: 10, radius: 4, anim: _anim),
              ],
            ),
          ]),
          const SizedBox(height: 12),
          _Bone(w: double.infinity, h: 14, radius: 4, anim: _anim),
          const SizedBox(height: 6),
          _Bone(w: 220, h: 12, radius: 4, anim: _anim),
          const SizedBox(height: 12),
          _Bone(w: double.infinity, h: 52, radius: 10, anim: _anim),
          const SizedBox(height: 12),
          Row(children: [
            _Bone(w: 40, h: 12, radius: 4, anim: _anim),
            const SizedBox(width: 20),
            _Bone(w: 40, h: 12, radius: 4, anim: _anim),
          ]),
          const SizedBox(height: 14),
          const Divider(
              height: 0.5, thickness: 0.5, color: Color(0xFF1A1A1A)),
        ],
      ),
    ),
  );
}

class _Bone extends StatelessWidget {
  final double w;
  final double h;
  final double radius;
  final Animation<double> anim;
  const _Bone(
      {required this.w,
        required this.h,
        required this.radius,
        required this.anim});

  @override
  Widget build(BuildContext context) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: const [
          Color(0xFF1A1A28),
          Color(0xFF252535),
          Color(0xFF1A1A28),
        ],
        stops: [
          (anim.value - 0.5).clamp(0.0, 1.0),
          anim.value.clamp(0.0, 1.0),
          (anim.value + 0.5).clamp(0.0, 1.0),
        ],
      ),
    ),
  );
}
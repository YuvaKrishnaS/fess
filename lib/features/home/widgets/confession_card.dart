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
import '../../../core/models/post_model.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/widgets/fess_snackbar.dart';
import '../providers/feed_provider.dart';
import '../providers/profile_provider.dart';

class ConfessionCard extends ConsumerStatefulWidget {
  final PostModel post;
  // IMPORTANT: must be the logged-in user's anonId, NOT the profile owner's
  final String? currentAnonId;
  final VoidCallback onLike;
  final VoidCallback onTap;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onDelete;

  const ConfessionCard({
    super.key,
    required this.post,
    required this.currentAnonId,
    required this.onLike,
    required this.onTap,
    this.onComment,
    this.onShare,
    this.onAuthorTap,
    this.onDelete,
  });

  @override
  ConsumerState<ConfessionCard> createState() => _ConfessionCardState();
}

class _ConfessionCardState extends ConsumerState<ConfessionCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  bool _deleting = false;
  late final AnimationController _deleteCtrl;
  late final Animation<double> _deleteOpacity;
  late final Animation<Color?> _deleteColor;

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
    _deleteOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _deleteCtrl, curve: const Interval(0.4, 1.0)),
    );
    _deleteColor = ColorTween(
      begin: Colors.transparent,
      end: const Color(0x22FF3B30),
    ).animate(CurvedAnimation(parent: _deleteCtrl, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _deleteCtrl.dispose();
    super.dispose();
  }

  void _onDeleteConfirmed() async {
    setState(() => _deleting = true);
    await _deleteCtrl.forward();
    widget.onDelete?.call();
  }

  void _showMoreSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MoreSheet(
        post: widget.post,
        isOwn: _isOwn,
        ref: ref,
        onDeleteConfirmed: _onDeleteConfirmed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _deleteCtrl,
      builder: (context, child) {
        return Opacity(
          opacity: _deleting ? _deleteOpacity.value : 1.0,
          child: Container(
            color: _deleting ? _deleteColor.value : Colors.transparent,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: _deleting
            ? null
            : () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          color: _pressed ? const Color(0xFF111111) : Colors.transparent,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardHeader(
                post: widget.post,
                onAuthorTap: widget.onAuthorTap,
                onMoreTap: () => _showMoreSheet(context),
              ),
              const SizedBox(height: 10),
              if (widget.post.type == 'spill_in_tea')
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A0A2E),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.accentSecondary.withOpacity(0.3),
                        width: 0.6,
                      ),
                    ),
                    child: Text(
                      'spilled completely',
                      style: TextStyle(
                        fontFamily: 'DM Serif Display',
                        fontStyle: FontStyle.italic,
                        fontSize: 11,
                        color: AppColors.accentSecondary.withOpacity(0.8),
                      ),
                    ),
                  ),
                ),
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
              if (widget.post.body != null &&
                  widget.post.body!.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  widget.post.body!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.55,
                  ),
                ),
              ],
              if (widget.post.imageUrls.isNotEmpty) ...[
                const SizedBox(height: 10),
                _CardImage(url: widget.post.imageUrls.first),
              ],
              if (widget.post.audioUrl != null &&
                  widget.post.audioUrl!.isNotEmpty) ...[
                const SizedBox(height: 10),
                _InlineVoicePlayer(
                  key: ValueKey('voice_${widget.post.postId}'),
                  audioUrl: widget.post.audioUrl!,
                  durationSecs: widget.post.audioDuration ?? 0,
                ),
              ],
              const SizedBox(height: 12),
              _ReactionRow(
                post: widget.post,
                onLike: widget.onLike,
                onComment: widget.onComment ?? widget.onTap,
                onShare: widget.onShare ?? () {},
              ),
              const SizedBox(height: 14),
              const Divider(
                  height: 0.5, thickness: 0.5, color: Color(0xFF1A1A1A)),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.04, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }
}

// ── Card Header ───────────────────────────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  final PostModel post;
  final VoidCallback? onAuthorTap;
  final VoidCallback onMoreTap;

  const _CardHeader({
    required this.post,
    required this.onMoreTap,
    this.onAuthorTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = post.authorAvatarConfig != null
        ? AvatarConfig.fromMap(post.authorAvatarConfig!).buildUrl(size: 72)
        : null;

    final timeStr = post.createdAt != null
        ? timeago.format(post.createdAt!, locale: 'en_short')
        : 'just now';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Author row — tappable to go to profile
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
                        '@${post.authorUsername ?? 'anon'}',
                        style: AppTypography.bodyMedium.copyWith(
                          fontFamily: 'DM Sans',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      GestureDetector(
                        onLongPress: () {
                          if (post.createdAt == null) return;
                          final full =
                              '${post.createdAt!.day}/${post.createdAt!.month}/${post.createdAt!.year} '
                              '${post.createdAt!.hour.toString().padLeft(2, '0')}:${post.createdAt!.minute.toString().padLeft(2, '0')}';
                          FessSnackbar.show(context, full,
                              type: SnackbarType.info);
                        },
                        child: Text(
                          timeStr,
                          style: AppTypography.bodySmall.copyWith(
                            fontSize: 11,
                            color: AppColors.hintText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Three dots
        GestureDetector(
          onTap: onMoreTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 0, 4),
            child: Icon(
              LucideIcons.moreVertical,
              size: 17,
              color: AppColors.hintText,
            ),
          ),
        ),
      ],
    );
  }
}

// ── More / Options Bottom Sheet ───────────────────────────────────────────────

class _MoreSheet extends ConsumerStatefulWidget {
  final PostModel post;
  final bool isOwn;
  final WidgetRef ref;
  final VoidCallback onDeleteConfirmed;

  const _MoreSheet({
    required this.post,
    required this.isOwn,
    required this.ref,
    required this.onDeleteConfirmed,
  });

  @override
  ConsumerState<_MoreSheet> createState() => _MoreSheetState();
}

class _MoreSheetState extends ConsumerState<_MoreSheet> {
  bool _showDeleteConfirm = false;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final isDeleting = widget.ref.watch(deletePostProvider);

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0E0E12),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: EdgeInsets.fromLTRB(0, 10, 0, bottomPad + 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            if (!_showDeleteConfirm) ...[
              // ── Normal options ──
              if (widget.isOwn) ...[
                _SheetOption(
                  icon: LucideIcons.trash2,
                  label: 'Delete post',
                  color: AppColors.errorLight,
                  onTap: () => setState(() => _showDeleteConfirm = true),
                ),
                _Divider(),
              ],
              _SheetOption(
                icon: LucideIcons.flag,
                label: 'Report',
                color: AppColors.textSecondary,
                onTap: () {
                  Navigator.of(context).pop();
                  FessSnackbar.show(context, 'Report — coming soon',
                      type: SnackbarType.info);
                },
              ),
              _SheetOption(
                icon: LucideIcons.userX,
                label: 'Block user',
                color: AppColors.textSecondary,
                onTap: () {
                  Navigator.of(context).pop();
                  FessSnackbar.show(context, 'Block — coming soon',
                      type: SnackbarType.info);
                },
              ),
              const SizedBox(height: 4),
            ] else ...[
              // ── Delete confirmation ──
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delete this post?',
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gone forever. No undoing this.',
                      style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    // Post preview
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111114),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF1E1E1E)),
                      ),
                      child: Text(
                        widget.post.heading,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _showDeleteConfirm = false),
                            child: Container(
                              height: 46,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A1A),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  'Keep it',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: isDeleting
                                ? null
                                : () async {
                              HapticFeedback.mediumImpact();
                              final ok = await widget.ref
                                  .read(deletePostProvider.notifier)
                                  .delete(
                                postId: widget.post.postId,
                                authorId: widget.post.authorId,
                                type: widget.post.type,
                              );
                              if (ok && context.mounted) {
                                Navigator.of(context).pop();
                                widget.onDeleteConfirmed();
                              }
                            },
                            child: Container(
                              height: 46,
                              decoration: BoxDecoration(
                                color:
                                AppColors.errorLight.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                  AppColors.errorLight.withOpacity(0.3),
                                  width: 0.8,
                                ),
                              ),
                              child: Center(
                                child: isDeleting
                                    ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: AppColors.errorLight,
                                  ),
                                )
                                    : const Text(
                                  'Delete',
                                  style: TextStyle(
                                    fontFamily: 'DM Sans',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.errorLight,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SheetOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      HapticFeedback.selectionClick();
      onTap();
    },
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 14),
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(height: 0.5, color: const Color(0xFF1A1A1A));
}

// ── Avatar ────────────────────────────────────────────────────────────────────

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

// ── Card Image ────────────────────────────────────────────────────────────────

class _CardImage extends StatelessWidget {
  final String url;
  const _CardImage({required this.url});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: AspectRatio(
      aspectRatio: 16 / 9,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: const Color(0xFF1A1A1A)),
        errorWidget: (_, __, ___) => Container(
          color: const Color(0xFF1A1A1A),
          child: const Center(
            child: Icon(LucideIcons.imageOff,
                size: 24, color: AppColors.hintText),
          ),
        ),
      ),
    ),
  );
}

// ── Inline Voice Player ───────────────────────────────────────────────────────

class _InlineVoicePlayer extends StatefulWidget {
  final String audioUrl;
  final int durationSecs;

  const _InlineVoicePlayer({
    super.key,
    required this.audioUrl,
    required this.durationSecs,
  });

  @override
  State<_InlineVoicePlayer> createState() => _InlineVoicePlayerState();
}

class _InlineVoicePlayerState extends State<_InlineVoicePlayer> {
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
        setState(() { _isPlaying = false; _position = Duration.zero; });
        return;
      }
      setState(() => _isPlaying = playing);
      if (!playing && currentUrl != widget.audioUrl) {
        setState(() => _position = Duration.zero);
      }
    });
    _posSub = AudioService.instance.positionStream.listen((p) {
      if (!mounted) return;
      if (AudioService.instance.currentUrl == widget.audioUrl) setState(() => _position = p);
    });
    _durSub = AudioService.instance.durationStream.listen((d) {
      if (!mounted) return;
      if (d != null && AudioService.instance.currentUrl == widget.audioUrl) setState(() => _duration = d);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel(); _posSub?.cancel(); _durSub?.cancel();
    super.dispose();
  }

  Future<void> _toggle() async {
    HapticFeedback.selectionClick();
    if (_isPlaying) { await AudioService.instance.pause(); }
    else { await AudioService.instance.playUrl(widget.audioUrl); }
  }

  @override
  Widget build(BuildContext context) {
    final total = _duration.inMilliseconds > 0 ? _duration.inMilliseconds : (widget.durationSecs * 1000);
    final pct = total > 0 ? (_position.inMilliseconds / total).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accentPrimary.withOpacity(0.15), width: 0.8),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: _toggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: _isPlaying ? AppColors.accentPrimary : AppColors.accentPrimary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Center(child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: Icon(_isPlaying ? LucideIcons.pause : LucideIcons.play,
                  key: ValueKey(_isPlaying), size: 13,
                  color: _isPlaying ? Colors.black : AppColors.accentPrimary),
            )),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
            activeTrackColor: AppColors.accentPrimary,
            inactiveTrackColor: const Color(0xFF2A2A38),
            thumbColor: AppColors.accentPrimary,
            overlayColor: AppColors.accentPrimary.withOpacity(0.12),
          ),
          child: Slider(
            value: pct.toDouble(), min: 0, max: 1,
            onChanged: (v) {
              if (total == 0 || AudioService.instance.currentUrl != widget.audioUrl) return;
              AudioService.instance.seekTo(Duration(milliseconds: (v * total).round()));
            },
          ),
        )),
        const SizedBox(width: 8),
        Text(
          _isPlaying && _position.inSeconds > 0 ? _fmt(_position.inSeconds) : _fmt(widget.durationSecs),
          style: AppTypography.bodySmall.copyWith(fontSize: 11, color: AppColors.textSecondary,
              fontFeatures: [const FontFeature.tabularFigures()]),
        ),
      ]),
    );
  }
}

// ── Reaction Row ──────────────────────────────────────────────────────────────

class _ReactionRow extends StatelessWidget {
  final PostModel post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;

  const _ReactionRow({
    required this.post, required this.onLike,
    required this.onComment, required this.onShare,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
    _ReactionBtn(icon: LucideIcons.messageCircle, count: post.commentCount,
        onTap: onComment, active: false, activeColor: AppColors.accentPrimary),
    const SizedBox(width: 20),
    _LikeBtn(post: post, onLike: onLike),
    const Spacer(),
    _ReactionBtn(icon: LucideIcons.share2, count: null,
        onTap: onShare, active: false, activeColor: AppColors.textSecondary),
  ]);
}

class _ReactionBtn extends StatelessWidget {
  final IconData icon; final int? count; final VoidCallback onTap;
  final bool active; final Color activeColor;
  const _ReactionBtn({required this.icon, required this.count, required this.onTap,
    required this.active, required this.activeColor});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () { HapticFeedback.selectionClick(); onTap(); },
    behavior: HitTestBehavior.opaque,
    child: Padding(padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 17, color: active ? activeColor : AppColors.textSecondary),
        if (count != null) ...[const SizedBox(width: 5),
          Text('$count', style: AppTypography.bodySmall.copyWith(fontSize: 13,
              color: active ? activeColor : AppColors.textSecondary,
              fontFeatures: [const FontFeature.tabularFigures()]))],
      ]),
    ),
  );
}

class _LikeBtn extends StatefulWidget {
  final PostModel post; final VoidCallback onLike;
  const _LikeBtn({required this.post, required this.onLike});
  @override State<_LikeBtn> createState() => _LikeBtnState();
}

class _LikeBtnState extends State<_LikeBtn> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () { HapticFeedback.mediumImpact(); _ctrl.forward(from: 0); widget.onLike(); },
    behavior: HitTestBehavior.opaque,
    child: Padding(padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        ScaleTransition(scale: _scale,
            child: Icon(widget.post.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: 17, color: widget.post.isLiked ? AppColors.errorLight : AppColors.textSecondary)),
        const SizedBox(width: 5),
        Text('${widget.post.likeCount}', style: AppTypography.bodySmall.copyWith(
            fontSize: 13, color: widget.post.isLiked ? AppColors.errorLight : AppColors.textSecondary,
            fontFeatures: [const FontFeature.tabularFigures()])),
      ]),
    ),
  );
}

// ── Shimmer ───────────────────────────────────────────────────────────────────

class ConfessionShimmerCard extends StatefulWidget {
  const ConfessionShimmerCard({super.key});
  @override State<ConfessionShimmerCard> createState() => _ConfessionShimmerCardState();
}

class _ConfessionShimmerCardState extends State<ConfessionShimmerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _Bone(w: 36, h: 36, radius: 18, anim: _anim),
          const SizedBox(width: 9),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Bone(w: 100, h: 12, radius: 4, anim: _anim),
            const SizedBox(height: 4),
            _Bone(w: 50, h: 10, radius: 4, anim: _anim),
          ]),
        ]),
        const SizedBox(height: 12),
        _Bone(w: double.infinity, h: 14, radius: 4, anim: _anim),
        const SizedBox(height: 6),
        _Bone(w: double.infinity, h: 12, radius: 4, anim: _anim),
        const SizedBox(height: 4),
        _Bone(w: 200, h: 12, radius: 4, anim: _anim),
        const SizedBox(height: 14),
        Row(children: [
          _Bone(w: 40, h: 12, radius: 4, anim: _anim),
          const SizedBox(width: 20),
          _Bone(w: 40, h: 12, radius: 4, anim: _anim),
        ]),
        const SizedBox(height: 14),
        const Divider(height: 0.5, thickness: 0.5, color: Color(0xFF1A1A1A)),
      ]),
    ),
  );
}

class _Bone extends StatelessWidget {
  final double w, h, radius; final Animation<double> anim;
  const _Bone({required this.w, required this.h, required this.radius, required this.anim});
  @override
  Widget build(BuildContext context) => Container(
    width: w, height: h,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.centerLeft, end: Alignment.centerRight,
        colors: const [Color(0xFF1A1A28), Color(0xFF252535), Color(0xFF1A1A28)],
        stops: [(anim.value - 0.5).clamp(0.0, 1.0), anim.value.clamp(0.0, 1.0), (anim.value + 0.5).clamp(0.0, 1.0)],
      ),
    ),
  );
}
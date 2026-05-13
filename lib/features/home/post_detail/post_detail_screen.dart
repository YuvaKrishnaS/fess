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
import '../../../core/models/comment_model.dart';
import '../../../core/models/post_model.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/widgets/fess_snackbar.dart';
import '../providers/post_detail_provider.dart';

Route<void> postDetailHeroRoute(String postId, {PostModel? initialPost}) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) =>
        PostDetailScreen(postId: postId, initialPost: initialPost),
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      );
      final scale = Tween<double>(begin: 0.97, end: 1.0).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
      );
      return FadeTransition(
        opacity: fade,
        child: ScaleTransition(
          scale: scale,
          alignment: Alignment.topCenter,
          child: child,
        ),
      );
    },
  );
}

class PostDetailScreen extends ConsumerStatefulWidget {
  final String postId;
  final PostModel? initialPost;

  const PostDetailScreen({super.key, required this.postId, this.initialPost});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final TextEditingController _commentCtrl = TextEditingController();
  final FocusNode _commentFocus = FocusNode();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    _commentFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _submit() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.mediumImpact();
    _commentCtrl.clear();
    _commentFocus.unfocus();
    final ok = await ref
        .read(postDetailProvider(widget.postId).notifier)
        .addComment(text);
    if (!ok && mounted) {
      FessSnackbar.show(context, 'Failed to post comment.',
          type: SnackbarType.error);
    } else {
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(postDetailProvider(widget.postId));
    final post = state.post ?? widget.initialPost;

    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          _DetailAppBar(post: post),
          Expanded(
            child: post == null
                ? const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: AppColors.textSecondary),
              ),
            )
                : CustomScrollView(
              controller: _scroll,
              slivers: [
                SliverToBoxAdapter(
                  child: Hero(
                    tag: 'hero_post_${post.postId}',
                    flightShuttleBuilder: _detailFlightShuttle,
                    child: Material(
                      type: MaterialType.transparency,
                      child: _PostBody(
                        post: post,
                        onLike: () => ref
                            .read(postDetailProvider(widget.postId)
                            .notifier)
                            .togglePostLike(),
                        onWitness: () => FessSnackbar.show(
                            context, 'Witness system — Coming soon',
                            type: SnackbarType.info),
                      ),
                    ),
                  ).animate().fadeIn(duration: 250.ms),
                ),
                SliverToBoxAdapter(
                    child: _CommentsHeader(count: post.commentCount)),
                if (state.isLoadingComments)
                  SliverToBoxAdapter(child: _CommentsShimmer())
                else if (state.comments.isEmpty)
                  SliverToBoxAdapter(child: _EmptyComments())
                else
                  SliverList.separated(
                    itemCount: state.comments.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 0.5,
                      thickness: 0.5,
                      color: Color(0xFF141414),
                      indent: 16,
                      endIndent: 16,
                    ),
                    itemBuilder: (ctx, i) => _CommentTile(
                      comment: state.comments[i],
                      onLike: () => ref
                          .read(postDetailProvider(widget.postId)
                          .notifier)
                          .toggleCommentLike(
                          state.comments[i].commentId),
                    )
                        .animate(
                        delay: Duration(
                            milliseconds: i < 8 ? i * 30 : 0))
                        .fadeIn(duration: 200.ms)
                        .slideY(
                        begin: 0.03,
                        end: 0,
                        duration: 200.ms,
                        curve: Curves.easeOut),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
          _CommentInput(
            controller: _commentCtrl,
            focusNode: _commentFocus,
            isSubmitting: state.isSubmitting,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }

  Widget _detailFlightShuttle(
      BuildContext flightContext,
      Animation<double> animation,
      HeroFlightDirection direction,
      BuildContext fromHeroContext,
      BuildContext toHeroContext,
      ) {
    return Material(
      type: MaterialType.transparency,
      child: direction == HeroFlightDirection.push
          ? toHeroContext.widget
          : fromHeroContext.widget,
    );
  }
}

class _DetailAppBar extends StatelessWidget {
  final PostModel? post;
  const _DetailAppBar({this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundMain,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).pop();
              },
              behavior: HitTestBehavior.opaque,
              child: const SizedBox(
                width: 52,
                height: 52,
                child: Center(
                  child: Icon(LucideIcons.arrowLeft,
                      size: 20, color: AppColors.textPrimary),
                ),
              ),
            ),
            Expanded(
              child: Text(
                post?.type == 'tea' ? 'Tea' : 'Spill',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  fontFamily: 'DM Sans',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 52),
          ],
        ),
      ),
    );
  }
}

class _PostBody extends StatelessWidget {
  final PostModel post;
  final VoidCallback onLike;
  final VoidCallback onWitness;

  const _PostBody(
      {required this.post, required this.onLike, required this.onWitness});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = post.authorAvatarConfig != null
        ? AvatarConfig.fromMap(post.authorAvatarConfig!).buildUrl(size: 72)
        : null;
    final timeStr =
    post.createdAt != null ? timeago.format(post.createdAt!) : 'just now';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _AvatarRing(url: avatarUrl, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    Text(
                      timeStr,
                      style: AppTypography.bodySmall
                          .copyWith(fontSize: 11, color: AppColors.hintText),
                    ),
                  ],
                ),
              ),
              _WitnessBtn(onTap: onWitness),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            post.heading,
            style: AppTypography.bodyMedium.copyWith(
              fontFamily: 'DM Sans',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          if (post.body != null && post.body!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              post.body!,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ],
          if (post.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ImageGrid(urls: post.imageUrls),
          ],
          if (post.audioUrl != null && post.audioUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _VoicePlayer(
              key: ValueKey('detail_${post.postId}'),
              audioUrl: post.audioUrl!,
              durationSecs: post.audioDuration ?? 0,
            ),
          ],
          const SizedBox(height: 14),
          _PostReactions(post: post, onLike: onLike),
          const SizedBox(height: 14),
          Container(height: 0.5, color: const Color(0xFF1A1A1A)),
        ],
      ),
    );
  }
}

class _AvatarRing extends StatelessWidget {
  final String? url;
  final double size;
  const _AvatarRing({this.url, this.size = 36});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
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
          shape: BoxShape.circle, color: AppColors.backgroundMain),
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

  Widget _fallback() => Container(
    color: const Color(0xFF1A1A1A),
    child: const Icon(LucideIcons.user, size: 14, color: Color(0xFF444444)),
  );
}

class _WitnessBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _WitnessBtn({required this.onTap});

  @override
  State<_WitnessBtn> createState() => _WitnessBtnState();
}

class _WitnessBtnState extends State<_WitnessBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => setState(() => _pressed = true),
    onTapUp: (_) {
      setState(() => _pressed = false);
      HapticFeedback.selectionClick();
      widget.onTap();
    },
    onTapCancel: () => setState(() => _pressed = false),
    child: AnimatedScale(
      scale: _pressed ? 0.93 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: AppColors.accentPrimary.withOpacity(0.4), width: 0.8),
        ),
        child: Center(
          child: Text(
            'Witness',
            style: AppTypography.labelSmall.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.accentPrimary,
            ),
          ),
        ),
      ),
    ),
  );
}

class _ImageGrid extends StatelessWidget {
  final List<String> urls;
  const _ImageGrid({required this.urls});

  @override
  Widget build(BuildContext context) {
    if (urls.length == 1) return _ImgTile(url: urls.first, aspectRatio: 16 / 9);
    if (urls.length == 2) {
      return Row(children: [
        Expanded(child: _ImgTile(url: urls[0], aspectRatio: 1)),
        const SizedBox(width: 4),
        Expanded(child: _ImgTile(url: urls[1], aspectRatio: 1)),
      ]);
    }
    return Row(children: [
      Expanded(flex: 2, child: _ImgTile(url: urls[0], aspectRatio: 4 / 5)),
      const SizedBox(width: 4),
      Expanded(
        flex: 1,
        child: Column(children: [
          _ImgTile(url: urls[1], aspectRatio: 1),
          const SizedBox(height: 4),
          _ImgTile(url: urls[2], aspectRatio: 1),
        ]),
      ),
    ]);
  }
}

class _ImgTile extends StatelessWidget {
  final String url;
  final double aspectRatio;
  const _ImgTile({required this.url, required this.aspectRatio});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: AspectRatio(
      aspectRatio: aspectRatio,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: const Color(0xFF1A1A1A)),
        errorWidget: (_, __, ___) => Container(
          color: const Color(0xFF1A1A1A),
          child: const Center(
              child: Icon(LucideIcons.imageOff,
                  size: 20, color: AppColors.hintText)),
        ),
      ),
    ),
  );
}

class _VoicePlayer extends StatefulWidget {
  final String audioUrl;
  final int durationSecs;
  const _VoicePlayer(
      {super.key, required this.audioUrl, required this.durationSecs});

  @override
  State<_VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<_VoicePlayer> {
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;

  @override
  void initState() {
    super.initState();
    _duration = Duration(seconds: widget.durationSecs);

    _stateSub = AudioService.instance.playerStateStream.listen((s) {
      if (!mounted) return;
      final cur = AudioService.instance.currentUrl;
      final playing = s.playing &&
          s.processingState != ProcessingState.completed &&
          cur == widget.audioUrl;
      if (s.processingState == ProcessingState.completed &&
          cur == widget.audioUrl) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
        return;
      }
      setState(() => _isPlaying = playing);
      if (!playing && cur != widget.audioUrl) {
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

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

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
            color: AppColors.accentPrimary.withOpacity(0.15), width: 0.8),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 36,
              height: 36,
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
                    size: 14,
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
                const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape:
                const RoundSliderOverlayShape(overlayRadius: 12),
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

class _PostReactions extends StatefulWidget {
  final PostModel post;
  final VoidCallback onLike;
  const _PostReactions({required this.post, required this.onLike});

  @override
  State<_PostReactions> createState() => _PostReactionsState();
}

class _PostReactionsState extends State<_PostReactions>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Row(children: [
        const Icon(LucideIcons.messageCircle,
            size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 5),
        Text(
          '${widget.post.commentCount}',
          style: AppTypography.bodySmall.copyWith(
            fontSize: 14,
            color: AppColors.textSecondary,
            fontFeatures: [const FontFeature.tabularFigures()],
          ),
        ),
      ]),
      const SizedBox(width: 22),
      GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          _ctrl.forward(from: 0);
          widget.onLike();
        },
        behavior: HitTestBehavior.opaque,
        child: Row(children: [
          ScaleTransition(
            scale: _scale,
            child: Icon(
              widget.post.isLiked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              size: 18,
              color: widget.post.isLiked
                  ? AppColors.errorLight
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '${widget.post.likeCount}',
            style: AppTypography.bodySmall.copyWith(
              fontSize: 14,
              color: widget.post.isLiked
                  ? AppColors.errorLight
                  : AppColors.textSecondary,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
        ]),
      ),
    ],
  );
}

class _CommentsHeader extends StatelessWidget {
  final int count;
  const _CommentsHeader({required this.count});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
    child: Row(children: [
      Text(
        'Comments',
        style: AppTypography.bodyMedium.copyWith(
          fontFamily: 'DM Sans',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.accentPrimary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '$count',
          style: AppTypography.bodySmall.copyWith(
            fontSize: 11,
            color: AppColors.accentPrimary,
            fontFeatures: [const FontFeature.tabularFigures()],
          ),
        ),
      ),
    ]),
  );
}

class _EmptyComments extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Center(
      child: Column(children: [
        const Icon(LucideIcons.messageCircle,
            size: 28, color: AppColors.hintText),
        const SizedBox(height: 10),
        Text('No comments yet.',
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 4),
        Text('Be the first to say something.',
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.hintText, fontSize: 12)),
      ]),
    ),
  );
}

class _CommentTile extends StatelessWidget {
  final CommentModel comment;
  final VoidCallback onLike;
  const _CommentTile({required this.comment, required this.onLike});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = comment.authorAvatarConfig != null
        ? AvatarConfig.fromMap(comment.authorAvatarConfig!).buildUrl(size: 48)
        : null;
    final timeStr = comment.createdAt != null
        ? timeago.format(comment.createdAt!, locale: 'en_short')
        : 'just now';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AvatarRing(url: avatarUrl, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(
                    '@${comment.authorUsername ?? 'anon'}',
                    style: AppTypography.bodySmall.copyWith(
                      fontFamily: 'DM Sans',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(timeStr,
                      style: AppTypography.bodySmall
                          .copyWith(fontSize: 11, color: AppColors.hintText)),
                ]),
                const SizedBox(height: 4),
                Text(
                  comment.body,
                  style: AppTypography.bodySmall.copyWith(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _CommentLikeBtn(comment: comment, onLike: onLike),
        ],
      ),
    );
  }
}

class _CommentLikeBtn extends StatefulWidget {
  final CommentModel comment;
  final VoidCallback onLike;
  const _CommentLikeBtn({required this.comment, required this.onLike});

  @override
  State<_CommentLikeBtn> createState() => _CommentLikeBtnState();
}

class _CommentLikeBtnState extends State<_CommentLikeBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 180));
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
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
      HapticFeedback.selectionClick();
      _ctrl.forward(from: 0);
      widget.onLike();
    },
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Column(children: [
        ScaleTransition(
          scale: _scale,
          child: Icon(
            widget.comment.isLiked
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            size: 15,
            color: widget.comment.isLiked
                ? AppColors.errorLight
                : AppColors.hintText,
          ),
        ),
        if (widget.comment.likeCount > 0) ...[
          const SizedBox(height: 2),
          Text(
            '${widget.comment.likeCount}',
            style: AppTypography.bodySmall.copyWith(
              fontSize: 10,
              color: widget.comment.isLiked
                  ? AppColors.errorLight
                  : AppColors.hintText,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
        ],
      ]),
    ),
  );
}

class _CommentsShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    children: List.generate(
      4,
          (i) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Bone(w: 32, h: 32, radius: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Bone(w: 100, h: 11),
                  const SizedBox(height: 6),
                  _Bone(w: double.infinity, h: 13),
                  const SizedBox(height: 4),
                  _Bone(w: 160, h: 13),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Bone extends StatelessWidget {
  final double w, h, radius;
  const _Bone({required this.w, required this.h, this.radius = 4});

  @override
  Widget build(BuildContext context) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: const Color(0xFF1A1A1A),
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

class _CommentInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const _CommentInput({
    required this.controller,
    required this.focusNode,
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundMain,
        border: Border(
          top: BorderSide(color: Color(0xFF1A1A1A), width: 0.5),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 10, 12, MediaQuery.of(context).padding.bottom + 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 100),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F0F),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFF2A2A2A), width: 0.8),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                maxLines: null,
                minLines: 1,
                maxLength: 300,
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  hintText: 'Add a comment...',
                  hintStyle: AppTypography.bodySmall.copyWith(
                    fontSize: 14,
                    color: AppColors.hintText,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  border: InputBorder.none,
                  counterText: '',
                ),
                textInputAction: TextInputAction.newline,
                onSubmitted: (_) => onSubmit(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isSubmitting ? null : onSubmit,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: isSubmitting
                    ? null
                    : const LinearGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFF1DE9B6)],
                ),
                color: isSubmitting ? const Color(0xFF1A1A1A) : null,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isSubmitting
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppColors.textSecondary,
                  ),
                )
                    : const Icon(LucideIcons.send, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
//
// class _CommentInputState extends State<_CommentInput> {
//   bool _focused = false;
//   bool _hasText = false;
//
//   @override
//   void initState() {
//     super.initState();
//     widget.focusNode.addListener(_onFocusChange);
//     widget.controller.addListener(_onTextChange);
//   }
//
//   @override
//   void dispose() {
//     widget.focusNode.removeListener(_onFocusChange);
//     widget.controller.removeListener(_onTextChange);
//     super.dispose();
//   }
//
//   void _onFocusChange() {
//     if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
//   }
//
//   void _onTextChange() {
//     final has = widget.controller.text.trim().isNotEmpty;
//     if (has != _hasText && mounted) setState(() => _hasText = has);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         color: AppColors.backgroundMain,
//         border: Border(
//           top: BorderSide(
//             color: _focused
//                 ? AppColors.accentPrimary.withOpacity(0.25)
//                 : const Color(0xFF1A1A1A),
//             width: 0.5,
//           ),
//         ),
//       ),
//       padding: EdgeInsets.fromLTRB(
//           16, 10, 12, MediaQuery.of(context).padding.bottom + 10),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.end,
//         children: [
//           Expanded(
//             child: TextField(
//               controller: widget.controller,
//               focusNode: widget.focusNode,
//               maxLines: null,
//               minLines: 1,
//               maxLength: 300,
//               style: AppTypography.bodySmall.copyWith(
//                 fontSize: 14,
//                 color: AppColors.textPrimary,
//                 height: 1.4,
//               ),
//               decoration: InputDecoration(
//                 hintText: 'say something...',
//                 hintStyle: AppTypography.bodySmall.copyWith(
//                   fontSize: 14,
//                   color: AppColors.hintText,
//                   fontStyle: FontStyle.italic,
//                 ),
//                 contentPadding:
//                 const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
//                 border: InputBorder.none,
//                 enabledBorder: UnderlineInputBorder(
//                   borderSide: BorderSide(
//                     color: const Color(0xFF2A2A2A),
//                     width: 0.8,
//                   ),
//                 ),
//                 focusedBorder: UnderlineInputBorder(
//                   borderSide: BorderSide(
//                     color: AppColors.accentPrimary.withOpacity(0.5),
//                     width: 1.0,
//                   ),
//                 ),
//                 counterText: '',
//               ),
//               textInputAction: TextInputAction.newline,
//               onSubmitted: (_) => widget.onSubmit(),
//             ),
//           ),
//           const SizedBox(width: 12),
//           GestureDetector(
//             onTap: widget.isSubmitting || !_hasText ? null : widget.onSubmit,
//             child: AnimatedOpacity(
//               opacity: widget.isSubmitting
//                   ? 0.4
//                   : _hasText
//                   ? 1.0
//                   : 0.3,
//               duration: const Duration(milliseconds: 180),
//               child: widget.isSubmitting
//                   ? const SizedBox(
//                 width: 20,
//                 height: 20,
//                 child: CircularProgressIndicator(
//                   strokeWidth: 1.5,
//                   color: AppColors.accentPrimary,
//                 ),
//               )
//                   : ShaderMask(
//                 shaderCallback: (bounds) => const LinearGradient(
//                   colors: [Color(0xFF7C4DFF), Color(0xFF1DE9B6)],
//                 ).createShader(bounds),
//                 blendMode: BlendMode.srcIn,
//                 child: const Icon(
//                   LucideIcons.send,
//                   size: 20,
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
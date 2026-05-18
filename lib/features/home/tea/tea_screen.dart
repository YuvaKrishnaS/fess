import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../post_detail/post_detail_screen.dart';
import '../providers/tea_feed_provider.dart';
import '../providers/feed_provider.dart';
import '../widgets/tea_card.dart';

class TeaScreen extends ConsumerStatefulWidget {
  const TeaScreen({super.key});

  @override
  ConsumerState<TeaScreen> createState() => _TeaScreenState();
}

class _TeaScreenState extends ConsumerState<TeaScreen> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent * 0.8) {
      ref.read(teaFeedProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            backgroundColor: AppColors.backgroundMain,
            floating: true,
            snap: true,
            pinned: false,
            elevation: 0,
            toolbarHeight: 0,
            scrolledUnderElevation: 0,
            automaticallyImplyLeading: false,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: _TeaAppBar(),
            ),
          ),
        ],
        body: _TeaBody(scrollController: _scroll),
      ),
    );
  }
}

class _TeaAppBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppColors.backgroundMain,
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
      child: Row(
        children: [
          const SizedBox(width: 44),
          const Spacer(),
          // Logo PNG — dropped in when asset is ready
          Image.asset(
            'assets/images/logo.png',
            height: 26,
            errorBuilder: (_, __, ___) => Text(
              'Tea',
              style: AppTypography.bodyMedium.copyWith(
                fontFamily: 'DM Sans',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: 2.0,
              ),
            ),
          ),
          const Spacer(),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _TeaBody extends ConsumerWidget {
  final ScrollController scrollController;

  const _TeaBody({required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(teaFeedProvider);
    final anonId = ref.watch(currentAnonIdProvider).value;

    return feedAsync.when(
      loading: () => _ShimmerList(),
      error: (_, __) => _ErrorState(
        onRetry: () => ref.read(teaFeedProvider.notifier).refresh(),
      ),
      data: (feed) {
        if (feed.isLoading) return _ShimmerList();

        if (feed.error != null && feed.posts.isEmpty) {
          return _ScrollableError(
            message: feed.error!,
            scrollController: scrollController,
            onRetry: () => ref.read(teaFeedProvider.notifier).refresh(),
          );
        }

        if (feed.posts.isEmpty) {
          return _EmptyState(scrollController: scrollController);
        }

        return RefreshIndicator(
          color: AppColors.accentPrimary,
          backgroundColor: const Color(0xFF1A1A1A),
          onRefresh: () => ref.read(teaFeedProvider.notifier).refresh(),
          child: ListView.builder(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: feed.posts.length + (feed.isLoadingMore ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (i == feed.posts.length) return const _LoadMore();
              final post = feed.posts[i];
              return TeaCard(
                post: post,
                currentAnonId: anonId,
                onTap: () => Navigator.of(ctx).push(
                  MaterialPageRoute(
                    builder: (_) => PostDetailScreen(postId: post.postId),
                  ),
                ),
                onLike: () =>
                    ref.read(teaFeedProvider.notifier).toggleLike(post.postId),
                // onWitness: () => FessSnackbar.show(
                //   ctx,
                //   'Witness system — Coming soon',
                //   type: SnackbarType.info,
                // ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ShimmerList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      itemBuilder: (_, __) => const TeaShimmerCard(),
    );
  }
}

class _LoadMore extends StatelessWidget {
  const _LoadMore();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ScrollController scrollController;
  const _EmptyState({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.22),
        Center(
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accentPrimary.withOpacity(0.06),
                    ),
                  ),
                  const Icon(LucideIcons.coffee,
                      size: 28, color: AppColors.accentPrimary),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'No tea yet.',
                style: AppTypography.bodyMedium.copyWith(
                  fontFamily: 'DM Sans',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Text(
                  'Be the first to spill it.',
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.wifiOff,
              size: 28, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text('Could not load tea.',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onRetry,
            child: Text('Retry',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.accentPrimary,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ],
      ),
    );
  }
}

class _ScrollableError extends StatelessWidget {
  final String message;
  final ScrollController scrollController;
  final Future<void> Function() onRetry;

  const _ScrollableError({
    required this.message,
    required this.scrollController,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.accentPrimary,
      backgroundColor: const Color(0xFF1A1A1A),
      onRefresh: onRetry,
      child: ListView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                message,
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textSecondary, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
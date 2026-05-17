import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/models/avatar_config.dart';
import '../../../core/widgets/fess_snackbar.dart';
import '../post_detail/post_detail_screen.dart';
import '../providers/feed_provider.dart';
import '../providers/scroll_visibility_provider.dart';
import '../widgets/confession_card.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final ScrollController _forYouScroll = ScrollController();
  final ScrollController _trendingScroll = ScrollController();
  double _lastOffset = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _forYouScroll.addListener(_onForYouScroll);
    _trendingScroll.addListener(_onTrendingScroll);
  }

  @override
  void dispose() {
    _tab.dispose();
    _forYouScroll.dispose();
    _trendingScroll.dispose();
    super.dispose();
  }

  void _onForYouScroll() {
    _handleScrollVisibility(_forYouScroll);
    if (_forYouScroll.position.pixels >=
        _forYouScroll.position.maxScrollExtent * 0.8) {
      ref.read(forYouFeedProvider.notifier).loadMore();
    }
  }

  void _onTrendingScroll() {
    _handleScrollVisibility(_trendingScroll);
  }

  void _handleScrollVisibility(ScrollController ctrl) {
    final offset = ctrl.position.pixels;
    final diff = offset - _lastOffset;
    _lastOffset = offset;
    if (offset < 10) {
      scrollVisibilityNotifier.value = true;
    } else if (diff > 4) {
      scrollVisibilityNotifier.value = false;
    } else if (diff < -4) {
      scrollVisibilityNotifier.value = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusBarH = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, innerScrolled) => [
          SliverAppBar(
            backgroundColor: AppColors.backgroundMain,
            floating: true,
            snap: true,
            pinned: false,
            elevation: 0,
            scrolledUnderElevation: 0,
            automaticallyImplyLeading: false,
            toolbarHeight: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: _AppBarContent(),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(tab: _tab, topPad: statusBarH),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            _ForYouTab(scrollController: _forYouScroll),
            _TrendingTab(scrollController: _trendingScroll),
          ],
        ),
      ),
    );
  }
}

class _AppBarContent extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    return Container(
      color: AppColors.backgroundMain,
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
      child: Row(
        children: [
          _AppBarAvatar(profile: profileAsync.value),
          const Spacer(),
          const Text(
            'Fess',
            style: TextStyle(
              fontFamily: 'DM Sans',
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          _StreakCup(),
        ],
      ),
    );
  }
}

class _AppBarAvatar extends StatelessWidget {
  final Map<String, dynamic>? profile;
  const _AppBarAvatar({this.profile});

  @override
  Widget build(BuildContext context) {
    final url = profile?['avatarConfig'] != null
        ? AvatarConfig.fromMap(
        profile!['avatarConfig'] as Map<String, dynamic>)
        .buildUrl(size: 72)
        : null;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        FessSnackbar.show(context, 'Profile — Coming soon',
            type: SnackbarType.info);
      },
      child: Container(
        width: 34,
        height: 34,
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
          padding: const EdgeInsets.all(1.5),
          child: ClipOval(
            child: url != null
                ? Image.network(url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback())
                : _fallback(),
          ),
        ),
      ),
    );
  }

  Widget _fallback() => Container(
    color: const Color(0xFF1A1A1A),
    child: const Icon(LucideIcons.user, size: 14, color: Color(0xFF444444)),
  );
}

class _StreakCup extends StatelessWidget {
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      HapticFeedback.selectionClick();
      _showStreakSheet(context);
    },
    child: const SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: Icon(LucideIcons.coffee,
            size: 22, color: AppColors.textSecondary),
      ),
    ),
  );

  void _showStreakSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F0F0F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFF3A3A3A),
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 28),
              const Icon(LucideIcons.coffee,
                  size: 36, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              Text('Your streak is at risk.',
                  style: AppTypography.h4.copyWith(fontSize: 16),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Post a spill or tea every day to keep it alive.',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController tab;
  final double topPad;
  const _TabBarDelegate({required this.tab, required this.topPad});

  @override
  double get minExtent => 44;
  @override
  double get maxExtent => 44;

  @override
  bool shouldRebuild(_TabBarDelegate old) =>
      old.tab != tab || old.topPad != topPad;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.backgroundMain,
      child: Column(
        children: [
          Expanded(
            child: TabBar(
              controller: tab,
              onTap: (_) => HapticFeedback.selectionClick(),
              indicatorColor: AppColors.accentPrimary,
              indicatorWeight: 2,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: Colors.transparent,
              labelColor: AppColors.textPrimary,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: AppTypography.labelMedium
                  .copyWith(fontSize: 14, fontWeight: FontWeight.w600),
              unselectedLabelStyle: AppTypography.labelMedium
                  .copyWith(fontSize: 14, fontWeight: FontWeight.w400),
              tabs: const [Tab(text: 'For You'), Tab(text: 'Trending')],
            ),
          ),
          Container(height: 0.5, color: const Color(0xFF1A1A1A)),
        ],
      ),
    );
  }
}

class _ForYouTab extends ConsumerWidget {
  final ScrollController scrollController;
  const _ForYouTab({required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(forYouFeedProvider);

    return feedAsync.when(
      loading: () => _ShimmerList(),
      error: (_, __) => _ErrorState(
        onRetry: () => ref.read(forYouFeedProvider.notifier).refresh(),
      ),
      data: (feed) {
        if (feed.isLoading) return _ShimmerList();

        if (feed.error != null && feed.posts.isEmpty) {
          return _ScrollableError(
            message: feed.error!,
            scrollController: scrollController,
            onRetry: () => ref.read(forYouFeedProvider.notifier).refresh(),
          );
        }

        if (feed.posts.isEmpty) {
          return _EmptyState(scrollController: scrollController);
        }

        return RefreshIndicator(
          color: AppColors.accentPrimary,
          backgroundColor: const Color(0xFF1A1A1A),
          onRefresh: () => ref.read(forYouFeedProvider.notifier).refresh(),
          child: ListView.builder(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: feed.posts.length + (feed.isLoadingMore ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (i == feed.posts.length) return const _LoadMore();
              final post = feed.posts[i];
              return ConfessionCard(
                key: ValueKey(post.postId),
                post: post,
                currentAnonId: null,
                onTap: () => Navigator.of(ctx).push(
                  postDetailHeroRoute(post.postId, initialPost: post),
                ),
                onLike: () =>
                    ref.read(forYouFeedProvider.notifier).toggleLike(post.postId),
              );
            },
          ),
        );
      },
    );
  }
}

class _TrendingTab extends StatelessWidget {
  final ScrollController scrollController;
  const _TrendingTab({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Center(
          child: Column(
            children: [
              const Icon(LucideIcons.trendingUp,
                  size: 28, color: AppColors.hintText),
              const SizedBox(height: 12),
              Text(
                'Trending — coming soon.',
                style: AppTypography.bodyMedium.copyWith(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShimmerList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      itemBuilder: (_, __) => const ConfessionShimmerCard(),
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
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Center(
          child: Column(
            children: [
              const Icon(LucideIcons.inbox,
                  size: 28, color: AppColors.hintText),
              const SizedBox(height: 12),
              Text(
                'Nothing here yet.',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textSecondary, fontSize: 14),
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
          Text('Could not load feed.',
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
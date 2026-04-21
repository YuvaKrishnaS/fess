import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/models/avatar_config.dart';
import '../../../core/widgets/fess_snackbar.dart';
import '../providers/feed_provider.dart';
import '../widgets/confession_card.dart';
import '../widgets/create_confession_sheet.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _forYouScroll = ScrollController();
  final ScrollController _followingScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _forYouScroll.addListener(_onForYouScroll);
    _followingScroll.addListener(_onFollowingScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _forYouScroll.dispose();
    _followingScroll.dispose();
    super.dispose();
  }

  void _onForYouScroll() {
    if (_forYouScroll.position.pixels >=
        _forYouScroll.position.maxScrollExtent * 0.8) {
      ref.read(forYouFeedProvider.notifier).loadMore();
    }
  }

  void _onFollowingScroll() {
    if (_followingScroll.position.pixels >=
        _followingScroll.position.maxScrollExtent * 0.8) {
      ref.read(followingFeedProvider.notifier).loadMore();
    }
  }

  void _openCreateSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => const CreateConfessionSheet(),
    ).then((_) {
      // Refresh feed after posting
      ref.read(forYouFeedProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverToBoxAdapter(child: _AppBar(onFabTap: _openCreateSheet)),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(tabController: _tabController),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _ForYouTab(scrollController: _forYouScroll),
            _FollowingTab(scrollController: _followingScroll),
          ],
        ),
      ),
      floatingActionButton: _FeedFab(onTap: _openCreateSheet),
    );
  }
}

// ─── App Bar ──────────────────────────────────────────────────────────────────

class _AppBar extends ConsumerWidget {
  final VoidCallback onFabTap;

  const _AppBar({required this.onFabTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Container(
      color: AppColors.backgroundMain,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 8,
      ),
      child: Row(
        children: [
          // Left: user avatar
          profileAsync.when(
            data: (profile) => _AvatarButton(profile: profile),
            loading: () => const SizedBox(width: 36, height: 36),
            error: (_, __) => const SizedBox(width: 36, height: 36),
          ),
          const Spacer(),
          // Center: FESS logo
          Text(
            'FESS',
            style: AppTypography.h3.copyWith(
              letterSpacing: 4,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          // Right: streak cup
          _StreakCup(),
        ],
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  final Map<String, dynamic>? profile;

  const _AvatarButton({this.profile});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile != null &&
        profile!['avatarConfig'] != null
        ? AvatarConfig.fromMap(
        profile!['avatarConfig'] as Map<String, dynamic>)
        .buildUrl(size: 36)
        : null;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        FessSnackbar.show(context, 'Profile — Coming soon',
            type: SnackbarType.info);
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.accentPrimary,
            width: 1.5,
          ),
        ),
        child: ClipOval(
          child: avatarUrl != null
              ? CachedNetworkImage(
            imageUrl: avatarUrl,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            placeholder: (_, __) =>
                Container(color: AppColors.elevated),
            errorWidget: (_, __, ___) => _defaultAvatar(),
          )
              : _defaultAvatar(),
        ),
      ),
    );
  }

  Widget _defaultAvatar() => Container(
    color: AppColors.elevated,
    child: Center(
      child: Icon(LucideIcons.user, size: 18, color: AppColors.hintText),
    ),
  );
}

class _StreakCup extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // M9 scope — cup reads from Firestore streak data
    // For now: show grey cup (at-risk state) as default
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _showStreakSheet(context);
      },
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Icon(
            LucideIcons.coffee,
            size: 28,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  void _showStreakSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppColors.elevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Icon(LucideIcons.coffee,
                size: 40, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              '⚠️ Your streak is fading. Post something.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Post a confession or tea every day to keep your streak.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─── Tab bar delegate ─────────────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabController;

  const _TabBarDelegate({required this.tabController});

  @override
  double get minExtent => 44;

  @override
  double get maxExtent => 44;

  @override
  bool shouldRebuild(_TabBarDelegate old) => false;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.backgroundMain,
      child: Column(
        children: [
          _FeedTabBar(tabController: tabController),
          Container(height: 0.5, color: AppColors.elevated),
        ],
      ),
    );
  }
}

class _FeedTabBar extends StatelessWidget {
  final TabController tabController;

  const _FeedTabBar({required this.tabController});

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: tabController,
      onTap: (_) => HapticFeedback.selectionClick(),
      indicatorColor: AppColors.accentPrimary,
      indicatorWeight: 2,
      indicatorSize: TabBarIndicatorSize.label,
      labelColor: AppColors.textPrimary,
      unselectedLabelColor: AppColors.textSecondary,
      labelStyle: AppTypography.labelMedium.copyWith(
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: AppTypography.labelMedium.copyWith(
        fontWeight: FontWeight.w400,
      ),
      tabs: const [
        Tab(text: 'For You'),
        Tab(text: 'Following'),
      ],
    );
  }
}

// ─── For You tab ──────────────────────────────────────────────────────────────

class _ForYouTab extends ConsumerWidget {
  final ScrollController scrollController;

  const _ForYouTab({required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(forYouFeedProvider);
    final anonIdAsync = ref.watch(currentAnonIdProvider);
    final currentAnonId = anonIdAsync.value;

    return feedAsync.when(
      loading: () => _ShimmerList(),
      error: (e, __) => Center(
        child: Text(
          'Something went wrong.',
          style:
          AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
      ),
      data: (feed) {
        if (feed.isLoading) return _ShimmerList();

        if (feed.error != null && feed.posts.isEmpty) {
          return Center(
            child: Text(
              feed.error!,
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          );
        }

        if (feed.posts.isEmpty) {
          return RefreshIndicator(
            color: AppColors.accentPrimary,
            backgroundColor: AppColors.elevated,
            onRefresh: () =>
                ref.read(forYouFeedProvider.notifier).refresh(),
            child: ListView(
              controller: scrollController,
              children: const [
                FeedEmptyState(
                  icon: LucideIcons.feather,
                  message: 'Nothing yet. Drop the first confession.',
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.accentPrimary,
          backgroundColor: AppColors.elevated,
          onRefresh: () => ref.read(forYouFeedProvider.notifier).refresh(),
          child: ListView.builder(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: feed.posts.length + (feed.isLoadingMore ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == feed.posts.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: AppColors.accentPrimary,
                      ),
                    ),
                  ),
                );
              }

              final post = feed.posts[i];
              return ConfessionCard(
                post: post,
                currentAnonId: currentAnonId,
                onTap: () => FessSnackbar.show(
                  context,
                  'Post detail — Coming soon',
                  type: SnackbarType.info,
                ),
                onLike: () => ref
                    .read(forYouFeedProvider.notifier)
                    .toggleLike(post.postId),
                onWitness: () => FessSnackbar.show(
                  context,
                  'Witness system — Coming soon',
                  type: SnackbarType.info,
                ),
              )
                  .animate()
                  .fadeIn(
                delay: Duration(milliseconds: i < 5 ? i * 60 : 0),
                duration: 300.ms,
              )
                  .slideY(
                begin: 0.05,
                end: 0,
                delay: Duration(milliseconds: i < 5 ? i * 60 : 0),
                duration: 300.ms,
                curve: Curves.easeOut,
              );
            },
          ),
        );
      },
    );
  }
}

// ─── Following tab ────────────────────────────────────────────────────────────

class _FollowingTab extends ConsumerWidget {
  final ScrollController scrollController;

  const _FollowingTab({required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(followingFeedProvider);
    final anonIdAsync = ref.watch(currentAnonIdProvider);
    final currentAnonId = anonIdAsync.value;

    return feedAsync.when(
      loading: () => _ShimmerList(),
      error: (_, __) => Center(
        child: Text('Something went wrong.',
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.textSecondary)),
      ),
      data: (feed) {
        if (feed.isLoading) return _ShimmerList();

        if (feed.posts.isEmpty) {
          return RefreshIndicator(
            color: AppColors.accentPrimary,
            backgroundColor: AppColors.elevated,
            onRefresh: () =>
                ref.read(followingFeedProvider.notifier).refresh(),
            child: ListView(
              controller: scrollController,
              children: const [
                FeedEmptyState(
                  icon: LucideIcons.users,
                  message:
                  'No confessions from people you Witness yet.',
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.accentPrimary,
          backgroundColor: AppColors.elevated,
          onRefresh: () =>
              ref.read(followingFeedProvider.notifier).refresh(),
          child: ListView.builder(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount:
            feed.posts.length + (feed.isLoadingMore ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == feed.posts.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: AppColors.accentPrimary,
                      ),
                    ),
                  ),
                );
              }

              final post = feed.posts[i];
              return ConfessionCard(
                post: post,
                currentAnonId: currentAnonId,
                onTap: () => FessSnackbar.show(
                  context,
                  'Post detail — Coming soon',
                  type: SnackbarType.info,
                ),
                onLike: () => ref
                    .read(followingFeedProvider.notifier)
                    .toggleLike(post.postId),
                onWitness: () => FessSnackbar.show(
                  context,
                  'Witness system — Coming soon',
                  type: SnackbarType.info,
                ),
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
      itemBuilder: (_, __) => const ConfessionShimmerCard(),
    );
  }
}

// ─── FAB (wired version) ──────────────────────────────────────────────────────

class _FeedFab extends StatefulWidget {
  final VoidCallback onTap;

  const _FeedFab({required this.onTap});

  @override
  State<_FeedFab> createState() => _FeedFabState();
}

class _FeedFabState extends State<_FeedFab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7C4DFF), Color(0xFF1DE9B6)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.accentPrimary.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Icon(LucideIcons.feather, size: 22, color: Colors.white),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 300.ms, duration: 400.ms)
        .scale(
      begin: const Offset(0.7, 0.7),
      delay: 300.ms,
      duration: 400.ms,
      curve: Curves.easeOutBack,
    );
  }
}
// lib/features/home/screens/profile_page.dart

import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/models/avatar_config.dart';
import '../../../core/widgets/fess_snackbar.dart';
import '../../home/post_detail/post_detail_screen.dart';
import '../providers/feed_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/confession_card.dart';

class ProfilePage extends ConsumerStatefulWidget {
  final String anonId;
  final int initialTab;

  const ProfilePage({
    super.key,
    required this.anonId,
    this.initialTab = 0,
  });

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myIdAsync = ref.watch(currentAnonIdProvider);

    return myIdAsync.when(
      loading: () => const _PageScaffold(child: _CenteredSpinner()),
      error: (_, __) =>
      const _PageScaffold(child: _PageError(msg: 'Could not load profile.')),
      data: (myId) {
        final isOwn = widget.anonId == myId;
        return _ProfilePageBody(
          anonId: widget.anonId,
          myId: myId,
          isOwn: isOwn,
          tab: _tab,
        );
      },
    );
  }
}

class _PageScaffold extends StatelessWidget {
  final Widget child;
  const _PageScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: AppColors.backgroundMain, body: child);
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _ProfilePageBody extends ConsumerWidget {
  final String anonId;
  final String? myId;
  final bool isOwn;
  final TabController tab;

  const _ProfilePageBody({
    required this.anonId,
    required this.myId,
    required this.isOwn,
    required this.tab,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileDataProvider(anonId));

    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverToBoxAdapter(
            child: Column(
              children: [
                _ProfileAppBar(anonId: anonId, isOwn: isOwn),
                profileAsync.when(
                  loading: () => const _FullHeaderShimmer(),
                  error: (_, __) =>
                  const _PageError(msg: 'Could not load profile.'),
                  data: (profile) {
                    if (profile == null) {
                      return const _PageError(msg: 'Profile not found.');
                    }
                    return _FullProfileHeader(
                      profile: profile,
                      isOwn: isOwn,
                      myId: myId,
                    );
                  },
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyTabBarDelegate(
              TabBar(
                controller: tab,
                onTap: (_) => HapticFeedback.selectionClick(),
                indicatorColor: AppColors.accentPrimary,
                indicatorWeight: 2,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: AppTypography.labelMedium.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: AppTypography.labelMedium.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
                tabs: [
                  Tab(text: isOwn ? 'My Spills' : 'Spills'),
                  Tab(text: isOwn ? 'My Tea' : 'Tea'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: tab,
          children: [
            _SpillsTab(anonId: anonId, myId: myId),
            _TeaTab(anonId: anonId, myId: myId),
          ],
        ),
      ),
    );
  }
}

// ─── App Bar ──────────────────────────────────────────────────────────────────

class _ProfileAppBar extends ConsumerWidget {
  final String anonId;
  final bool isOwn;

  const _ProfileAppBar({required this.anonId, required this.isOwn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      color: AppColors.backgroundMain,
      padding: EdgeInsets.fromLTRB(8, topPad + 8, 8, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(LucideIcons.arrowLeft,
                size: 20, color: AppColors.textPrimary),
            onPressed: () => context.pop(),
          ),
          const Spacer(),
          if (isOwn)
            IconButton(
              icon: const Icon(LucideIcons.settings,
                  size: 20, color: AppColors.textSecondary),
              onPressed: () {
                HapticFeedback.selectionClick();
                context.push('/settings/profile');
              },
            ),
        ],
      ),
    );
  }
}

// ─── Profile Header ───────────────────────────────────────────────────────────

class _FullProfileHeader extends StatelessWidget {
  final ProfileData profile;
  final bool isOwn;
  final String? myId;

  const _FullProfileHeader({
    required this.profile,
    required this.isOwn,
    required this.myId,
  });

  String? _avatarUrl() {
    if (profile.avatarConfig.isEmpty) return null;
    try {
      return AvatarConfig.fromMap(profile.avatarConfig).buildUrl(size: 200);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _avatarUrl();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.accentPrimary.withOpacity(0.4),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: avatarUrl != null
                  ? CachedNetworkImage(
                imageUrl: avatarUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: const Color(0xFF1A1A1A)),
                errorWidget: (_, __, ___) => const _AnonAvatarLg(),
              )
                  : const _AnonAvatarLg(),
            ),
          ),
          const SizedBox(height: 14),

          // ── Username
          Text(
            '@${profile.username}',
            style: AppTypography.h2.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),

          // ── Anon ID (long-press to copy)
          GestureDetector(
            onLongPress: () {
              Clipboard.setData(ClipboardData(text: profile.anonId));
              FessSnackbar.show(
                context,
                'Anon ID copied',
                type: SnackbarType.success,
                duration: const Duration(seconds: 1),
              );
            },
            child: Text(
              '#${profile.anonId}',
              style: AppTypography.bodySmall.copyWith(
                fontSize: 11,
                color: AppColors.hintText,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Stats
          Row(
            children: [
              _StatBlock(label: 'Spills', value: profile.totalPostCount),
              const SizedBox(width: 28),
              _StatBlock(label: 'Tea', value: profile.totalTeaCount),
            ],
          ),
          const SizedBox(height: 20),

          // ── Action buttons (only on other people's profiles)
          if (!isOwn) ...[
            _ProfileActions(
              profile: profile,
              myId: myId,
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

// ─── Profile Action Buttons ───────────────────────────────────────────────────
// Shown only on other people's profiles: Message button

class _ProfileActions extends StatelessWidget {
  final ProfileData profile;
  final String? myId;

  const _ProfileActions({required this.profile, required this.myId});

  String? _avatarUrl() {
    if (profile.avatarConfig.isEmpty) return null;
    try {
      return AvatarConfig.fromMap(profile.avatarConfig).buildUrl(size: 92);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Message button
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            context.push(
              '/dm/${profile.anonId}',
              extra: {
                'username': profile.username,
                'avatarUrl': _avatarUrl(),
              },
            );
          },
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D0D),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF2A2A3A),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.messageCircle,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 7),
                Text(
                  'Message',
                  style: AppTypography.labelSmall.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Stat block ───────────────────────────────────────────────────────────────

class _StatBlock extends StatelessWidget {
  final String label;
  final int value;

  const _StatBlock({required this.label, required this.value});

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _fmt(value),
          style: AppTypography.bodyMedium.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ─── Tabs ─────────────────────────────────────────────────────────────────────

class _SpillsTab extends ConsumerWidget {
  final String anonId;
  final String? myId;
  const _SpillsTab({required this.anonId, required this.myId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(mySpillsProvider(anonId));

    return feedAsync.when(
      loading: _shimmerList,
      error: (e, __) {
        debugPrint('[_SpillsTab] provider error: $e');
        return _emptyState('Could not load spills.\n$e', isError: true);
      },
      data: (feed) {
        if (feed.error != null) {
          debugPrint('[_SpillsTab] feed error: ${feed.error}');
          return _emptyState(feed.error!, isError: true);
        }
        if (feed.posts.isEmpty) {
          return _emptyState(
              'No spills yet.\nWhen you spill, they show up here.');
        }
        return ListView.builder(
          itemCount: feed.posts.length + 1,
          itemBuilder: (ctx, i) {
            if (i == feed.posts.length) return _EasterEgg();
            final post = feed.posts[i];
            return ConfessionCard(
              key: ValueKey(post.postId),
              post: post,
              currentAnonId: myId,
              onTap: () => Navigator.of(ctx).push(
                postDetailHeroRoute(post.postId, initialPost: post),
              ),
              onLike: () =>
                  ref.read(forYouFeedProvider.notifier).toggleLike(post.postId),
              onAuthorTap: post.authorId != myId
                  ? () => context.push('/profile/${post.authorId}')
                  : null,
              onDelete: () => ref.invalidate(mySpillsProvider(anonId)),
            );
          },
        );
      },
    );
  }
}

class _TeaTab extends ConsumerWidget {
  final String anonId;
  final String? myId;
  const _TeaTab({required this.anonId, required this.myId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(myTeaProvider(anonId));

    return feedAsync.when(
      loading: _shimmerList,
      error: (e, __) {
        debugPrint('[_TeaTab] provider error: $e');
        return _emptyState('Could not load tea.\n$e', isError: true);
      },
      data: (feed) {
        if (feed.error != null) {
          debugPrint('[_TeaTab] feed error: ${feed.error}');
          return _emptyState(feed.error!, isError: true);
        }
        if (feed.posts.isEmpty) {
          return _emptyState('No tea yet.\nSpill the tea to see it here.');
        }
        return ListView.builder(
          itemCount: feed.posts.length + 1,
          itemBuilder: (ctx, i) {
            if (i == feed.posts.length) return _EasterEgg();
            final post = feed.posts[i];
            return ConfessionCard(
              key: ValueKey(post.postId),
              post: post,
              currentAnonId: myId,
              onTap: () => Navigator.of(ctx).push(
                postDetailHeroRoute(post.postId, initialPost: post),
              ),
              onLike: () =>
                  ref.read(forYouFeedProvider.notifier).toggleLike(post.postId),
              onAuthorTap: post.authorId != myId
                  ? () => context.push('/profile/${post.authorId}')
                  : null,
              onDelete: () => ref.invalidate(myTeaProvider(anonId)),
            );
          },
        );
      },
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _StickyTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height + 1;

  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.backgroundMain,
      child: Column(
        children: [
          tabBar,
          Container(height: 1, color: const Color(0xFF1A1A1A)),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate old) => false;
}

class _AnonAvatarLg extends StatelessWidget {
  const _AnonAvatarLg();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: const Icon(LucideIcons.user, size: 36, color: AppColors.hintText),
    );
  }
}

class _EasterEgg extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: 0.25,
            child: Image.asset('assets/images/logo.png', width: 48, height: 48),
          ),
          const SizedBox(height: 16),
          Text(
            'You reached the end of the posts! go touch some grass ;P',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              fontSize: 13,
              color: const Color(0xFF3A3A3A),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Fess',
            style: AppTypography.h3.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF252525),
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _shimmerList() => ListView.builder(
  physics: const NeverScrollableScrollPhysics(),
  itemCount: 4,
  itemBuilder: (_, __) => const ConfessionShimmerCard(),
);

Widget _emptyState(String msg, {bool isError = false}) => Center(
  child: Padding(
    padding: const EdgeInsets.all(32),
    child: Text(
      msg,
      textAlign: TextAlign.center,
      style: AppTypography.bodyMedium.copyWith(
        fontSize: 14,
        color: isError ? AppColors.errorLight : AppColors.textSecondary,
        height: 1.6,
        decoration: TextDecoration.none,
      ),
    ),
  ),
);

class _CenteredSpinner extends StatelessWidget {
  const _CenteredSpinner();

  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 1.5,
        color: AppColors.textSecondary,
      ),
    ),
  );
}

class _PageError extends StatelessWidget {
  final String msg;
  const _PageError({required this.msg});

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      msg,
      style: AppTypography.bodySmall.copyWith(
        color: AppColors.textSecondary,
        decoration: TextDecoration.none,
      ),
    ),
  );
}

class _FullHeaderShimmer extends StatelessWidget {
  const _FullHeaderShimmer();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShimmerBox(width: 80, height: 80, radius: 40),
          SizedBox(height: 14),
          _ShimmerBox(width: 160, height: 20, radius: 5),
          SizedBox(height: 6),
          _ShimmerBox(width: 110, height: 11, radius: 5),
          SizedBox(height: 20),
          Row(
            children: [
              _ShimmerBox(width: 64, height: 36, radius: 6),
              SizedBox(width: 28),
              _ShimmerBox(width: 64, height: 36, radius: 6),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.radius,
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
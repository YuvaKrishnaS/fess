import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/models/avatar_config.dart';
import '../../home/post_detail/post_detail_screen.dart';
import '../providers/feed_provider.dart';
import '../providers/profile_provider.dart';
import 'confession_card.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

void showProfileSheet(BuildContext context, {String? anonId}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.6),
    builder: (_) => _ProfileSheet(anonId: anonId),
  );
}

// ── Sheet root ────────────────────────────────────────────────────────────────

class _ProfileSheet extends ConsumerStatefulWidget {
  final String? anonId;
  const _ProfileSheet({this.anonId});

  @override
  ConsumerState<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends ConsumerState<_ProfileSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  String? _resolvedId;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
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
      loading: () => const _SheetScaffold(child: _LoadingBody()),
      error: (_, __) => const _SheetScaffold(child: _ErrorBody()),
      data: (myId) {
        _resolvedId = widget.anonId ?? myId;
        final isOwn = _resolvedId == myId || widget.anonId == null;
        if (_resolvedId == null) {
          return const _SheetScaffold(child: _ErrorBody());
        }
        return _SheetScaffold(
          child: _ProfileBody(
            anonId: _resolvedId!,
            isOwn: isOwn,
            tab: _tab,
          ),
        );
      },
    );
  }
}

// ── Scaffold wrapper ──────────────────────────────────────────────────────────

class _SheetScaffold extends StatelessWidget {
  final Widget child;
  const _SheetScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return Container(
      height: screenH * 0.92,
      decoration: const BoxDecoration(
        color: Color(0xFF0C0C0C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: child,
    );
  }
}

// ── Full body ─────────────────────────────────────────────────────────────────

class _ProfileBody extends ConsumerWidget {
  final String anonId;
  final bool isOwn;
  final TabController tab;

  const _ProfileBody({
    required this.anonId,
    required this.isOwn,
    required this.tab,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileDataProvider(anonId));

    return Column(
      children: [
        // Drag handle
        const SizedBox(height: 12),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFF3A3A3A),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 20),

        // Header
        profileAsync.when(
          loading: () => const _HeaderShimmer(),
          error: (_, __) => const _ErrorBody(),
          data: (profile) {
            if (profile == null) return const _ErrorBody();
            return _ProfileHeader(
              profile: profile,
              isOwn: isOwn,
            );
          },
        ),

        const SizedBox(height: 16),
        Container(height: 0.5, color: const Color(0xFF1A1A1A)),

        // Tab bar
        _ProfileTabBar(tab: tab, isOwn: isOwn),
        Container(height: 0.5, color: const Color(0xFF1A1A1A)),

        // Tab content
        Expanded(
          child: TabBarView(
            controller: tab,
            children: [
              _SpillsTab(anonId: anonId),
              _TeaTab(anonId: anonId),
              _LikedTab(anonId: anonId),
            ],
          ),
        ),

        // Settings footer — own profile only
        if (isOwn) ...[
          Container(height: 0.5, color: const Color(0xFF1A1A1A)),
          _SettingsFooter(),
        ],
        SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
      ],
    );
  }
}

// ── Profile header ────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final ProfileData profile;
  final bool isOwn;

  const _ProfileHeader({required this.profile, required this.isOwn});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile.avatarConfig.isNotEmpty
        ? AvatarConfig.fromMap(profile.avatarConfig).buildUrl(size: 160)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.accentPrimary.withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: ClipOval(
              child: avatarUrl != null
                  ? CachedNetworkImage(
                imageUrl: avatarUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: const Color(0xFF1A1A1A)),
                errorWidget: (_, __, ___) => const _AnonAvatar(),
              )
                  : const _AnonAvatar(),
            ),
          ),
          const SizedBox(width: 16),

          // Name + id
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@${profile.username}',
                  style: AppTypography.bodyMedium.copyWith(
                    fontFamily: 'DM Sans',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  onLongPress: () {
                    Clipboard.setData(ClipboardData(text: profile.anonId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Anon ID copied'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Text(
                    profile.anonId.length > 16
                        ? '${profile.anonId.substring(0, 16)}…'
                        : profile.anonId,
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 11,
                      color: AppColors.hintText,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnonAvatar extends StatelessWidget {
  const _AnonAvatar();
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFF1A1A1A),
    child: const Icon(LucideIcons.user, size: 28, color: AppColors.hintText),
  );
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final ProfileData profile;

  const _StatsRow({required this.profile});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _StatCell(label: 'Posts', value: profile.totalPostCount),
        const SizedBox(width: 28),
        _StatCell(label: 'Likes', value: profile.totalLikeCount),
        const SizedBox(width: 28),
        _StatCell(label: 'Comments', value: profile.totalCommentCount),
      ],
    ),
  );
}

class _StatCell extends StatelessWidget {
  final String label;
  final int value;

  const _StatCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        _fmt(value),
        style: AppTypography.bodyMedium.copyWith(
          fontFamily: 'DM Sans',
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          fontFeatures: [const FontFeature.tabularFigures()],
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

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

// ── Tab bar ───────────────────────────────────────────────────────────────────

class _ProfileTabBar extends StatelessWidget {
  final TabController tab;
  final bool isOwn;

  const _ProfileTabBar({required this.tab, required this.isOwn});

  @override
  Widget build(BuildContext context) => TabBar(
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
      Tab(text: 'Liked'),
    ],
  );
}

// ── Spills tab ────────────────────────────────────────────────────────────────

class _SpillsTab extends ConsumerWidget {
  final String anonId;
  const _SpillsTab({required this.anonId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mySpillsProvider(anonId));
    return async.when(
      loading: () => _shimmerList(),
      error: (_, __) => _emptyState('Could not load spills.'),
      data: (feed) {
        if (feed.isLoading) return _shimmerList();
        if (feed.posts.isEmpty) {
          return _emptyState('No spills yet.');
        }
        return ListView.builder(
          itemCount: feed.posts.length + (feed.isLoadingMore ? 1 : 0),
          itemBuilder: (ctx, i) {
            if (i == feed.posts.length) return _loadMore();
            final post = feed.posts[i];
            return ConfessionCard(
              key: ValueKey(post.postId),
              post: post,
              currentAnonId: anonId,
              onTap: () => Navigator.of(ctx).push(
                postDetailHeroRoute(post.postId, initialPost: post),
              ),
              onLike: () =>
                  ref.read(mySpillsProvider(anonId).notifier).loadMore(),
            );
          },
        );
      },
    );
  }
}

// ── Tea tab ───────────────────────────────────────────────────────────────────

class _TeaTab extends ConsumerWidget {
  final String anonId;
  const _TeaTab({required this.anonId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myTeaProvider(anonId));
    return async.when(
      loading: () => _shimmerList(),
      error: (_, __) => _emptyState('Could not load tea.'),
      data: (feed) {
        if (feed.isLoading) return _shimmerList();
        if (feed.posts.isEmpty) {
          return _emptyState('No tea yet.');
        }
        return ListView.builder(
          itemCount: feed.posts.length,
          itemBuilder: (ctx, i) {
            final post = feed.posts[i];
            return ConfessionCard(
              key: ValueKey(post.postId),
              post: post,
              currentAnonId: anonId,
              onTap: () => Navigator.of(ctx).push(
                postDetailHeroRoute(post.postId, initialPost: post),
              ),
              onLike: () {},
            );
          },
        );
      },
    );
  }
}

// ── Liked tab ─────────────────────────────────────────────────────────────────

class _LikedTab extends ConsumerWidget {
  final String anonId;
  const _LikedTab({required this.anonId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myLikedProvider(anonId));
    return async.when(
      loading: () => _shimmerList(),
      error: (_, __) => _emptyState('Could not load liked posts.'),
      data: (feed) {
        if (feed.isLoading) return _shimmerList();
        if (feed.posts.isEmpty) {
          return _emptyState('Nothing liked yet.');
        }
        return ListView.builder(
          itemCount: feed.posts.length,
          itemBuilder: (ctx, i) {
            final post = feed.posts[i];
            return ConfessionCard(
              key: ValueKey(post.postId),
              post: post,
              currentAnonId: anonId,
              onTap: () => Navigator.of(ctx).push(
                postDetailHeroRoute(post.postId, initialPost: post),
              ),
              onLike: () {},
            );
          },
        );
      },
    );
  }
}

// ── Settings footer ───────────────────────────────────────────────────────────

class _SettingsFooter extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          _SettingsRow(
            icon: LucideIcons.bell,
            label: 'Notifications',
            onTap: () {},
            trailing: Text(
              'Coming soon',
              style: AppTypography.bodySmall.copyWith(
                fontSize: 11,
                color: AppColors.hintText,
              ),
            ),
          ),
          _SettingsRow(
            icon: LucideIcons.shieldOff,
            label: 'Blocked Users',
            onTap: () {},
            trailing: Text(
              'Coming soon',
              style: AppTypography.bodySmall.copyWith(
                fontSize: 11,
                color: AppColors.hintText,
              ),
            ),
          ),
          _SettingsRow(
            icon: LucideIcons.logOut,
            label: 'Sign Out',
            labelColor: AppColors.errorLight,
            onTap: () async {
              Navigator.of(context).pop();
              final signOut = ref.read(signOutProvider);
              await signOut();
            },
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? labelColor;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.labelColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      HapticFeedback.selectionClick();
      onTap();
    },
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: labelColor ?? AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                fontSize: 14,
                color: labelColor ?? AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    ),
  );
}

// ── Shared helpers ────────────────────────────────────────────────────────────

Widget _shimmerList() => ListView.builder(
  physics: const NeverScrollableScrollPhysics(),
  itemCount: 4,
  itemBuilder: (_, __) => const ConfessionShimmerCard(),
);

Widget _emptyState(String msg) => Center(
  child: Text(
    msg,
    style: const TextStyle(
      fontSize: 14,
      color: AppColors.textSecondary,
    ),
  ),
);

Widget _loadMore() => const Padding(
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

// ── Shimmer header ────────────────────────────────────────────────────────────

class _HeaderShimmer extends StatefulWidget {
  const _HeaderShimmer();

  @override
  State<_HeaderShimmer> createState() => _HeaderShimmerState();
}

class _HeaderShimmerState extends State<_HeaderShimmer>
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
    builder: (_, __) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _Bone(w: 64, h: 64, radius: 32, anim: _anim),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Bone(w: 120, h: 16, radius: 4, anim: _anim),
              const SizedBox(height: 6),
              _Bone(w: 80, h: 11, radius: 4, anim: _anim),
            ],
          ),
        ],
      ),
    ),
  );
}

class _Bone extends StatelessWidget {
  final double w, h, radius;
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

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();
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

class _ErrorBody extends StatelessWidget {
  const _ErrorBody();
  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      'Could not load profile.',
      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
    ),
  );
}
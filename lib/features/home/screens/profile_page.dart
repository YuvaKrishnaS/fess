import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/models/avatar_config.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../home/post_detail/post_detail_screen.dart';
import '../providers/feed_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/confession_card.dart';

// ── Entry ─────────────────────────────────────────────────────────────────────

class ProfilePage extends ConsumerStatefulWidget {
  final String anonId;
  final int initialTab; // 0=Spills 1=Tea 2=Liked 3=Settings

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
  late bool _isOwn;

  @override
  void initState() {
    super.initState();
    // settings tab shown as tab index 3 but it's rendered outside tabview
    _tab = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab < 3 ? widget.initialTab : 0,
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
      error: (_, __) => const _PageScaffold(
          child: _PageError(msg: 'Could not determine identity.')),
      data: (myId) {
        _isOwn = widget.anonId == myId || myId == null;
        return _ProfilePageBody(
          anonId: widget.anonId,
          isOwn: _isOwn,
          tab: _tab,
          initialTab: widget.initialTab,
        );
      },
    );
  }
}

// ── Page scaffold ─────────────────────────────────────────────────────────────

class _PageScaffold extends StatelessWidget {
  final Widget child;
  const _PageScaffold({required this.child});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.backgroundMain,
    body: child
  );
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _ProfilePageBody extends ConsumerWidget {
  final String anonId;
  final bool isOwn;
  final TabController tab;
  final int initialTab;

  const _ProfilePageBody({
    required this.anonId,
    required this.isOwn,
    required this.tab,
    required this.initialTab,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileDataProvider(anonId));

    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, innerScrolled) => [
          SliverToBoxAdapter(
            child: Column(
              children: [
                // ── App bar ──────────────────────────────────────────────
                _ProfileAppBar(anonId: anonId, isOwn: isOwn),

                // ── Header ───────────────────────────────────────────────
                profileAsync.when(
                  loading: () => const _FullHeaderShimmer(),
                  error: (_, __) => const _PageError(
                      msg: 'Could not load profile.'),
                  data: (profile) {
                    if (profile == null) {
                      return const _PageError(
                          msg: 'Profile not found.');
                    }
                    return _FullProfileHeader(
                        profile: profile, isOwn: isOwn);
                  },
                ),

                const SizedBox(height: 4),
              ],
            ),
          ),

          // Sticy TaB BAR
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
                  const Tab(text: 'Liked'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: tab,
          children: [
            _SpillsTab(anonId: anonId),
            _TeaTab(anonId: anonId),
            _LikedTab(anonId: anonId),
          ],
        ),
      ),
      // Settings shown as bottom sheet on the page itself (for own profile)
    );
  }
}

// App Bar

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
          // Back
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
                _showSettingsSheet(context, ref);
              },
            ),
        ],
      ),
    );
  }

  void _showSettingsSheet(BuildContext ctx, WidgetRef ref) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SettingsSheet(ref: ref),
    );
  }
}

// Full Profile Header

class _FullProfileHeader extends StatelessWidget {
  final ProfileData profile;
  final bool isOwn;
  const _FullProfileHeader(
      {required this.profile, required this.isOwn});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile.avatarConfig.isNotEmpty
        ? AvatarConfig.fromMap(profile.avatarConfig).buildUrl(size: 200)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + edit button row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
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
            ],
          ),

          const SizedBox(height: 14),

          Text(
            '@${profile.username}',
            style: AppTypography.h2.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 4),

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
              '#${profile.anonId}',
              style: AppTypography.bodySmall.copyWith(
                fontSize: 11,
                color: AppColors.hintText,
                fontFamily: 'monospace',
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Stats
          Row(
            children: [
              _StatBlock(
                  label: 'Spills', value: profile.totalPostCount),
              const SizedBox(width: 28),
              _StatBlock(
                  label: 'Likes Received',
                  value: profile.totalLikeCount),
              const SizedBox(width: 28),
              _StatBlock(
                  label: 'Replies', value: profile.totalCommentCount),
            ],
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        _fmt(value),
        style: AppTypography.bodyMedium.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w900,
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
}

class _AnonAvatarLg extends StatelessWidget {
  const _AnonAvatarLg();
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFF1A1A1A),
    child: const Icon(LucideIcons.user,
        size: 36, color: AppColors.hintText),
  );
}

// Sticky tab bar delegate

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

// Content tabs

class _SpillsTab extends ConsumerWidget {
  final String anonId;
  const _SpillsTab({required this.anonId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mySpillsProvider(anonId));
    return async.when(
      loading: _shimmerList,
      error: (_, __) => _emptyState('Could not load spills.', isError: true),
      data: (feed) {
        if (feed.isLoading) return _shimmerList();
        if (feed.posts.isEmpty) {
          return _emptyState(
              'No spills yet.\nWhen you spill, they show up here.');
        }
        return ListView.builder(
          itemCount: feed.posts.length +
              (feed.hasMore ? 1 : 1), // +1 for easter egg
          itemBuilder: (ctx, i) {
            if (i == feed.posts.length) {
              return feed.isLoadingMore
                  ? _loadMoreSpinner()
                  : _EasterEgg();
            }
            final post = feed.posts[i];
            return ConfessionCard(
              key: ValueKey(post.postId),
              post: post,
              currentAnonId: anonId,
              onTap: () => Navigator.of(ctx).push(
                  postDetailHeroRoute(post.postId, initialPost: post)),
              onLike: () =>
                  ref.read(mySpillsProvider(anonId).notifier).loadMore(),
            );
          },
        );
      },
    );
  }
}

class _TeaTab extends ConsumerWidget {
  final String anonId;
  const _TeaTab({required this.anonId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myTeaProvider(anonId));
    return async.when(
      loading: _shimmerList,
      error: (_, __) => _emptyState('Could not load tea.', isError: true),
      data: (feed) {
        if (feed.isLoading) return _shimmerList();
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
              currentAnonId: anonId,
              onTap: () => Navigator.of(ctx).push(
                  postDetailHeroRoute(post.postId, initialPost: post)),
              onLike: () =>
                  ref.read(myTeaProvider(anonId).notifier).loadMore(),
            );
          },
        );
      },
    );
  }
}

class _LikedTab extends ConsumerWidget {
  final String anonId;
  const _LikedTab({required this.anonId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myLikedProvider(anonId));
    return async.when(
      loading: _shimmerList,
      error: (_, __) =>
          _emptyState('Could not load liked posts.', isError: true),
      data: (feed) {
        if (feed.isLoading) return _shimmerList();
        if (feed.posts.isEmpty) {
          return _emptyState(
              'Nothing liked yet.\nHeart posts that hit different.');
        }
        return ListView.builder(
          itemCount: feed.posts.length + 1,
          itemBuilder: (ctx, i) {
            if (i == feed.posts.length) return _EasterEgg();
            final post = feed.posts[i];
            return ConfessionCard(
              key: ValueKey(post.postId),
              post: post,
              currentAnonId: anonId,
              onTap: () => Navigator.of(ctx).push(
                  postDetailHeroRoute(post.postId, initialPost: post)),
              onLike: () {},
            );
          },
        );
      },
    );
  }
}

// Easter Egg

class _EasterEgg extends StatefulWidget {
  @override
  State<_EasterEgg> createState() => _EasterEggState();
}

class _EasterEggState extends State<_EasterEgg>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo
              Opacity(
                opacity: 0.25,
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 48,
                  height: 48,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "There's nothing here to discover more, bruhh !!",
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
        ),
      ),
    );
  }
}

// Settings Bottom sheet

class _SettingsSheet extends ConsumerWidget {
  final WidgetRef ref;
  const _SettingsSheet({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0E0E0E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(0, 12, 0, bottomPad + 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Section: Account
          _SettingsSection(label: 'Account'),
          _SettingsItem(
            icon: LucideIcons.userCircle,
            label: 'Edit Persona',
            subtitle: 'Change your username or avatar',
            onTap: () {
              Navigator.of(context).pop();
              context.push('/avatar-builder');
            },
          ),
          _SettingsItem(
            icon: LucideIcons.copy,
            label: 'Copy Anon ID',
            subtitle: 'Share your anonymous identity',
            onTap: () async {
              final anonId = await ref
                  .read(currentAnonIdProvider.future);
              if (anonId != null) {
                Clipboard.setData(ClipboardData(text: anonId));
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Anon ID copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
          ),

          const SizedBox(height: 8),
          _SettingsSection(label: 'Privacy & Safety'),
          _SettingsItem(
            icon: LucideIcons.shieldOff,
            label: 'Blocked Users',
            subtitle: 'Manage who can\'t see your posts',
            badge: 'Soon',
            onTap: () {},
          ),
          _SettingsItem(
            icon: LucideIcons.lock,
            label: 'Privacy Settings',
            subtitle: 'Control your visibility',
            badge: 'Soon',
            onTap: () {},
          ),

          const SizedBox(height: 8),
          _SettingsSection(label: 'Notifications'),
          _SettingsItem(
            icon: LucideIcons.bell,
            label: 'Push Notifications',
            subtitle: 'Likes, comments & replies',
            badge: 'Soon',
            onTap: () {},
          ),

          const SizedBox(height: 8),
          _SettingsSection(label: 'Support'),
          _SettingsItem(
            icon: LucideIcons.mailQuestion,
            label: 'Help & Feedback',
            subtitle: 'Report bugs or ask questions',
            onTap: () {},
          ),
          _SettingsItem(
            icon: LucideIcons.fileText,
            label: 'Privacy Policy',
            onTap: () {},
          ),
          _SettingsItem(
            icon: LucideIcons.scrollText,
            label: 'Terms of Service',
            onTap: () {},
          ),

          const SizedBox(height: 16),

          // Danger zone
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.errorLight.withOpacity(0.15)),
            ),
            child: Column(
              children: [
                _SettingsItem(
                  icon: LucideIcons.logOut,
                  label: 'Sign Out',
                  labelColor: AppColors.errorLight,
                  iconColor: AppColors.errorLight,
                  onTap: () async {
                    Navigator.of(context).pop();
                    final confirmed = await AppDialog.show(
                      context,
                      title: 'Sign out?',
                      body:
                      'You\'ll be signed out of your anonymous persona. Your posts and spills stay.',
                      confirmLabel: 'Sign Out',
                      cancelLabel: 'Stay',
                      isDestructive: true,
                    );
                    if (confirmed && context.mounted) {
                      final signOut = ref.read(signOutProvider);
                      await signOut();
                      if (context.mounted) context.go('/auth/login');
                    }
                  },
                ),
                Container(
                    height: 1,
                    color: AppColors.errorLight.withOpacity(0.1)),
                _SettingsItem(
                  icon: LucideIcons.trash2,
                  label: 'Delete Account',
                  subtitle:
                  'Permanently erase all your data',
                  labelColor: AppColors.errorLight,
                  iconColor: AppColors.errorLight,
                  onTap: () async {
                    final confirmed = await AppDialog.show(
                      context,
                      title: 'Delete account?',
                      body:
                      'This permanently deletes your persona, all spills, and all your data. This cannot be undone.',
                      confirmLabel: 'Delete Forever',
                      cancelLabel: 'Keep Account',
                      isDestructive: true,
                    );
                    if (confirmed) {
                      // TODO: implement account deletion
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // App version
          Text(
            'Fess v2.0.0 • Everything stays anon.',
            style: AppTypography.bodySmall.copyWith(
              fontSize: 13,
              color: const Color(0xFF2A2A2A),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String label;
  const _SettingsSection({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label.toUpperCase(),
        style: AppTypography.bodySmall.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 1.1
        )
      )
    )
  );
}

class _SettingsItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final String? badge;
  final VoidCallback onTap;
  final Color? labelColor;
  final Color? iconColor;

  const _SettingsItem({
    required this.icon,
    required this.label,
    this.subtitle,
    this.badge,
    required this.onTap,
    this.labelColor,
    this.iconColor,
  });

  @override
  State<_SettingsItem> createState() => _SettingsItemState();
}

class _SettingsItemState extends State<_SettingsItem> {
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
        color: _pressed ? const Color(0xFF181818) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            Icon(widget.icon,
                size: 18,
                color: widget.iconColor ?? AppColors.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: AppTypography.bodyMedium.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: widget.labelColor ?? AppColors.textPrimary,
                    ),
                  ),
                  if (widget.subtitle != null)
                    Text(
                      widget.subtitle!,
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (widget.badge != null)
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: AppColors.accentPrimary.withOpacity(0.2)),
                ),
                child: Text(
                  widget.badge!,
                  style: AppTypography.labelMedium.copyWith(
                    fontSize: 10,
                    color: AppColors.accentPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else if (widget.labelColor == null)
              Icon(LucideIcons.chevronRight,
                  size: 14, color: AppColors.hintText),
          ],
        ),
      ),
    );
  }
}

// Helpers

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
      ),
    ),
  ),
);

Widget _loadMoreSpinner() => const Padding(
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

class _CenteredSpinner extends StatelessWidget {
  const _CenteredSpinner();
  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 1.5,
        color: AppColors.textSecondary
      )
    )
  );
}

class _PageError extends StatelessWidget {
  final String msg;
  const _PageError({required this.msg});
  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      msg,
      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),

    )
  );
}

class _FullHeaderShimmer extends StatefulWidget {
  const _FullHeaderShimmer();
  @override
  State<_FullHeaderShimmer> createState() => _FullHeaderShimmerState();
}

class _FullHeaderShimmerState extends State<_FullHeaderShimmer>
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
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Bone(w: 80, h: 80, radius: 40, anim: _anim),
            const SizedBox(height: 14),
            _Bone(w: 160, h: 20, radius: 5, anim: _anim),
            const SizedBox(height: 6),
            _Bone(w: 110, h: 11, radius: 5, anim: _anim),
            const SizedBox(height: 20),
            Row(
              children: [
                _Bone(w: 50, h: 36, radius: 5, anim: _anim),
                const SizedBox(width: 28),
                _Bone(w: 50, h: 36, radius: 5, anim: _anim),
                const SizedBox(width: 28),
                _Bone(w: 50, h: 36, radius: 5, anim: _anim),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
        colors: const [
          Color(0xFF1A1A1A),
          Color(0xFF252525),
          Color(0xFF1A1A1A),
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
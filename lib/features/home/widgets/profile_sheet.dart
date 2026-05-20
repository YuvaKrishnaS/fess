import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/models/avatar_config.dart';
import '../../../core/widgets/app_dialog.dart';
import '../providers/feed_provider.dart';
import '../providers/profile_provider.dart' hide currentAnonIdProvider;

// ENTRY POINT :))))))))

/// Opens the left-slide profile drawer. Call from any avatar/profile tap.
void showProfileDrawer(BuildContext context, {String? anonId}) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => _ProfileDrawerOverlay(anonId: anonId),
      transitionsBuilder: (_, anim, __, child) => child,
    ),
  );
}

// OVERLAY

class _ProfileDrawerOverlay extends ConsumerStatefulWidget {
  final String? anonId;
  const _ProfileDrawerOverlay({this.anonId});

  @override
  ConsumerState<_ProfileDrawerOverlay> createState() =>
      _ProfileDrawerOverlayState();
}

class _ProfileDrawerOverlayState extends ConsumerState<_ProfileDrawerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scrimOpacity;
  late final Animation<Offset> _drawerOffset;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 230),
    );

    _scrimOpacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    _drawerOffset = Tween<Offset>(
      begin: const Offset(-1.0, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _controller.forward();
  }

  Future<void> closeDrawer() async {
    if (_isClosing) return;
    _isClosing = true;
    await _controller.reverse();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: closeDrawer,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          FadeTransition(                                   // FIX 1: was FadetransitionS
            opacity: _scrimOpacity,
            child: Container(color: Colors.black.withOpacity(0.55)),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: SlideTransition(
              position: _drawerOffset,
              child: GestureDetector(
                onHorizontalDragUpdate: (details) {
                  if (details.delta.dx < -8) {
                    closeDrawer();
                  }
                },
                onTap: () {},
                child: _ProfileDrawerContent(             // FIX 2: was _profileDrawerContent
                  anonId: widget.anonId,
                  onClose: closeDrawer,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Scrim extends StatefulWidget {
  @override
  State<_Scrim> createState() => _ScrimState();
}

class _ScrimState extends State<_Scrim> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(color: Colors.black.withOpacity(0.55)),
    );
  }
}

// DRAWER

class _ProfileDrawerContent extends ConsumerWidget {
  final String? anonId;
  final Future<void> Function() onClose;

  const _ProfileDrawerContent({
    required this.anonId,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myIdAsync = ref.watch(currentAnonIdProvider);
    final screenW = MediaQuery.of(context).size.width;

    return Container(
      width: screenW * 0.78,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF0C0C0C),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 32,
            offset: Offset(8, 0),
          ),
        ],
      ),
      child: myIdAsync.when(
        loading: () => const _DrawerLoadingState(),
        error: (_, __) => const _DrawerErrorState(),
        data: (myId) {
          final resolvedId = anonId ?? myId;
          final isOwn = resolvedId == myId || anonId == null;

          if (resolvedId == null) return const _DrawerErrorState();

          return _DrawerContent(
            anonId: resolvedId,
            isOwn: isOwn,
            onClose: onClose,
          );
        },
      ),
    );
  }
}

// FIX 3: removed dead _ProfileDrawerState / _ProfileDrawer orphan block entirely

// DRAWER CONTENT

class _DrawerContent extends ConsumerWidget {
  final String anonId;
  final bool isOwn;
  final Future<void> Function() onClose;

  const _DrawerContent({
    required this.anonId,
    required this.isOwn,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileDataProvider(anonId));
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: topPad + 16),

        // FESS LOGO + CLOSE
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _FessLogo(),
              const Spacer(),
              GestureDetector(
                onTap: () => onClose(),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    LucideIcons.x,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // PROFILE HEADER
        profileAsync.when(
          loading: () => const _DrawerHeaderShimmer(),
          error: (_, __) => const _DrawerErrorState(),
          data: (profile) {
            if (profile == null) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: _DrawerErrorState(),
              );
            }
            return _DrawerHeader(profile: profile);
          },
        ),

        const SizedBox(height: 24),

        // Divider
        Container(
          height: 1,
          color: const Color(0xFF1A1A1A),
          margin: const EdgeInsets.symmetric(horizontal: 20),
        ),

        const SizedBox(height: 16),

        // QUICK NAV
        _DrawerNavItem(
          icon: LucideIcons.layoutGrid,
          label: 'View Full Profile',
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).pop();
            context.push('/profile/$anonId');
          },
          isHighlight: true,
        ),
        _DrawerNavItem(
          icon: LucideIcons.messageSquare,
          label: 'My Spills',
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).pop();
            context.push('/profile/$anonId?tab=0');
          },
        ),
        _DrawerNavItem(
          icon: LucideIcons.coffee,
          label: 'My Tea',
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).pop();
            context.push('/profile/$anonId?tab=1');
          },
        ),
        _DrawerNavItem(
          icon: LucideIcons.heart,
          label: 'Liked',
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).pop();
            context.push('/profile/$anonId?tab=2');
          },
        ),

        const SizedBox(height: 16),
        Container(
          height: 1,
          color: const Color(0xFF1A1A1A),
          margin: const EdgeInsets.symmetric(horizontal: 20),
        ),
        const SizedBox(height: 8),

        // SETTINGS SECTION
        if (isOwn) ...[
          _DrawerNavItem(
            icon: LucideIcons.settings,
            label: 'Settings',
            onTap: () async {
              HapticFeedback.selectionClick();
              await onClose();
              if (context.mounted) context.push('/settings/profile');
            },
          ),
          _DrawerNavItem(
            icon: LucideIcons.logOut,
            label: 'Sign Out',
            labelColor: AppColors.errorLight,
            iconColor: AppColors.errorLight,
            onTap: () async {
              final confirmed = await AppDialog.show(
                context,
                title: 'Sign out?',
                body: 'You\'ll be signed out of your anonymous persona.',
                confirmLabel: 'Sign Out',
                cancelLabel: 'Stay',
                isDestructive: true,
              );

              if (!confirmed || !context.mounted) return;

              await onClose();

              final signOut = ref.read(signOutProvider);
              await signOut();

              if (context.mounted) {
                context.go('/auth/login');
              }
            },
          ),
        ],

        const Spacer(),

        // Bottom version tag
        Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPad + 20),
          child: Text(
            'Fess v2 • Everything stays anon.',
            style: AppTypography.bodySmall.copyWith(
              fontSize: 13,
              color: const Color(0xFF2A2A2A),
            ),
          ),
        ),
      ],
    );
  }
}

// DRAWER HEADER

class _DrawerHeader extends StatelessWidget {
  final ProfileData profile;
  const _DrawerHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile.avatarConfig.isNotEmpty
        ? AvatarConfig.fromMap(profile.avatarConfig).buildUrl(size: 120)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.accentPrimary.withOpacity(0.35),
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

          const SizedBox(height: 12),

          Text(
            '@${profile.username}',
            style: AppTypography.bodyMedium.copyWith(
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
              profile.anonId.length > 14
                  ? '#${profile.anonId.substring(0, 14)}…'
                  : '#${profile.anonId}',
              style: AppTypography.bodySmall.copyWith(
                fontSize: 11,
                color: AppColors.hintText,
                fontFamily: 'monospace',
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              _MiniStat(value: profile.totalPostCount, label: 'Posts'),
              const SizedBox(width: 20),
              _MiniStat(value: profile.totalLikeCount, label: 'Likes'),
              const SizedBox(width: 20),
              _MiniStat(value: profile.totalCommentCount, label: 'Replies'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final int value;
  final String label;
  const _MiniStat({required this.value, required this.label});

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
            fontSize: 15,
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
  }
}

// DRAWER NAV ITEM

class _DrawerNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isHighlight;
  final Color? labelColor;
  final Color? iconColor;

  const _DrawerNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isHighlight = false,
    this.labelColor,
    this.iconColor,
  });

  @override
  State<_DrawerNavItem> createState() => _DrawerNavItemState();
}

class _DrawerNavItemState extends State<_DrawerNavItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final fg = widget.labelColor ??
        (widget.isHighlight ? AppColors.accentPrimary : AppColors.textPrimary);
    final iconFg = widget.iconColor ??
        (widget.isHighlight
            ? AppColors.accentPrimary
            : AppColors.textSecondary);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: _pressed ? const Color(0xFF1A1A1A) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(widget.icon, size: 18, color: iconFg),
            const SizedBox(width: 14),
            Text(
              widget.label,
              style: AppTypography.bodyMedium.copyWith(
                fontSize: 15,
                fontWeight:
                widget.isHighlight ? FontWeight.w700 : FontWeight.w500,
                color: fg,
              ),
            ),
            if (widget.isHighlight) ...[
              const Spacer(),
              Icon(
                LucideIcons.arrowRight,
                size: 14,
                color: AppColors.accentPrimary.withOpacity(0.6),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// FESS LOGO SVG INLINE
class _FessLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          'assets/images/logo.png',
          width: 28,
          height: 28,
        ),
        const SizedBox(width: 8),
        Text(
          'Fess',
          style: AppTypography.h3.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

// HELPERS

class _AnonAvatar extends StatelessWidget {
  const _AnonAvatar();
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFF1A1A1A),
    child: const Icon(LucideIcons.user, size: 24, color: AppColors.hintText),
  );
}

class _DrawerLoadingState extends StatelessWidget {
  const _DrawerLoadingState();
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

class _DrawerErrorState extends StatelessWidget {
  const _DrawerErrorState();
  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      'Could not load.',
      style: AppTypography.bodySmall
          .copyWith(color: AppColors.textSecondary),
    ),
  );
}

class _DrawerHeaderShimmer extends StatefulWidget {
  const _DrawerHeaderShimmer();
  @override
  State<_DrawerHeaderShimmer> createState() => _DrawerHeaderShimmerState();
}

class _DrawerHeaderShimmerState extends State<_DrawerHeaderShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
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
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Bone(w: 60, h: 60, radius: 30, anim: _anim),
            const SizedBox(height: 12),
            _Bone(w: 130, h: 16, radius: 5, anim: _anim),
            const SizedBox(height: 6),
            _Bone(w: 90, h: 11, radius: 5, anim: _anim),
          ],
        ),
      ),
    );
  }
}

class _Bone extends StatelessWidget {
  final double w, h, radius;
  final Animation<double> anim;
  const _Bone({
    required this.w,
    required this.h,
    required this.radius,
    required this.anim,
  });

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
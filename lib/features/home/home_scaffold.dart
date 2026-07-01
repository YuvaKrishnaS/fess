import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/avatar_config.dart';
import '../../core/models/dm_model.dart';
import '../../core/services/local_storage_service.dart';
import '../../core/widgets/dm_notification_overlay.dart';
import '../../core/widgets/fess_snackbar.dart';
import 'feed/feed_screen.dart';
import 'providers/dm_provider.dart';
import 'providers/scroll_visibility_provider.dart';
import 'screens/dm_inbox_screen.dart';
import 'tea/tea_screen.dart';
import 'widgets/create_confession_sheet.dart';
import 'world/world_screen.dart';

class HomeScaffold extends ConsumerStatefulWidget {
  const HomeScaffold({super.key});

  @override
  ConsumerState<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends ConsumerState<HomeScaffold> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    FeedScreen(),
    TeaScreen(),
    WorldScreen(),
    DmInboxScreen(),
  ];

  static const List<_NavItem> _navItems = [
    _NavItem(icon: LucideIcons.home, label: 'Home'),
    _NavItem(icon: LucideIcons.coffee, label: 'Spill'),
    _NavItem(icon: LucideIcons.globe, label: 'World'),
    _NavItem(icon: LucideIcons.messageCircle, label: 'Chat'),
  ];

  void _onTab(int i) {
    if (i == _currentIndex) return;
    HapticFeedback.selectionClick();
    scrollVisibilityNotifier.value = true;
    setState(() => _currentIndex = i);
  }

  void _openCreate() {
    if (_currentIndex > 1) {
      FessSnackbar.show(context, 'Coming soon', type: SnackbarType.info);
      return;
    }
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (_) => const CreateConfessionSheet(),
    );
  }

  String? _resolveAvatarUrl(Map<String, dynamic>? profile) {
    final raw = profile?['avatarConfig'];
    if (raw == null) return null;
    try {
      return AvatarConfig.fromMap(raw as Map<String, dynamic>)
          .buildUrl(size: 76);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(dmInboxProvider);

    ref.listen(dmInboxProvider, (prev, next) {
      next.whenData((convos) {
        if (prev?.value == null) return;
        final prevConvos = prev!.value!;
        final myId = LocalStorageService.getCachedAnonId() ?? '';
        final currentOpenConvoId = ref.read(activeConversationIdProvider);

        for (final convo in convos) {
          final prevConvo = prevConvos
              .cast<DmConversation?>()
              .firstWhere((c) => c?.id == convo.id, orElse: () => null);

          final newUnread = convo.unreadFor(myId);
          final prevUnread = prevConvo?.unreadFor(myId) ?? 0;

          if (newUnread > prevUnread && convo.lastSenderId != myId) {
            if (convo.id == currentOpenConvoId) continue;

            final peerId = convo.otherParticipant(myId);
            ref.read(dmPeerProfileProvider(peerId).future).then((profile) {
              if (!mounted || !context.mounted) return;
              DmNotificationOverlay.show(
                context,
                DmNotificationPayload(
                  peerId: peerId,
                  username: profile?['username'] as String? ?? 'anon',
                  avatarUrl: _resolveAvatarUrl(profile),
                  messagePreview: convo.lastMessage ?? '',
                ),
              );
            });
          }
        }
      });
    });

    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: KeyedSubtree(
          key: ValueKey(_currentIndex),
          child: _screens[_currentIndex],
        ),
      ),
      floatingActionButton: _currentIndex <= 1
          ? ValueListenableBuilder<bool>(
        valueListenable: scrollVisibilityNotifier,
        builder: (_, visible, __) => AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, 2),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOutCubic,
          child: AnimatedOpacity(
            opacity: visible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: _Fab(onTap: _openCreate),
          ),
        ),
      )
          : null,
      bottomNavigationBar: ValueListenableBuilder<bool>(
        valueListenable: scrollVisibilityNotifier,
        builder: (_, visible, __) => AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, 1),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOutCubic,
          child: AnimatedOpacity(
            opacity: visible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: ValueListenableBuilder<int>(
              valueListenable: totalUnreadNotifier,
              builder: (_, unread, __) => _BottomNav(
                currentIndex: _currentIndex,
                items: _navItems,
                onTap: _onTab,
                totalUnread: unread,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;
  final int totalUnread;

  const _BottomNav({
    required this.currentIndex,
    required this.items,
    required this.onTap,
    required this.totalUnread,
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
      child: SafeArea(
        child: SizedBox(
          height: 52,
          child: Row(
            children: List.generate(items.length, (i) {
              final active = i == currentIndex;
              final showBadge = i == 3 && totalUnread > 0 && !active;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    height: 52,
                    child: Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedScale(
                            scale: active ? 1.12 : 1.0,
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            child: Icon(
                              items[i].icon,
                              size: 22,
                              color: active
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                          if (showBadge)
                            Positioned(
                              top: -4,
                              right: -6,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: const BoxDecoration(
                                  color: AppColors.accentPrimary,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    totalUnread > 9 ? '9+' : '$totalUnread',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _Fab extends StatefulWidget {
  final VoidCallback onTap;
  const _Fab({required this.onTap});

  @override
  State<_Fab> createState() => _FabState();
}

class _FabState extends State<_Fab> {
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
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7C4DFF), Color(0xFF1DE9B6)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C4DFF).withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Icon(LucideIcons.feather, size: 20, color: Colors.white),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 350.ms, duration: 400.ms)
        .scale(
      begin: const Offset(0.6, 0.6),
      delay: 350.ms,
      duration: 400.ms,
      curve: Curves.easeOutBack,
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import 'feed/feed_screen.dart';
import 'create/create_placeholder_screen.dart';
import 'world/world_placeholder_screen.dart';
import 'chat/chat_placeholder_screen.dart';

class HomeScaffold extends StatefulWidget {
  const HomeScaffold({super.key});

  @override
  State<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends State<HomeScaffold> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    FeedScreen(),
    CreatePlaceholderScreen(),
    WorldPlaceholderScreen(),
    ChatPlaceholderScreen(),
  ];

  // Nav items: inactive icon, active icon
  final List<_NavItemData> _navItems = const [
    _NavItemData(
      inactive: LucideIcons.home,
      active: LucideIcons.home,
      label: 'Home',
    ),
    // spill the tea page
    _NavItemData(
      inactive: LucideIcons.coffee,
      active: LucideIcons.coffee,
      label: 'Spill',
    ),
    _NavItemData(
      inactive: LucideIcons.globe,
      active: LucideIcons.globe,
      label: 'World',
    ),
    _NavItemData(
      inactive: LucideIcons.messageCircle,
      active: LucideIcons.messageCircle,
      label: 'Chat',
    ),
  ];

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: _screens[_currentIndex],
        ),
      ),

      // Floating action button — UI only, wired in M5
      floatingActionButton: _FabSpill(),

      // Custom nav bar — X.com style
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        items: _navItems,
        onTap: _onTabTapped,
      ),
    );
  }
}

// Nav item Data
class _NavItemData {
  final IconData inactive;
  final IconData active;
  final String label;

  const _NavItemData({
    required this.inactive,
    required this.active,
    required this.label,
  });
}

// Bottom Nav Bar
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final List<_NavItemData> items;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundMain,
        border: Border(
          top: BorderSide(
            color: AppColors.elevated,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 52,
          child: Row(
            children: List.generate(items.length, (i) {
              final isActive = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    height: 52,
                    child: Center(
                      child: AnimatedScale(
                        scale: isActive ? 1.15 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        child: Icon(
                          isActive ? items[i].active : items[i].inactive,
                          size: 22,
                          color: isActive
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
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


class _FabSpill extends StatefulWidget {
  @override
  State<_FabSpill> createState() => _FabSpillState();
}

class _FabSpillState extends State<_FabSpill> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        // TODO M5: context.go('/create/post')
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.accentPrimary,
            shape: BoxShape.circle,
            // Teal glow shadow — dark theme appropriate
            boxShadow: [
              BoxShadow(
                color: AppColors.accentPrimary.withOpacity(0.35),
                blurRadius: 16,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              LucideIcons.feather,
              size: 22,
              color: AppColors.backgroundMain,
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 300.ms, duration: 400.ms)
        .scale(
      begin: const Offset(0.7, 0.7),
      end: const Offset(1.0, 1.0),
      delay: 300.ms,
      duration: 400.ms,
      curve: Curves.easeOutBack,
    );
  }
}
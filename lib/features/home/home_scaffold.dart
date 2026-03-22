import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      // Fade transition between screens
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: _screens[_currentIndex],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.elevated, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          items: [
            _buildNavItem(Icons.home_outlined, Icons.home_rounded, 'Home', 0),
            _buildNavItem(Icons.add_circle_outline, Icons.add_circle, 'Spill', 1),
            _buildNavItem(Icons.public_outlined, Icons.public, 'World', 2),
            _buildNavItem(Icons.chat_bubble_outline, Icons.chat_bubble, 'Chat', 3),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(
      IconData inactive,
      IconData active,
      String label,
      int index,
      ) {
    final bool isActive = _currentIndex == index;

    return BottomNavigationBarItem(
      icon: AnimatedScale(
        scale: isActive ? 1.15 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: Icon(inactive),
      ),
      activeIcon: AnimatedScale(
        scale: isActive ? 1.15 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: Icon(active),
      ),
      label: label,
    );
  }
}
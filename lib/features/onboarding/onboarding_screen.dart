import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/services/local_storage_service.dart';
import 'widgets/onboarding_page_1.dart';
import 'widgets/onboarding_page_2.dart';
import 'widgets/onboarding_page_3.dart';
import 'widgets/onboarding_page_4.dart';
import 'package:lucide_icons/lucide_icons.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Alignment> _glowAlignments = [
    const Alignment(0.8, -0.5),
    const Alignment(-0.9, -0.3),
    const Alignment(0.0, -0.6),
    const Alignment(-0.6, -0.4),
  ];

  final List<Widget> _pages = const [
    OnboardingPage1(),
    OnboardingPage2(),
    OnboardingPage3(),
    OnboardingPage4(),
  ];

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipToEnd() {
    _pageController.animateToPage(
      _pages.length - 1,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _completeOnboarding() async {
    await LocalStorageService.setHasSeenOnboarding(true);
    if (mounted) context.go('/auth/login');
  }

  bool get _isLastPage => _currentPage == _pages.length - 1;
  bool get _isFirstPage => _currentPage == 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      body: Stack(
        children: [
          // Glow blob — bigger and more visible
          AnimatedAlign(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOut,
            alignment: _glowAlignments[_currentPage],
            child: Container(
              width: size.width * 1.1,
              height: size.width * 1.1,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accentSecondary.withOpacity(0.32),
                    AppColors.accentPrimary.withOpacity(0.10),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top bar — close LEFT, counter RIGHT
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Close icon — no background, larger
                      GestureDetector(
                        onTap: _skipToEnd,
                        child: Icon(
                          LucideIcons.x,
                          size: 22,
                          color: AppColors.textSecondary,
                        ),
                      ).animate().fadeIn(duration: 400.ms),

                      // Page counter
                      Text(
                        '${_currentPage + 1}/${_pages.length}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.hintText,
                          fontWeight: FontWeight.w500,
                        ),
                      ).animate().fadeIn(duration: 400.ms),
                    ],
                  ),
                ),

                // Pages
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    physics: const BouncingScrollPhysics(),
                    children: _pages,
                  ),
                ),

                // Bottom
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 36),
                  child: Column(
                    children: [
                      _AnimatedDots(
                        count: _pages.length,
                        current: _currentPage,
                      ),
                      const SizedBox(height: 28),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        child: _isLastPage
                            ? _AgreeButton(
                          key: const ValueKey('agree'),
                          onTap: _completeOnboarding,
                        )
                            : _SkipNextRow(
                          key: const ValueKey('skipnext'),
                          showSkip: !_isFirstPage,
                          onSkip: _skipToEnd,
                          onNext: _nextPage,
                        ),
                      ),
                    ],
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

// Dots
class _AnimatedDots extends StatelessWidget {
  final int count;
  final int current;

  const _AnimatedDots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final bool isActive = index == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 32 : 9,
          height: 9,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.accentSecondary
                : AppColors.elevated,
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }),
    );
  }
}

// Skip and Next
class _SkipNextRow extends StatelessWidget {
  final bool showSkip;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  const _SkipNextRow({
    super.key,
    required this.showSkip,
    required this.onSkip,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AnimatedOpacity(
            opacity: showSkip ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: !showSkip,
              child: TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 12),
                ),
                child: Text(
                  'Skip',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: onNext,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Next',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  LucideIcons.arrowRight,
                  size: 18,
                  color: AppColors.textPrimary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Agree and enter
class _AgreeButton extends StatefulWidget {
  final VoidCallback onTap;

  const _AgreeButton({super.key, required this.onTap});

  @override
  State<_AgreeButton> createState() => _AgreeButtonState();
}

class _AgreeButtonState extends State<_AgreeButton> {
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
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.accentPrimary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              'I Agree & Enter',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.backgroundMain,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.08, end: 0, duration: 300.ms);
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/services/local_storage_service.dart';
import 'widgets/onboarding_page_1.dart';
import 'widgets/onboarding_page_2.dart';
import 'widgets/onboarding_page_3.dart';
import 'widgets/onboarding_page_4.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

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
    } else {
      _completeOnboarding();
    }
  }

  void _skipToEnd() {
    _pageController.animateToPage(
      _pages.length - 1,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _completeOnboarding() async {
    await LocalStorageService.setHasSeenOnboarding(true);
    if (mounted) context.go('/auth/login');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isFirstPage = _currentPage == 0;
    final bool isLastPage = _currentPage == _pages.length - 1;
    final bool canSkip = !isFirstPage && !isLastPage;

    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo with fade-in
                  Image.asset(
                    'assets/images/logo.png',
                    width: 32,
                    height: 32,
                  )
                      .animate()
                      .fadeIn(duration: 500.ms),

                  // Skip button — only on middle pages
                  AnimatedOpacity(
                    opacity: canSkip ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: IgnorePointer(
                      ignoring: !canSkip,
                      child: TextButton(
                        onPressed: _skipToEnd,
                        child: Text(
                          'Skip',
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
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

            // Bottom section
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
              child: Column(
                children: [
                  // Animated dots
                  _AnimatedDots(
                    count: _pages.length,
                    current: _currentPage,
                  ),

                  const SizedBox(height: 28),

                  // Action button
                  CustomButton(
                    text: isFirstPage
                        ? 'I Agree & Enter'
                        : isLastPage
                        ? "Let's start"
                        : 'Next',
                    onPressed: _nextPage,
                    icon: isLastPage ? Icons.arrow_forward : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Animated dots ────────────────────────────────────────────────────────────
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
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.accentPrimary
                : AppColors.elevated,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
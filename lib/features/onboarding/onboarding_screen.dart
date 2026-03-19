import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
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
    setState(() {
      _currentPage = page;
    });
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skipToEnd() {
    _pageController.animateToPage(
      _pages.length - 1,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _completeOnboarding() async {
    await LocalStorageService.setHasSeenOnboarding(true);
    if (mounted) {
      context.go('/auth/login');
    }
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
    final bool canSkip = _currentPage > 0 && _currentPage < _pages.length - 1;

    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with logo and skip
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    width: 32,
                    height: 32,
                  ),
                  if (canSkip)
                    TextButton(
                      onPressed: _skipToEnd,
                      child: const Text('Skip'),
                    )
                  else
                    const SizedBox(width: 60),
                ],
              ),
            ),

            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: _pages,
              ),
            ),

            // Bottom section: dots + button
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  // Page indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                          (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 32 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? AppColors.accentPrimary
                              : AppColors.elevated,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

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

import 'package:flutter/material.dart';
import 'onboarding_base.dart';

class OnboardingPage1 extends StatelessWidget {
  const OnboardingPage1({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingBase(
      imagePath: 'assets/images/onboarding/Onboarding-1.png',
      title: 'Welcome to Fess',
      highlightWord: 'Fess',
      body: 'A safe space for honest stories, hidden feelings, and real connections. We value vulnerability over vanity. You are anonymous here, but you are never alone.',
      enableFloat: true,
    );
  }
}
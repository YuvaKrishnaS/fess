import 'package:flutter/material.dart';
import 'onboarding_base.dart';

class OnboardingPage4 extends StatelessWidget {
  const OnboardingPage4({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingBase(
      imagePath: 'assets/images/onboarding/Onboarding-4.png',
      title: 'You Have the Power',
      highlightWord: 'Power',
      body: 'Anonymity is a responsibility. Own your posts and report toxicity if you see it. By entering, you agree to keep Fess safe for everyone.',
      enableFloat: true,
    );
  }
}
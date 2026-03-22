import 'package:flutter/material.dart';
import 'onboarding_base.dart';

class OnboardingPage3 extends StatelessWidget {
  const OnboardingPage3({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingBase(
      imagePath: 'assets/images/onboarding/Onboarding-3.png',
      title: 'Respect is Everything',
      highlightWord: 'Everything',
      body: 'Share authentically, but never bully or discriminate. Hate speech, insults, and threats have no place here. We are here to support, not to hurt.',
    );
  }
}
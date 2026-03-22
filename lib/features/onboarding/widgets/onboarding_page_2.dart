import 'package:flutter/material.dart';
import 'onboarding_base.dart';

class OnboardingPage2 extends StatelessWidget {
  const OnboardingPage2({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingBase(
      imagePath: 'assets/images/onboarding/Onboarding-2.png',
      title: 'Keep It Safe & Clean',
      highlightWord: 'Safe',
      body: 'No graphic violence, nudity, or illegal content. Keep shares emotional, not explicit. We strictly prohibit content that harms minors or promotes self-harm.',
    );
  }
}
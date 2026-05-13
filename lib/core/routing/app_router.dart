import 'package:fessv2/features/home/post_detail/post_detail_screen.dart';
import 'package:fessv2/features/persona/persona_creation_screen.dart';
import 'package:go_router/go_router.dart';
import '../../features/persona/avatar_builder_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/home/home_scaffold.dart';
import '../models/post_model.dart';
import 'package:flutter/material.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScaffold(),
      ),
      GoRoute(
        path: '/persona/create',
        builder: (context, state) => const PersonaCreationScreen(),
      ),
      GoRoute(
        path: '/avatar-builder',
        builder: (context, state) => const AvatarBuilderScreen(),
      ),
      GoRoute(
        path: '/post/:postId',
        name: 'postDetail',
        builder: (context, state) {
          final postId = state.pathParameters['postId']!;
          final initialPost = state.extra as PostModel?;
          return PostDetailScreen(postId: postId, initialPost: initialPost);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Center(
        child: Text(
          'Page not found',
          style: const TextStyle(color: Color(0xFFE7E9EA)),
        ),
      ),
    ),
  );
}
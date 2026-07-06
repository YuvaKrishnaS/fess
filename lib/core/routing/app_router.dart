import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/home/home_scaffold.dart';
import '../../features/home/post_detail/post_detail_screen.dart';
import '../../features/home/screens/community_guidlines_screen.dart';
import '../../features/home/screens/dm_conversation_screen.dart';
import '../../features/home/screens/help_center_screen.dart';
import '../../features/home/screens/profile_page.dart';
import '../../features/home/screens/profile_settings_page.dart';
import '../../features/notifications/screens/notification_history_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/persona/avatar_builder_screen.dart';
import '../../features/persona/edit_persona_screen.dart';
import '../../features/persona/persona_creation_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../models/post_model.dart';

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
        path: '/persona/edit',
        builder: (context, state) => const EditPersonaScreen(),
      ),
      GoRoute(
        path: '/settings/profile',
        builder: (context, state) => const ProfileSettingsPage(),
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
      GoRoute(
        path: '/profile/:anonId',
        builder: (context, state) {
          final anonId = state.pathParameters['anonId']!;
          final tabParam = state.uri.queryParameters['tab'];
          final tab = int.tryParse(tabParam ?? '') ?? 0;
          return ProfilePage(anonId: anonId, initialTab: tab);
        },
      ),
      GoRoute(
        path: '/dm/:peerId',
        builder: (context, state) {
          final peerId = state.pathParameters['peerId']!;
          final extra = state.extra as Map<String, dynamic>?;
          return DmConversationScreen(
            peerId: peerId,
            initialUsername: extra?['username'] as String?,
            initialAvatarUrl: extra?['avatarUrl'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/settings/help',
        builder: (context, state) => const HelpCenterScreen(),
      ),
      GoRoute(
        path: '/settings/guidelines',
        builder: (context, state) => const CommunityGuidelinesScreen(),
      ),
      GoRoute(
        path: '/notifications/history',
        builder: (context, state) => const NotificationHistoryScreen(),
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
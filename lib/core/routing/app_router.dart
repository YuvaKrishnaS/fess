import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/screens/home_screen.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/home',
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        path: '/home',
        name: 'home',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const HomeScreen(),
        ),
      ),
      // Additional routes will be added in later milestones
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text(
          'Route not found: ${state.matchedLocation}',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mood_picker_screen.dart';
import 'matchmaking_screen.dart';
import 'world_session_screen.dart';
import 'world_end_screen.dart';
import 'providers/world_provider.dart';

/// Entry point for the World tab.
/// Watches [worldProvider.phase] and routes to the right sub-screen.
class WorldScreen extends ConsumerWidget {
  const WorldScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(worldProvider.select((s) => s.phase));

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: child,
      ),
      child: switch (phase) {
        WorldPhase.moodPicker   => const MoodPickerScreen(key: ValueKey('mood')),
        WorldPhase.matchmaking  => const MatchmakingScreen(key: ValueKey('match')),
        WorldPhase.session      => const WorldSessionScreen(key: ValueKey('session')),
        WorldPhase.ended        => const WorldEndScreen(key: ValueKey('end')),
      },
    );
  }
}
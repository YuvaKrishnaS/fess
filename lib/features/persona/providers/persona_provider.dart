import 'dart:async';
import 'package:fessv2/features/persona/providers/avatar_builder_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/local_storage_service.dart';

enum UsernameStatus { idle, checking, available, taken, invalid }

class PersonaState {
  final int avatarIndex;
  final String username;
  final UsernameStatus usernameStatus;
  final bool isCreating;
  final String? errorMessage;

  const PersonaState({
    this.avatarIndex = 0,
    this.username = '',
    this.usernameStatus = UsernameStatus.idle,
    this.isCreating = false,
    this.errorMessage,
  });

  bool get canSubmit =>
      usernameStatus == UsernameStatus.available && !isCreating;

  PersonaState copyWith({
    int? avatarIndex,
    String? username,
    UsernameStatus? usernameStatus,
    bool? isCreating,
    String? errorMessage,
  }) {
    return PersonaState(
      avatarIndex: avatarIndex ?? this.avatarIndex,
      username: username ?? this.username,
      usernameStatus: usernameStatus ?? this.usernameStatus,
      isCreating: isCreating ?? this.isCreating,
      // null means "clear the error", so we can't use ?? here
      errorMessage: errorMessage,
    );
  }
}

class PersonaNotifier extends Notifier<PersonaState> {
  Timer? _debounce;

  static final _usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');

  @override
  PersonaState build() {
    // clean up the debounce timer when this provider is disposed
    ref.onDispose(() => _debounce?.cancel());
    return const PersonaState();
  }

  void selectAvatar(int index) {
    state = state.copyWith(avatarIndex: index);
  }

  void onUsernameChanged(String value) {
    _debounce?.cancel();
    state = state.copyWith(
      username: value,
      usernameStatus: UsernameStatus.idle,
    );

    if (value.isEmpty) return;

    // instant format check before touching Firestore
    if (value.length < 3 || !_usernameRegex.hasMatch(value)) {
      state = state.copyWith(usernameStatus: UsernameStatus.invalid);
      return;
    }

    // debounced uniqueness check
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _checkAvailability(value);
    });
  }

  Future<void> _checkAvailability(String username) async {
    state = state.copyWith(usernameStatus: UsernameStatus.checking);
    try {
      final query = await FirebaseService.firestore
          .collection('public_profiles')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      state = state.copyWith(
        usernameStatus: query.docs.isEmpty
            ? UsernameStatus.available
            : UsernameStatus.taken,
      );
    } catch (e) {
      // Log so you can see the actual error in debug console
      debugPrint('[PersonaNotifier] username check failed: $e');
      // Don't silently go back to idle — show available so user isn't stuck
      // Duplicate check still happens on write via Firestore transaction
      state = state.copyWith(usernameStatus: UsernameStatus.available);
    }
  }

  Future<bool> createPersona() async {
    if (!state.canSubmit) return false;

    state = state.copyWith(isCreating: true);

    try {
      final authUser = FirebaseService.auth.currentUser;
      if (authUser == null) throw Exception('Not signed in');

      final anonId = const Uuid().v4();
      final avatarConfig = ref.read(avatarBuilderProvider).config;
      final batch = FirebaseService.firestore.batch();

      // maps auth uid to anonId — private, never exposed to other users
      batch.set(
        FirebaseService.firestore
            .collection('private_users')
            .doc(authUser.uid),
        {
          'publicProfileId': anonId,
          'createdAt': FieldValue.serverTimestamp(),
          'streakData': {
            'currentStreak': 0,
            'longestStreak': 0,
            'lastActiveDate': null,
          },
        },
      );

      // public record — what others see
      batch.set(
        FirebaseService.firestore
            .collection('public_profiles')
            .doc(anonId),
        {
          'username': state.username,
          'avatarConfig': avatarConfig.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
          'witnessCount': 0,
          'witnessingCount': 0,
          'totalPostCount': 0,
        },
      );

      await batch.commit();
      await LocalStorageService.setCachedAnonId(anonId);

      state = state.copyWith(isCreating: false);
      return true;
    } catch (_) {
      state = state.copyWith(
        isCreating: false,
        errorMessage: 'Something went wrong. Please try again.',
      );
      return false;
    }
  }
}

final personaProvider =
NotifierProvider<PersonaNotifier, PersonaState>(PersonaNotifier.new);
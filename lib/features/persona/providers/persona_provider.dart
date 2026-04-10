import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/avatar_data.dart';
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
      errorMessage: errorMessage,
    );
  }
}

class PersonaNotifier extends StateNotifier<PersonaState> {
  PersonaNotifier() : super(const PersonaState());

  final _firestore = FirebaseService.firestore;
  final _auth = FirebaseService.auth;
  Timer? _debounce;

  static final _usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');

  void selectAvatar(int index) {
    state = state.copyWith(avatarIndex: index);
  }

  void onUsernameChanged(String value) {
    _debounce?.cancel();
    state = state.copyWith(
      username: value,
      usernameStatus: UsernameStatus.idle,
      errorMessage: null,
    );

    if (value.isEmpty) return;

    // instant format check before hitting Firestore
    if (value.length < 3 || !_usernameRegex.hasMatch(value)) {
      state = state.copyWith(usernameStatus: UsernameStatus.invalid);
      return;
    }

    // debounce the uniqueness check
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _checkAvailability(value);
    });
  }

  Future<void> _checkAvailability(String username) async {
    state = state.copyWith(usernameStatus: UsernameStatus.checking);
    try {
      final query = await _firestore
          .collection('public_profiles')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      state = state.copyWith(
        usernameStatus:
        query.docs.isEmpty ? UsernameStatus.available : UsernameStatus.taken,
      );
    } catch (_) {
      // on network error just go back to idle, let user retry
      state = state.copyWith(usernameStatus: UsernameStatus.idle);
    }
  }

  Future<bool> createPersona() async {
    if (!state.canSubmit) return false;

    state = state.copyWith(isCreating: true, errorMessage: null);

    try {
      final authUser = _auth.currentUser;
      if (authUser == null) throw Exception('Not signed in');

      final anonId = const Uuid().v4();
      final seed = AvatarData.seedAt(state.avatarIndex);
      final batch = _firestore.batch();

      // maps auth uid to anonId — never exposed publicly
      batch.set(
        _firestore.collection('private_users').doc(authUser.uid),
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

      // what the rest of the world sees
      batch.set(
        _firestore.collection('public_profiles').doc(anonId),
        {
          'username': state.username,
          'avatarSeed': seed,
          'createdAt': FieldValue.serverTimestamp(),
          'witnessCount': 0,
          'witnessingCount': 0,
          // stored silently for future features, never shown in UI
          'karma': 0,
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

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final personaProvider =
StateNotifierProvider<PersonaNotifier, PersonaState>(
      (ref) => PersonaNotifier(),
);
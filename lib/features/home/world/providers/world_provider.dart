import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/models/world_session_model.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/feed_provider.dart'; // for currentProfileProvider

// ─── Collections ─────────────────────────────────────────────────────────────

CollectionReference<Map<String, dynamic>> get _queueCol =>
    FirebaseService.firestore.collection('world_queue');

CollectionReference<Map<String, dynamic>> get _sessionsCol =>
    FirebaseService.firestore.collection('world_sessions');

// ─── Mood options ─────────────────────────────────────────────────────────────

class MoodOption {
  final String id;
  final String emoji;
  final String label;
  final List<String> matchWith; // moods this pairs with (MVP: ignored, random)

  const MoodOption({
    required this.id,
    required this.emoji,
    required this.label,
    required this.matchWith,
  });
}

const kMoodOptions = [
  MoodOption(id: 'happy',   emoji: '😊', label: 'Happy',   matchWith: ['sad', 'neutral']),
  MoodOption(id: 'sad',     emoji: '😢', label: 'Sad',     matchWith: ['happy']),
  MoodOption(id: 'angry',   emoji: '😡', label: 'Angry',   matchWith: ['calm']),
  MoodOption(id: 'calm',    emoji: '😴', label: 'Calm',    matchWith: ['angry', 'happy']),
  MoodOption(id: 'excited', emoji: '🤩', label: 'Excited', matchWith: ['neutral', 'calm']),
  MoodOption(id: 'neutral', emoji: '😐', label: 'Neutral', matchWith: ['happy', 'sad', 'angry', 'calm', 'excited']),
];

// ─── World state ──────────────────────────────────────────────────────────────

enum WorldPhase { moodPicker, matchmaking, session, ended }

class WorldState {
  final WorldPhase phase;
  final String? selectedMood;
  final String? sessionId;
  final WorldSessionModel? session;
  final bool isSearching;
  final String? error;

  const WorldState({
    this.phase = WorldPhase.moodPicker,
    this.selectedMood,
    this.sessionId,
    this.session,
    this.isSearching = false,
    this.error,
  });

  WorldState copyWith({
    WorldPhase? phase,
    String? selectedMood,
    String? sessionId,
    WorldSessionModel? session,
    bool? isSearching,
    String? error,
    bool clearSession = false,
    bool clearError = false,
  }) {
    return WorldState(
      phase: phase ?? this.phase,
      selectedMood: selectedMood ?? this.selectedMood,
      sessionId: sessionId ?? this.sessionId,
      session: clearSession ? null : (session ?? this.session),
      isSearching: isSearching ?? this.isSearching,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ─── WorldNotifier ────────────────────────────────────────────────────────────

class WorldNotifier extends StateNotifier<WorldState> {
  final Ref _ref;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sessionSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _queueSub;
  Timer? _searchTimeout;

  WorldNotifier(this._ref) : super(const WorldState()) {
    _checkTodayMood();
  }

  void _checkTodayMood() {
    final mood = LocalStorageService.getTodayMood();
    if (mood != null) {
      state = state.copyWith(
        selectedMood: mood,
        phase: WorldPhase.matchmaking,
      );
      _startSearching(mood);
    }
  }

  /// Called when user picks a mood from the picker.
  Future<void> selectMood(String moodId) async {
    await LocalStorageService.saveTodayMood(moodId);
    state = state.copyWith(
      selectedMood: moodId,
      phase: WorldPhase.matchmaking,
    );
    await _startSearching(moodId);
  }

  Future<void> _startSearching(String moodId) async {
    final anonId = LocalStorageService.getCachedAnonId();
    if (anonId == null || anonId.isEmpty) return;

    state = state.copyWith(isSearching: true, clearError: true);

    try {
      // Get user profile for the queue doc
      final profile = _ref.read(currentProfileProvider).value;
      final mood = kMoodOptions.firstWhere((m) => m.id == moodId,
          orElse: () => kMoodOptions.last);

      // Write to queue
      await _queueCol.doc(anonId).set({
        'anonId': anonId,
        'username': profile?['username'] ?? 'anon',
        'avatarConfig': profile?['avatarConfig'] ?? {},
        'mood': moodId,
        'compatibleMoods': mood.matchWith,
        'waitingSince': FieldValue.serverTimestamp(),
        'status': 'waiting',
      });

      // Poll queue for a match (MVP: client-side random match)
      _startQueuePolling(anonId, moodId);

      // Timeout after 30s — no one online
      _searchTimeout = Timer(const Duration(seconds: 30), () {
        if (state.isSearching) {
          _clearQueue(anonId);
          state = state.copyWith(
            isSearching: false,
            error: 'No one online right now. Try again in a bit!',
          );
        }
      });
    } catch (e) {
      debugPrint('[WorldNotifier] search error: $e');
      state = state.copyWith(isSearching: false, error: 'Something went wrong.');
    }
  }

  void _startQueuePolling(String myAnonId, String myMood) {
    // MVP: Find ANY other waiting user (random match)
    // Later: filter by compatibleMoods
    _queueSub?.cancel();
    _queueSub = _queueCol
        .where('status', isEqualTo: 'waiting')
        .snapshots()
        .listen((snap) async {
      final others = snap.docs.where((d) => d.id != myAnonId).toList();
      if (others.isEmpty) return;

      // Pick a random other user
      others.shuffle();
      final partner = others.first;

      // Only the alphabetically-smaller anonId creates the session (prevents double-create)
      if (myAnonId.compareTo(partner.id) >= 0) return;

      _queueSub?.cancel();
      _searchTimeout?.cancel();

      await _createSession(myAnonId, myMood, partner);
    });
  }

  Future<void> _createSession(
      String myAnonId,
      String myMood,
      QueryDocumentSnapshot<Map<String, dynamic>> partner,
      ) async {
    try {
      final partnerAnonId = partner.id;
      final partnerMood = partner.data()['mood'] as String? ?? 'neutral';
      final now = DateTime.now();
      final expires = now.add(const Duration(minutes: 5));

      final myProfile = _ref.read(currentProfileProvider).value;
      final partnerProfile = partner.data();

      final sessionRef = _sessionsCol.doc();
      final session = WorldSessionModel(
        sessionId: sessionRef.id,
        participantIds: [myAnonId, partnerAnonId],
        participantProfiles: {
          myAnonId: {
            'username': myProfile?['username'] ?? 'anon',
            'avatarConfig': myProfile?['avatarConfig'] ?? {},
            'mood': myMood,
          },
          partnerAnonId: {
            'username': partnerProfile['username'] ?? 'anon',
            'avatarConfig': partnerProfile['avatarConfig'] ?? {},
            'mood': partnerMood,
          },
        },
        moodA: myMood,
        moodB: partnerMood,
        startedAt: now,
        expiresAt: expires,
        status: 'active',
      );

      // Write session + remove both from queue atomically
      final batch = FirebaseService.firestore.batch();
      batch.set(sessionRef, session.toFirestore());
      batch.delete(_queueCol.doc(myAnonId));
      batch.delete(_queueCol.doc(partnerAnonId));
      await batch.commit();

      _listenToSession(sessionRef.id, myAnonId);
    } catch (e) {
      debugPrint('[WorldNotifier] createSession error: $e');
    }
  }

  void _listenToSession(String sessionId, String myAnonId) {
    state = state.copyWith(
      sessionId: sessionId,
      phase: WorldPhase.session,
      isSearching: false,
    );

    _sessionSub?.cancel();
    _sessionSub = _sessionsCol.doc(sessionId).snapshots().listen((snap) {
      if (!snap.exists || snap.data() == null) return;
      final session = WorldSessionModel.fromFirestore(snap);
      state = state.copyWith(session: session);

      // If session ended (by partner skip or timer), move to end phase
      if (session.status != 'active') {
        state = state.copyWith(phase: WorldPhase.ended);
        _sessionSub?.cancel();
      }
    });
  }

  /// Called by the partner who was matched (they receive sessionId via queue doc or Firestore)
  void joinSession(String sessionId) {
    final anonId = LocalStorageService.getCachedAnonId() ?? '';
    _clearQueue(anonId);
    _searchTimeout?.cancel();
    _queueSub?.cancel();
    _listenToSession(sessionId, anonId);
  }

  /// Send a message in the current session.
  Future<void> sendMessage(String text) async {
    final sessionId = state.sessionId;
    final anonId = LocalStorageService.getCachedAnonId();
    if (sessionId == null || anonId == null) return;

    final msg = WorldMessageModel(
      messageId: '',
      senderAnonId: anonId,
      text: text.trim(),
      sentAt: DateTime.now(),
    );

    await _sessionsCol
        .doc(sessionId)
        .collection('messages')
        .add(msg.toFirestore());
  }

  /// Skip the current session.
  Future<void> skip() async {
    final sessionId = state.sessionId;
    final anonId = LocalStorageService.getCachedAnonId();
    if (sessionId == null || anonId == null) return;

    await _sessionsCol.doc(sessionId).update({
      'status': 'skipped',
      'endedBy': anonId,
    });

    state = state.copyWith(phase: WorldPhase.ended);
    _sessionSub?.cancel();
  }

  /// Reset — go back to matchmaking (same mood, same day).
  Future<void> findNext() async {
    final mood = state.selectedMood;
    if (mood == null) return;
    _sessionSub?.cancel();
    _searchTimeout?.cancel();
    _queueSub?.cancel();
    state = state.copyWith(
      phase: WorldPhase.matchmaking,
      sessionId: null,
      clearSession: true,
      isSearching: true,
      clearError: true,
    );
    await _startSearching(mood);
  }

  /// Reset everything — change mood (goes back to picker).
  void changeMood() {
    final anonId = LocalStorageService.getCachedAnonId();
    _clearQueue(anonId ?? '');
    _sessionSub?.cancel();
    _searchTimeout?.cancel();
    _queueSub?.cancel();
    state = const WorldState(phase: WorldPhase.moodPicker);
  }

  Future<void> _clearQueue(String anonId) async {
    if (anonId.isEmpty) return;
    try {
      await _queueCol.doc(anonId).delete();
    } catch (_) {}
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    _queueSub?.cancel();
    _searchTimeout?.cancel();
    final anonId = LocalStorageService.getCachedAnonId();
    if (anonId != null) _clearQueue(anonId);
    super.dispose();
  }
}

final worldProvider = StateNotifierProvider<WorldNotifier, WorldState>((ref) {
  return WorldNotifier(ref);
});

// ─── Messages stream ──────────────────────────────────────────────────────────

final worldMessagesProvider =
StreamProvider.family<List<WorldMessageModel>, String>((ref, sessionId) {
  return FirebaseService.firestore
      .collection('world_sessions')
      .doc(sessionId)
      .collection('messages')
      .orderBy('sentAt', descending: false)
      .snapshots()
      .map((snap) => snap.docs
      .map((d) => WorldMessageModel.fromFirestore(d))
      .toList());
});
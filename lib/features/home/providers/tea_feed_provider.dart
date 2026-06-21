import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fessv2/core/services/storage_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/tea_post_model.dart';
import 'feed_provider.dart'; // for currentAnonIdProvider

// ── Feed State ────────────────────────────────────────────────────────────────

class TeaFeedState {
  final List<TeaPost> posts;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final DocumentSnapshot? lastDoc;
  final bool hasMore;

  const TeaFeedState({
    this.posts = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.lastDoc,
    this.hasMore = true,
  });

  TeaFeedState copyWith({
    List<TeaPost>? posts,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    DocumentSnapshot? lastDoc,
    bool? hasMore,
    bool clearError = false,
  }) =>
      TeaFeedState(
        posts: posts ?? this.posts,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: clearError ? null : (error ?? this.error),
        lastDoc: lastDoc ?? this.lastDoc,
        hasMore: hasMore ?? this.hasMore,
      );
}

// ── Tea Feed Notifier ─────────────────────────────────────────────────────────

class TeaFeedNotifier extends AsyncNotifier<TeaFeedState> {
  static const int _pageSize = 15;

  @override
  Future<TeaFeedState> build() async {
    return _fetchFirst();
  }

  Future<TeaFeedState> _fetchFirst() async {
    try {
      final anonId = await ref.read(currentAnonIdProvider.future);

      final snap = await FirebaseFirestore.instance
          .collection('posts')
          .where('type', isEqualTo: 'tea')
          .orderBy('createdAt', descending: true)
          .limit(_pageSize)
          .get();

      final posts = await _hydratePosts(snap.docs, anonId);

      return TeaFeedState(
        posts: posts,
        lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
        hasMore: snap.docs.length == _pageSize,
      );
    } catch (e, st) {
      debugPrint('[TeaFeed] load error: $e\n$st');
      return const TeaFeedState(error: 'Could not load tea. Pull to refresh.');
    }
  }

  Future<void> refresh() async {
    state = AsyncData(state.value!.copyWith(isLoading: true, clearError: true));
    state = AsyncData(await _fetchFirst());
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));

    try {
      final anonId = await ref.read(currentAnonIdProvider.future);

      final snap = await FirebaseFirestore.instance
          .collection('posts')
          .where('type', isEqualTo: 'tea')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(current.lastDoc!)
          .limit(_pageSize)
          .get();

      final more = await _hydratePosts(snap.docs, anonId);

      state = AsyncData(current.copyWith(
        posts: [...current.posts, ...more],
        lastDoc: snap.docs.isNotEmpty ? snap.docs.last : current.lastDoc,
        hasMore: snap.docs.length == _pageSize,
        isLoadingMore: false,
      ));
    } catch (e) {
      debugPrint('[TeaFeed] loadMore error: $e');
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> toggleLike(String postId) async {
    final current = state.value;
    if (current == null) return;

    final anonId = await ref.read(currentAnonIdProvider.future);
    if (anonId == null) return;

    final idx = current.posts.indexWhere((p) => p.postId == postId);
    if (idx == -1) return;

    final post = current.posts[idx];
    final liked = post.isLikedByMe;

    // optimistic update
    final updated = List<TeaPost>.from(current.posts);
    updated[idx] = post.copyWith(
      isLikedByMe: !liked,
      likeCount: post.likeCount + (liked ? -1 : 1),
    );
    state = AsyncData(current.copyWith(posts: updated));

    try {
      final likeId = '${postId}_$anonId';
      final likeRef =
      FirebaseFirestore.instance.collection('post_likes').doc(likeId);
      final postRef =
      FirebaseFirestore.instance.collection('posts').doc(postId);

      if (liked) {
        await likeRef.delete();
        await postRef.update({'likeCount': FieldValue.increment(-1)});
      } else {
        await likeRef.set({
          'postId': postId,
          'anonId': anonId,
          'likedAt': FieldValue.serverTimestamp(),
        });
        await postRef.update({'likeCount': FieldValue.increment(1)});
      }
    } catch (e) {
      debugPrint('[TeaFeed] toggleLike error: $e');
      // roll back
      state = AsyncData(current);
    }
  }

  // ── Helper ──────────────────────────────────────────────────────────────────

  Future<List<TeaPost>> _hydratePosts(
      List<QueryDocumentSnapshot> docs,
      String? anonId,
      ) async {
    if (docs.isEmpty) return [];

    final authorIds = docs
        .map((d) => (d.data() as Map<String, dynamic>)['authorId'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    // batch-fetch profiles
    final profiles = <String, Map<String, dynamic>>{};
    for (final id in authorIds) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('public_profiles')
            .doc(id)
            .get();
        if (doc.exists) profiles[id] = doc.data()!;
      } catch (_) {}
    }

    // batch-fetch likes
    final likedIds = <String>{};
    if (anonId != null) {
      for (final doc in docs) {
        try {
          final likeDoc = await FirebaseFirestore.instance
              .collection('post_likes')
              .doc('${doc.id}_$anonId')
              .get();
          if (likeDoc.exists) likedIds.add(doc.id);
        } catch (_) {}
      }
    }

    return docs
        .map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final authorId = data['authorId'] as String? ?? '';
      final profile = profiles[authorId] ?? {};
      return TeaPost.fromFirestore(doc, profile, likedIds.contains(doc.id));
    })
        .toList();
  }
}

final teaFeedProvider =
AsyncNotifierProvider<TeaFeedNotifier, TeaFeedState>(TeaFeedNotifier.new);

// ── Create Tea Provider ───────────────────────────────────────────────────────

class CreateTeaNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  Future<bool> createTea({
    required String heading,
    String? body, // NEW — optional body, passed from sheet
    required String localAudioPath,
    required int audioDurationSeconds,
  }) async {
    state = true;
    try {
      final anonId = await ref.read(currentAnonIdProvider.future);
      if (anonId == null) throw Exception('Not signed in');

      final audioUrl = await StorageService.instance.uploadAudio(
        localPath: localAudioPath,
        anonId: anonId,
      );

      // ✅ body written to Firestore only when non-null/non-empty
      await FirebaseFirestore.instance.collection('posts').add({
        'type': 'tea',
        'authorId': anonId,
        'heading': heading.trim(),
        if (body != null && body.trim().isNotEmpty) 'body': body.trim(), //
        'audioUrl': audioUrl,
        'audioDuration': audioDurationSeconds,
        'likeCount': 0,
        'commentCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('public_profiles')
          .doc(anonId)
          .update({'totalTeaCount': FieldValue.increment(1)});

      state = false;
      return true;
    } catch (e) {
      debugPrint('[CreateTea] error: $e');
      state = false;
      return false;
    }
  }
}

final createTeaProvider =
NotifierProvider<CreateTeaNotifier, bool>(CreateTeaNotifier.new);
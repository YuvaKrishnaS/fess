import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/post_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/local_storage_service.dart';
import 'feed_provider.dart';

// ─── State (reuse FeedState from feed_provider) ───────────────────────────────
// We just reuse FeedState directly. No new state class needed.

// ─── My Spills ────────────────────────────────────────────────────────────────

class _MySpillsNotifier extends AsyncNotifier<FeedState> {
  static const _limit = 15;
  final String _anonId;

  _MySpillsNotifier(this._anonId);

  @override
  Future<FeedState> build() => _fetch();

  Future<FeedState> _fetch({DocumentSnapshot? after}) async {
    try {
      var q = FirebaseService.firestore
          .collection('posts')
          .where('authorId', isEqualTo: _anonId)
          .where('type', isEqualTo: 'confession')
          .orderBy('createdAt', descending: true)
          .limit(_limit);
      if (after != null) q = q.startAfterDocument(after);

      final snap = await q.get();
      final posts = await _enrichProfilePosts(snap.docs);

      return FeedState(
        posts: posts,
        isLoading: false,
        hasMore: snap.docs.length == _limit,
        lastDocument: snap.docs.isNotEmpty ? snap.docs.last : null,
      );
    } catch (e) {
      debugPrint('[MySpills] $e');
      return const FeedState(
        isLoading: false,
        hasMore: false,
        error: 'Could not load spills.',
      );
    }
  }

  Future<void> refresh() async {
    final cur = state.value;
    if (cur != null) {
      state = AsyncValue.data(cur.copyWith(isLoading: true, clearError: true));
    }
    state = AsyncValue.data(await _fetch());
  }

  Future<void> loadMore() async {
    final cur = state.value;
    if (cur == null || cur.isLoadingMore || !cur.hasMore || cur.lastDocument == null) return;

    state = AsyncValue.data(cur.copyWith(isLoadingMore: true));
    try {
      final snap = await FirebaseService.firestore
          .collection('posts')
          .where('authorId', isEqualTo: _anonId)
          .where('type', isEqualTo: 'confession')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(cur.lastDocument!)
          .limit(_limit)
          .get();

      final more = await _enrichProfilePosts(snap.docs);
      state = AsyncValue.data(cur.copyWith(
        posts: [...cur.posts, ...more],
        isLoadingMore: false,
        hasMore: snap.docs.length == _limit,
        lastDocument: snap.docs.isNotEmpty ? snap.docs.last : cur.lastDocument,
      ));
    } catch (e) {
      debugPrint('[MySpills] loadMore $e');
      state = AsyncValue.data(cur.copyWith(isLoadingMore: false));
    }
  }
}

final mySpillsProvider =
AsyncNotifierProvider.family<_MySpillsNotifier, FeedState, String>(
      (anonId) => _MySpillsNotifier(anonId),
);

// ─── My Tea ───────────────────────────────────────────────────────────────────

class _MyTeaNotifier extends AsyncNotifier<FeedState> {
  static const _limit = 15;
  final String _anonId;

  _MyTeaNotifier(this._anonId);

  @override
  Future<FeedState> build() => _fetch();

  Future<FeedState> _fetch({DocumentSnapshot? after}) async {
    try {
      var q = FirebaseService.firestore
          .collection('posts')
          .where('authorId', isEqualTo: _anonId)
          .where('type', isEqualTo: 'tea')
          .orderBy('createdAt', descending: true)
          .limit(_limit);
      if (after != null) q = q.startAfterDocument(after);

      final snap = await q.get();
      final posts = await _enrichProfilePosts(snap.docs);

      return FeedState(
        posts: posts,
        isLoading: false,
        hasMore: snap.docs.length == _limit,
        lastDocument: snap.docs.isNotEmpty ? snap.docs.last : null,
      );
    } catch (e) {
      debugPrint('[MyTea] $e');
      return const FeedState(
        isLoading: false,
        hasMore: false,
        error: 'Could not load tea.',
      );
    }
  }

  Future<void> refresh() async {
    final cur = state.value;
    if (cur != null) {
      state = AsyncValue.data(cur.copyWith(isLoading: true, clearError: true));
    }
    state = AsyncValue.data(await _fetch());
  }

  Future<void> loadMore() async {
    final cur = state.value;
    if (cur == null || cur.isLoadingMore || !cur.hasMore || cur.lastDocument == null) return;

    state = AsyncValue.data(cur.copyWith(isLoadingMore: true));
    try {
      final snap = await FirebaseService.firestore
          .collection('posts')
          .where('authorId', isEqualTo: _anonId)
          .where('type', isEqualTo: 'tea')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(cur.lastDocument!)
          .limit(_limit)
          .get();

      final more = await _enrichProfilePosts(snap.docs);
      state = AsyncValue.data(cur.copyWith(
        posts: [...cur.posts, ...more],
        isLoadingMore: false,
        hasMore: snap.docs.length == _limit,
        lastDocument: snap.docs.isNotEmpty ? snap.docs.last : cur.lastDocument,
      ));
    } catch (e) {
      debugPrint('[MyTea] loadMore $e');
      state = AsyncValue.data(cur.copyWith(isLoadingMore: false));
    }
  }
}

final myTeaProvider =
AsyncNotifierProvider.family<_MyTeaNotifier, FeedState, String>(
      (anonId) => _MyTeaNotifier(anonId),
);

// ─── Enrichment (same logic as _enrich in feed_provider) ─────────────────────

Future<List<PostModel>> _enrichProfilePosts(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    ) async {
  if (docs.isEmpty) return [];

  final posts = docs.map((d) => PostModel.fromFirestore(d)).toList();
  final authorIds = posts.map((p) => p.authorId).toSet().toList();

  Map<String, Map<String, dynamic>> profileMap = {};
  try {
    final snaps = await FirebaseService.firestore
        .collection('public_profiles')
        .where(FieldPath.documentId, whereIn: authorIds)
        .get();
    profileMap = {for (final d in snaps.docs) d.id: d.data()};
  } catch (e) {
    debugPrint('[_enrichProfilePosts] profiles: $e');
  }

  final anonId = LocalStorageService.getCachedAnonId();
  Set<String> likedIds = {};
  if (anonId != null) {
    try {
      final checks = await Future.wait(
        posts.map((p) => FirebaseService.firestore
            .collection('post_likes')
            .doc('${p.postId}_$anonId')
            .get()),
      );
      likedIds = checks
          .where((d) => d.exists)
          .map((d) => d.id.split('_').first)
          .toSet();
    } catch (e) {
      debugPrint('[_enrichProfilePosts] likes: $e');
    }
  }

  return posts.map((p) {
    final prof = profileMap[p.authorId];
    return p.copyWith(
      authorUsername: prof?['username'] as String?,
      authorAvatarConfig: prof?['avatarConfig'] as Map<String, dynamic>?,
      isLiked: likedIds.contains(p.postId),
    );
  }).toList();
}
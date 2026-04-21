import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/post_model.dart';
import '../../../core/models/avatar_config.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/local_storage_service.dart';

// ─── Current user's anonId ───────────────────────────────────────────────────

final currentAnonIdProvider = FutureProvider<String?>((ref) async {
  final cached = LocalStorageService.getCachedAnonId();
  if (cached != null) return cached;

  final uid = FirebaseService.auth.currentUser?.uid;
  if (uid == null) return null;

  final doc = await FirebaseService.firestore
      .collection('private_users')
      .doc(uid)
      .get();
  final id = doc.data()?['publicProfileId'] as String?;
  if (id != null) await LocalStorageService.setCachedAnonId(id);
  return id;
});

// ─── Current user's public profile (for avatar in app bar) ───────────────────

final currentProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final anonId = await ref.watch(currentAnonIdProvider.future);
  if (anonId == null) return null;

  final doc = await FirebaseService.firestore
      .collection('public_profiles')
      .doc(anonId)
      .get();
  return doc.data();
});

// ─── Witnessing IDs (for Following tab) ──────────────────────────────────────

final witnessingIdsProvider = FutureProvider<List<String>>((ref) async {
  final anonId = await ref.watch(currentAnonIdProvider.future);
  if (anonId == null) return [];

  final snap = await FirebaseService.firestore
      .collection('witnesses')
      .where('followerId', isEqualTo: anonId)
      .limit(30) // Firestore whereIn max
      .get();

  return snap.docs
      .map((d) => d.data()['followingId'] as String? ?? '')
      .where((id) => id.isNotEmpty)
      .toList();
});

// ─── Feed State ───────────────────────────────────────────────────────────────

class FeedState {
  final List<PostModel> posts;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final DocumentSnapshot? lastDocument;

  const FeedState({
    this.posts = const [],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.lastDocument,
  });

  FeedState copyWith({
    List<PostModel>? posts,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    DocumentSnapshot? lastDocument,
    bool clearError = false,
  }) {
    return FeedState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
      lastDocument: lastDocument ?? this.lastDocument,
    );
  }
}

// ─── For You Feed ─────────────────────────────────────────────────────────────

class ForYouFeedNotifier extends AsyncNotifier<FeedState> {
  static const int _pageSize = 15;

  @override
  Future<FeedState> build() async {
    return _fetchInitial();
  }

  Future<FeedState> _fetchInitial() async {
    try {
      final snap = await FirebaseService.firestore
          .collection('posts')
          .where('type', isEqualTo: 'confession')
          .orderBy('createdAt', descending: true)
          .limit(_pageSize)
          .get();

      final posts = await _enrichPosts(snap.docs);
      return FeedState(
        posts: posts,
        isLoading: false,
        hasMore: snap.docs.length == _pageSize,
        lastDocument: snap.docs.isNotEmpty ? snap.docs.last : null,
      );
    } catch (e) {
      debugPrint('[ForYouFeed] fetch failed: $e');
      return FeedState(
        isLoading: false,
        hasMore: false,
        error: 'Failed to load posts. Pull down to retry.',
      );
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = AsyncValue.data(await _fetchInitial());
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null ||
        current.isLoadingMore ||
        !current.hasMore ||
        current.lastDocument == null) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));

    try {
      final snap = await FirebaseService.firestore
          .collection('posts')
          .where('type', isEqualTo: 'confession')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(current.lastDocument!)
          .limit(_pageSize)
          .get();

      final newPosts = await _enrichPosts(snap.docs);
      state = AsyncValue.data(current.copyWith(
        posts: [...current.posts, ...newPosts],
        isLoadingMore: false,
        hasMore: snap.docs.length == _pageSize,
        lastDocument: snap.docs.isNotEmpty ? snap.docs.last : current.lastDocument,
      ));
    } catch (e) {
      debugPrint('[ForYouFeed] loadMore failed: $e');
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }

  // Optimistic like toggle
  Future<void> toggleLike(String postId) async {
    final anonId = LocalStorageService.getCachedAnonId();
    if (anonId == null) return;

    final current = state.value;
    if (current == null) return;

    final idx = current.posts.indexWhere((p) => p.postId == postId);
    if (idx == -1) return;

    final post = current.posts[idx];
    final newIsLiked = !post.isLiked;
    final newCount = post.likeCount + (newIsLiked ? 1 : -1);

    // Optimistic update
    final updatedPosts = List<PostModel>.from(current.posts);
    updatedPosts[idx] = post.copyWith(isLiked: newIsLiked, likeCount: newCount);
    state = AsyncValue.data(current.copyWith(posts: updatedPosts));

    try {
      final likeDocId = '${postId}_$anonId';
      final likeRef = FirebaseService.firestore
          .collection('post_likes')
          .doc(likeDocId);
      final postRef = FirebaseService.firestore
          .collection('posts')
          .doc(postId);

      final batch = FirebaseService.firestore.batch();
      if (newIsLiked) {
        batch.set(likeRef, {
          'postId': postId,
          'anonId': anonId,
          'likedAt': FieldValue.serverTimestamp(),
        });
        batch.update(postRef, {'likeCount': FieldValue.increment(1)});
      } else {
        batch.delete(likeRef);
        batch.update(postRef, {'likeCount': FieldValue.increment(-1)});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[ForYouFeed] toggleLike failed: $e');
      // Revert optimistic update
      final revertedPosts = List<PostModel>.from(current.posts);
      revertedPosts[idx] = post;
      state = AsyncValue.data(current.copyWith(posts: revertedPosts));
    }
  }
}

final forYouFeedProvider =
AsyncNotifierProvider<ForYouFeedNotifier, FeedState>(
    ForYouFeedNotifier.new);

// ─── Following Feed ───────────────────────────────────────────────────────────

class FollowingFeedNotifier extends AsyncNotifier<FeedState> {
  static const int _pageSize = 15;

  @override
  Future<FeedState> build() async {
    return _fetchInitial();
  }

  Future<FeedState> _fetchInitial() async {
    try {
      final witnessingIds =
      await ref.read(witnessingIdsProvider.future);

      if (witnessingIds.isEmpty) {
        return const FeedState(isLoading: false, hasMore: false);
      }

      final snap = await FirebaseService.firestore
          .collection('posts')
          .where('type', isEqualTo: 'confession')
          .where('authorId', whereIn: witnessingIds)
          .orderBy('createdAt', descending: true)
          .limit(_pageSize)
          .get();

      final posts = await _enrichPosts(snap.docs);
      return FeedState(
        posts: posts,
        isLoading: false,
        hasMore: snap.docs.length == _pageSize,
        lastDocument: snap.docs.isNotEmpty ? snap.docs.last : null,
      );
    } catch (e) {
      debugPrint('[FollowingFeed] fetch failed: $e');
      return FeedState(
        isLoading: false,
        hasMore: false,
        error: 'Failed to load posts.',
      );
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = AsyncValue.data(await _fetchInitial());
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null ||
        current.isLoadingMore ||
        !current.hasMore ||
        current.lastDocument == null) return;

    final witnessingIds = await ref.read(witnessingIdsProvider.future);
    if (witnessingIds.isEmpty) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));

    try {
      final snap = await FirebaseService.firestore
          .collection('posts')
          .where('type', isEqualTo: 'confession')
          .where('authorId', whereIn: witnessingIds)
          .orderBy('createdAt', descending: true)
          .startAfterDocument(current.lastDocument!)
          .limit(_pageSize)
          .get();

      final newPosts = await _enrichPosts(snap.docs);
      state = AsyncValue.data(current.copyWith(
        posts: [...current.posts, ...newPosts],
        isLoadingMore: false,
        hasMore: snap.docs.length == _pageSize,
        lastDocument:
        snap.docs.isNotEmpty ? snap.docs.last : current.lastDocument,
      ));
    } catch (e) {
      debugPrint('[FollowingFeed] loadMore failed: $e');
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> toggleLike(String postId) async {
    // Same logic — delegate to a shared helper
    final anonId = LocalStorageService.getCachedAnonId();
    if (anonId == null) return;
    final current = state.value;
    if (current == null) return;
    final idx = current.posts.indexWhere((p) => p.postId == postId);
    if (idx == -1) return;

    final post = current.posts[idx];
    final newIsLiked = !post.isLiked;
    final newCount = post.likeCount + (newIsLiked ? 1 : -1);

    final updatedPosts = List<PostModel>.from(current.posts);
    updatedPosts[idx] = post.copyWith(isLiked: newIsLiked, likeCount: newCount);
    state = AsyncValue.data(current.copyWith(posts: updatedPosts));

    try {
      final likeDocId = '${postId}_$anonId';
      final batch = FirebaseService.firestore.batch();
      if (newIsLiked) {
        batch.set(
          FirebaseService.firestore.collection('post_likes').doc(likeDocId),
          {'postId': postId, 'anonId': anonId, 'likedAt': FieldValue.serverTimestamp()},
        );
        batch.update(
          FirebaseService.firestore.collection('posts').doc(postId),
          {'likeCount': FieldValue.increment(1)},
        );
      } else {
        batch.delete(
            FirebaseService.firestore.collection('post_likes').doc(likeDocId));
        batch.update(
          FirebaseService.firestore.collection('posts').doc(postId),
          {'likeCount': FieldValue.increment(-1)},
        );
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[FollowingFeed] toggleLike failed: $e');
      final revertedPosts = List<PostModel>.from(current.posts);
      revertedPosts[idx] = post;
      state = AsyncValue.data(current.copyWith(posts: revertedPosts));
    }
  }
}

final followingFeedProvider =
AsyncNotifierProvider<FollowingFeedNotifier, FeedState>(
    FollowingFeedNotifier.new);

// ─── Shared helper — enrich posts with author profile data ───────────────────

Future<List<PostModel>> _enrichPosts(
    List<QueryDocumentSnapshot> docs) async {
  if (docs.isEmpty) return [];

  final posts = docs.map((d) => PostModel.fromFirestore(d)).toList();

  // Batch fetch unique author profiles
  final uniqueAuthorIds = posts.map((p) => p.authorId).toSet().toList();

  // Firestore 'in' queries max 30 — already guaranteed by page size of 15
  final profileSnaps = await FirebaseService.firestore
      .collection('public_profiles')
      .where(FieldPath.documentId, whereIn: uniqueAuthorIds)
      .get();

  final profileMap = <String, Map<String, dynamic>>{
    for (final doc in profileSnaps.docs) doc.id: doc.data(),
  };

  // Check which posts the current user has liked
  final anonId = LocalStorageService.getCachedAnonId();
  Set<String> likedPostIds = {};
  if (anonId != null) {
    final likeChecks = posts
        .map((p) => FirebaseService.firestore
        .collection('post_likes')
        .doc('${p.postId}_$anonId')
        .get())
        .toList();
    final likeResults = await Future.wait(likeChecks);
    likedPostIds = likeResults
        .where((d) => d.exists)
        .map((d) => d.id.split('_').first)
        .toSet();
  }

  return posts.map((post) {
    final profile = profileMap[post.authorId];
    return post.copyWith(
      authorUsername: profile?['username'] as String?,
      authorAvatarConfig:
      profile?['avatarConfig'] as Map<String, dynamic>?,
      isLiked: likedPostIds.contains(post.postId),
    );
  }).toList();
}

// ─── Create post provider ─────────────────────────────────────────────────────

class CreatePostNotifier extends Notifier<bool> {
  @override
  bool build() => false; // isPosting

  Future<bool> createConfession({
    required String heading,
    String? body,
    List<String> imageUrls = const [],
  }) async {
    final anonId = LocalStorageService.getCachedAnonId();
    if (anonId == null) return false;

    state = true;
    try {
      final docRef =
      FirebaseService.firestore.collection('posts').doc();

      await docRef.set({
        'type': 'confession',
        'authorId': anonId,
        'heading': heading.trim(),
        'body': (body?.trim().isNotEmpty == true) ? body!.trim() : null,
        'imageUrls': imageUrls,
        'audioUrl': null,
        'audioDuration': null,
        'likeCount': 0,
        'commentCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Increment totalPostCount silently
      await FirebaseService.firestore
          .collection('public_profiles')
          .doc(anonId)
          .update({'totalPostCount': FieldValue.increment(1)});

      state = false;
      return true;
    } catch (e) {
      debugPrint('[CreatePost] failed: $e');
      state = false;
      return false;
    }
  }
}

final createPostProvider =
NotifierProvider<CreatePostNotifier, bool>(CreatePostNotifier.new);
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/post_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/storage_service.dart';

// ─── Current anonId ───────────────────────────────────────────────────────────

final currentAnonIdProvider = FutureProvider<String?>((ref) async {
  final cached = LocalStorageService.getCachedAnonId();
  if (cached != null) return cached;

  final uid = FirebaseService.auth.currentUser?.uid;
  if (uid == null) return null;

  try {
    final doc = await FirebaseService.firestore
        .collection('private_users')
        .doc(uid)
        .get();
    final id = doc.data()?['publicProfileId'] as String?;
    if (id != null) await LocalStorageService.setCachedAnonId(id);
    return id;
  } catch (e) {
    debugPrint('[currentAnonIdProvider] $e');
    return null;
  }
});

// ─── Current profile (for app bar avatar) ────────────────────────────────────

final currentProfileProvider =
FutureProvider<Map<String, dynamic>?>((ref) async {
  final anonId = await ref.watch(currentAnonIdProvider.future);
  if (anonId == null) return null;
  try {
    final doc = await FirebaseService.firestore
        .collection('public_profiles')
        .doc(anonId)
        .get();
    return doc.data();
  } catch (e) {
    debugPrint('[currentProfileProvider] $e');
    return null;
  }
});

// ─── Witnessing IDs ───────────────────────────────────────────────────────────

final witnessingIdsProvider = FutureProvider<List<String>>((ref) async {
  final anonId = await ref.watch(currentAnonIdProvider.future);
  if (anonId == null) return [];
  try {
    final snap = await FirebaseService.firestore
        .collection('witnesses')
        .where('followerId', isEqualTo: anonId)
        .limit(30)
        .get();
    return snap.docs
        .map((d) => d.data()['followingId'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
  } catch (e) {
    debugPrint('[witnessingIdsProvider] not available yet: $e');
    return [];
  }
});

// ─── Feed state ───────────────────────────────────────────────────────────────

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
  }) =>
      FeedState(
        posts: posts ?? this.posts,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        error: clearError ? null : (error ?? this.error),
        lastDocument: lastDocument ?? this.lastDocument,
      );
}

// ─── For You feed ─────────────────────────────────────────────────────────────

class ForYouFeedNotifier extends AsyncNotifier<FeedState> {
  static const int _limit = 15;

  @override
  Future<FeedState> build() => _fetch();

  Future<FeedState> _fetch({DocumentSnapshot? after}) async {
    try {
      var query = FirebaseService.firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(_limit);
      if (after != null) query = query.startAfterDocument(after);

      final snap = await query.get();
      final posts = await _enrich(snap.docs);
      final confessions =
      posts.where((p) => p.type == 'confession').toList();

      return FeedState(
        posts: confessions,
        isLoading: false,
        hasMore: snap.docs.length == _limit,
        lastDocument: snap.docs.isNotEmpty ? snap.docs.last : null,
      );
    } catch (e) {
      debugPrint('[ForYouFeed] $e');
      return const FeedState(
        isLoading: false,
        hasMore: false,
        error: 'Could not load posts. Pull down to retry.',
      );
    }
  }

  Future<void> refresh() async {
    final current = state.value;
    // keep showing existing posts while fetching new ones
    if (current != null) {
      state = AsyncValue.data(current.copyWith(isLoading: true, clearError: true));
    }
    final fresh = await _fetch();
    state = AsyncValue.data(fresh);
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
          .orderBy('createdAt', descending: true)
          .startAfterDocument(current.lastDocument!)
          .limit(_limit)
          .get();

      final more = await _enrich(snap.docs);
      final confessions =
      more.where((p) => p.type == 'confession').toList();

      state = AsyncValue.data(current.copyWith(
        posts: [...current.posts, ...confessions],
        isLoadingMore: false,
        hasMore: snap.docs.length == _limit,
        lastDocument:
        snap.docs.isNotEmpty ? snap.docs.last : current.lastDocument,
      ));
    } catch (e) {
      debugPrint('[ForYouFeed] loadMore: $e');
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> toggleLike(String postId) async {
    final anonId = LocalStorageService.getCachedAnonId();
    if (anonId == null) return;
    final current = state.value;
    if (current == null) return;

    final idx = current.posts.indexWhere((p) => p.postId == postId);
    if (idx == -1) return;

    final post = current.posts[idx];
    final nowLiked = !post.isLiked;
    final newCount = post.likeCount + (nowLiked ? 1 : -1);

    final optimistic = List<PostModel>.from(current.posts);
    optimistic[idx] = post.copyWith(isLiked: nowLiked, likeCount: newCount);
    state = AsyncValue.data(current.copyWith(posts: optimistic));

    try {
      final likeId = '${postId}_$anonId';
      final batch = FirebaseService.firestore.batch();
      final delta = nowLiked ? 1 : -1;
      if (nowLiked) {
        batch.set(
          FirebaseService.firestore.collection('post_likes').doc(likeId),
          {
            'postId': postId,
            'anonId': anonId,
            'likedAt': FieldValue.serverTimestamp(),
          },
        );
      } else {
        batch.delete(
            FirebaseService.firestore.collection('post_likes').doc(likeId));
      }
      // Update likeCount on the post itself
      batch.update(
        FirebaseService.firestore.collection('posts').doc(postId),
        {'likeCount': FieldValue.increment(delta)},
      );
      // Update totalLikeCount on the author's public profile
      if (post.authorId.isNotEmpty) {
        batch.update(
          FirebaseService.firestore
              .collection('public_profiles')
              .doc(post.authorId),
          {'totalLikeCount': FieldValue.increment(delta)},
        );
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[ForYouFeed] toggleLike failed, reverting: $e');
      final reverted = List<PostModel>.from(current.posts);
      reverted[idx] = post;
      state = AsyncValue.data(current.copyWith(posts: reverted));
    }
  }
}

final forYouFeedProvider =
AsyncNotifierProvider<ForYouFeedNotifier, FeedState>(
    ForYouFeedNotifier.new);

// ─── Following feed ───────────────────────────────────────────────────────────

class FollowingFeedNotifier extends AsyncNotifier<FeedState> {
  static const int _limit = 15;

  @override
  Future<FeedState> build() => _fetch();

  Future<FeedState> _fetch({DocumentSnapshot? after}) async {
    try {
      final ids = await ref.read(witnessingIdsProvider.future);
      if (ids.isEmpty) {
        return const FeedState(isLoading: false, hasMore: false);
      }

      var query = FirebaseService.firestore
          .collection('posts')
          .where('authorId', whereIn: ids)
          .orderBy('createdAt', descending: true)
          .limit(_limit);
      if (after != null) query = query.startAfterDocument(after);

      final snap = await query.get();
      final posts = await _enrich(snap.docs);
      final confessions =
      posts.where((p) => p.type == 'confession').toList();

      return FeedState(
        posts: confessions,
        isLoading: false,
        hasMore: snap.docs.length == _limit,
        lastDocument: snap.docs.isNotEmpty ? snap.docs.last : null,
      );
    } catch (e) {
      debugPrint('[FollowingFeed] $e');
      return const FeedState(isLoading: false, hasMore: false);
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = AsyncValue.data(await _fetch());
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null ||
        current.isLoadingMore ||
        !current.hasMore ||
        current.lastDocument == null) return;

    final ids = await ref.read(witnessingIdsProvider.future);
    if (ids.isEmpty) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));

    try {
      final snap = await FirebaseService.firestore
          .collection('posts')
          .where('authorId', whereIn: ids)
          .orderBy('createdAt', descending: true)
          .startAfterDocument(current.lastDocument!)
          .limit(_limit)
          .get();

      final more = await _enrich(snap.docs);
      final confessions =
      more.where((p) => p.type == 'confession').toList();

      state = AsyncValue.data(current.copyWith(
        posts: [...current.posts, ...confessions],
        isLoadingMore: false,
        hasMore: snap.docs.length == _limit,
        lastDocument:
        snap.docs.isNotEmpty ? snap.docs.last : current.lastDocument,
      ));
    } catch (e) {
      debugPrint('[FollowingFeed] loadMore: $e');
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> toggleLike(String postId) async {
    final anonId = LocalStorageService.getCachedAnonId();
    if (anonId == null) return;
    final current = state.value;
    if (current == null) return;

    final idx = current.posts.indexWhere((p) => p.postId == postId);
    if (idx == -1) return;
    final post = current.posts[idx];
    final nowLiked = !post.isLiked;
    final newCount = post.likeCount + (nowLiked ? 1 : -1);

    final optimistic = List<PostModel>.from(current.posts);
    optimistic[idx] = post.copyWith(isLiked: nowLiked, likeCount: newCount);
    state = AsyncValue.data(current.copyWith(posts: optimistic));

    try {
      final likeId = '${postId}_$anonId';
      final batch = FirebaseService.firestore.batch();
      final delta = nowLiked ? 1 : -1;
      if (nowLiked) {
        batch.set(
          FirebaseService.firestore.collection('post_likes').doc(likeId),
          {
            'postId': postId,
            'anonId': anonId,
            'likedAt': FieldValue.serverTimestamp(),
          },
        );
      } else {
        batch.delete(
            FirebaseService.firestore.collection('post_likes').doc(likeId));
      }
      // Update likeCount on the post itself
      batch.update(
        FirebaseService.firestore.collection('posts').doc(postId),
        {'likeCount': FieldValue.increment(delta)},
      );
      // Update totalLikeCount on the author's public profile
      if (post.authorId.isNotEmpty) {
        batch.update(
          FirebaseService.firestore
              .collection('public_profiles')
              .doc(post.authorId),
          {'totalLikeCount': FieldValue.increment(delta)},
        );
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[FollowingFeed] toggleLike reverted: $e');
      final reverted = List<PostModel>.from(current.posts);
      reverted[idx] = post;
      state = AsyncValue.data(current.copyWith(posts: reverted));
    }
  }
}

final followingFeedProvider =
AsyncNotifierProvider<FollowingFeedNotifier, FeedState>(
    FollowingFeedNotifier.new);

// ─── Create post ──────────────────────────────────────────────────────────────

class CreatePostNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  Future<bool> createConfession({
    required String heading,
    String? body,
    String? voiceNotePath,        // local file path from recorder
    int? voiceDurationSeconds,    // duration of voice note
  }) async {
    final anonId = LocalStorageService.getCachedAnonId();
    if (anonId == null) return false;
    state = true;

    try {
      // Upload voice note to Cloudinary if provided
      String? audioUrl;
      if (voiceNotePath != null) {
        try {
          audioUrl = await StorageService.instance.uploadAudio(
            localPath: voiceNotePath,
            anonId: anonId,
          );
        } catch (e) {
          debugPrint('[CreatePost] audio upload failed: $e');
          // fail hard — don't post without the voice note if one was recorded
          state = false;
          return false;
        }
      }

      await FirebaseService.firestore.collection('posts').doc().set({
        'type': 'confession',
        'authorId': anonId,
        'heading': heading.trim(),
        'body': (body != null && body.trim().isNotEmpty)
            ? body.trim()
            : null,
        'imageUrls': <String>[],  // M5: image upload added here
        'audioUrl': audioUrl,     // null when no voice note recorded
        'audioDuration': voiceDurationSeconds,
        'likeCount': 0,
        'commentCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseService.firestore
          .collection('public_profiles')
          .doc(anonId)
          .update({'totalPostCount': FieldValue.increment(1)});

      state = false;
      return true;
    } catch (e) {
      debugPrint('[CreatePost] $e');
      state = false;
      return false;
    }
  }
}

final createPostProvider =
NotifierProvider<CreatePostNotifier, bool>(CreatePostNotifier.new);

// ─── Enrichment helper ────────────────────────────────────────────────────────

Future<List<PostModel>> _enrich(List<QueryDocumentSnapshot> docs) async {
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
    debugPrint('[_enrich] profiles: $e');
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
      debugPrint('[_enrich] likes: $e');
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
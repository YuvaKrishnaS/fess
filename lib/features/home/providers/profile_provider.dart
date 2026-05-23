import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/post_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/local_storage_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'feed_provider.dart';

// ─── ProfileData ──────────────────────────────────────────────────────────────

class ProfileData {
  final String anonId;
  final String username;
  final Map<String, dynamic> avatarConfig;
  final int totalPostCount;
  final int totalLikeCount;
  final int totalTeaCount;

  const ProfileData({
    required this.anonId,
    required this.username,
    required this.avatarConfig,
    required this.totalPostCount,
    required this.totalLikeCount,
    required this.totalTeaCount,
  });

  factory ProfileData.fromMap(String anonId, Map<String, dynamic> data) {
    return ProfileData(
      anonId: anonId,
      username: data['username'] as String? ?? 'anon',
      avatarConfig: Map<String, dynamic>.from(
        (data['avatarConfig'] as Map?) ?? const {},
      ),
      totalPostCount: (data['totalPostCount'] as num?)?.toInt() ?? 0,
      totalLikeCount: (data['totalLikeCount'] as num?)?.toInt() ?? 0,
      totalTeaCount: (data['totalTeaCount'] as num?)?.toInt() ?? 0,
    );
  }
}

// ─── ProfileFeedState ─────────────────────────────────────────────────────────

class ProfileFeedState {
  final List<PostModel> posts;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final String? error;

  const ProfileFeedState({
    this.posts = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.lastDoc,
    this.error,
  });

  ProfileFeedState copyWith({
    List<PostModel>? posts,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    DocumentSnapshot<Map<String, dynamic>>? lastDoc,
    String? error,
  }) {
    return ProfileFeedState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      lastDoc: lastDoc ?? this.lastDoc,
      error: error ?? this.error,
    );
  }
}

// ─── currentAnonIdProvider (single source of truth) ──────────────────────────

// NOTE: Do NOT redeclare currentAnonIdProvider here if feed_provider.dart
// already exports it. This file imports it from there via 'feed_provider.dart'.
// If your project had a duplicate here, REMOVE this and only use the one from
// feed_provider.dart. Keeping one here only if feed_provider doesn't have it.

// ─── currentProfileProvider ───────────────────────────────────────────────────

final currentProfileProvider =
FutureProvider<ProfileData?>((ref) async {
  final anonId = await ref.watch(currentAnonIdProvider.future);
  if (anonId == null || anonId.isEmpty) return null;
  return ref.watch(profileDataProvider(anonId).future);
});

// ─── profileDataProvider ──────────────────────────────────────────────────────

final profileDataProvider =
FutureProvider.family<ProfileData?, String>((ref, anonId) async {
  if (anonId.isEmpty) return null;

  try {
    final doc = await FirebaseService.firestore
        .collection('public_profiles')
        .doc(anonId)
        .get();

    final data = doc.data();
    if (!doc.exists || data == null) return null;

    return ProfileData.fromMap(anonId, Map<String, dynamic>.from(data));
  } catch (e, st) {
    debugPrint('[profileDataProvider] error: $e');
    debugPrint('$st');
    return null;
  }
});

// ─── mySpillsProvider ─────────────────────────────────────────────────────────
// Uses ONLY where(authorId) + orderBy(createdAt), then filters type in Dart.
// This matches the existing Firestore index and mirrors forYouFeedProvider.

final mySpillsProvider =
FutureProvider.family<ProfileFeedState, String>((ref, anonId) async {
  if (anonId.isEmpty) {
    return const ProfileFeedState(isLoading: false, hasMore: false, posts: []);
  }

  try {
    debugPrint('[mySpillsProvider] querying for anonId=$anonId');

    final snap = await FirebaseService.firestore
        .collection('posts')
        .where('authorId', isEqualTo: anonId)
        .orderBy('createdAt', descending: true)
        .get();

    debugPrint('[mySpillsProvider] raw docs returned: ${snap.docs.length}');

    // Filter confession type in Dart — avoids needing compound index
    final confessionDocs =
    snap.docs.where((d) => d.data()['type'] == 'confession').toList();

    debugPrint(
        '[mySpillsProvider] confession docs after filter: ${confessionDocs.length}');

    final posts = await _enrichPosts(confessionDocs);

    return ProfileFeedState(
      posts: posts,
      isLoading: false,
      hasMore: false,
      lastDoc: confessionDocs.isNotEmpty ? confessionDocs.last : null,
    );
  } catch (e, st) {
    debugPrint('[mySpillsProvider] ERROR: $e');
    debugPrint('$st');
    return ProfileFeedState(
      isLoading: false,
      hasMore: false,
      error: 'Could not load spills: ${e.toString()}',
    );
  }
});

// ─── myTeaProvider ────────────────────────────────────────────────────────────
// Same safe pattern — where(authorId).orderBy(createdAt), filter type in Dart.

final myTeaProvider =
FutureProvider.family<ProfileFeedState, String>((ref, anonId) async {
  if (anonId.isEmpty) {
    return const ProfileFeedState(isLoading: false, hasMore: false, posts: []);
  }

  try {
    debugPrint('[myTeaProvider] querying for anonId=$anonId');

    final snap = await FirebaseService.firestore
        .collection('posts')
        .where('authorId', isEqualTo: anonId)
        .orderBy('createdAt', descending: true)
        .get();

    debugPrint('[myTeaProvider] raw docs returned: ${snap.docs.length}');

    // Filter tea type in Dart
    final teaDocs =
    snap.docs.where((d) => d.data()['type'] == 'tea').toList();

    debugPrint('[myTeaProvider] tea docs after filter: ${teaDocs.length}');

    final posts = await _enrichPosts(teaDocs);

    return ProfileFeedState(
      posts: posts,
      isLoading: false,
      hasMore: false,
      lastDoc: teaDocs.isNotEmpty ? teaDocs.last : null,
    );
  } catch (e, st) {
    debugPrint('[myTeaProvider] ERROR: $e');
    debugPrint('$st');
    return ProfileFeedState(
      isLoading: false,
      hasMore: false,
      error: 'Could not load tea: ${e.toString()}',
    );
  }
});

// ─── myLikedProvider (kept for backward compat, not used in new tabs) ─────────

final myLikedProvider =
FutureProvider.family<ProfileFeedState, String>((ref, anonId) async {
  if (anonId.isEmpty) {
    return const ProfileFeedState(isLoading: false, hasMore: false, posts: []);
  }

  try {
    final likeSnap = await FirebaseService.firestore
        .collection('post_likes')
        .where('anonId', isEqualTo: anonId)
        .orderBy('likedAt', descending: true)
        .get();

    if (likeSnap.docs.isEmpty) {
      return const ProfileFeedState(
          isLoading: false, hasMore: false, posts: []);
    }

    final postIds = likeSnap.docs
        .map((d) => d.data()['postId'] as String?)
        .whereType<String>()
        .toList();

    if (postIds.isEmpty) {
      return const ProfileFeedState(
          isLoading: false, hasMore: false, posts: []);
    }

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = [];
    for (var i = 0; i < postIds.length; i += 10) {
      final chunk =
      postIds.sublist(i, (i + 10).clamp(0, postIds.length));
      final snap = await FirebaseService.firestore
          .collection('posts')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      docs.addAll(snap.docs);
    }

    final enriched = await _enrichPosts(docs);
    final postMap = {for (final p in enriched) p.postId: p};
    final ordered =
    postIds.where(postMap.containsKey).map((id) => postMap[id]!).toList();

    return ProfileFeedState(
      posts: ordered,
      isLoading: false,
      hasMore: false,
      lastDoc:
      likeSnap.docs.isNotEmpty ? likeSnap.docs.last : null,
    );
  } catch (e, st) {
    debugPrint('[myLikedProvider] ERROR: $e');
    debugPrint('$st');
    return ProfileFeedState(
      isLoading: false,
      hasMore: false,
      error: 'Could not load liked posts: ${e.toString()}',
    );
  }
});

// ─── _enrichPosts helper ──────────────────────────────────────────────────────

Future<List<PostModel>> _enrichPosts(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    ) async {
  if (docs.isEmpty) return [];

  final posts = docs.map((d) => PostModel.fromFirestore(d)).toList();

  final authorIds = posts
      .map((p) => p.authorId)
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList();

  final Map<String, Map<String, dynamic>> profileMap = {};

  if (authorIds.isNotEmpty) {
    try {
      for (var i = 0; i < authorIds.length; i += 10) {
        final chunk =
        authorIds.sublist(i, (i + 10).clamp(0, authorIds.length));
        final snap = await FirebaseService.firestore
            .collection('public_profiles')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final d in snap.docs) {
          profileMap[d.id] = d.data();
        }
      }
    } catch (e) {
      debugPrint('[_enrichPosts] profiles error: $e');
    }
  }

  final anonId = LocalStorageService.getCachedAnonId();
  final Set<String> likedIds = {};

  if (anonId != null && anonId.isNotEmpty) {
    try {
      final checks = await Future.wait(
        posts.map(
              (p) => FirebaseService.firestore
              .collection('post_likes')
              .doc('${p.postId}_$anonId')
              .get(),
        ),
      );
      for (final d in checks) {
        if (d.exists) {
          final id = d.data()?['postId'] as String?;
          if (id != null) likedIds.add(id);
        }
      }
    } catch (e) {
      debugPrint('[_enrichPosts] likes error: $e');
    }
  }

  return posts.map((p) {
    final prof = profileMap[p.authorId];
    return p.copyWith(
      authorUsername: prof?['username'] as String?,
      authorAvatarConfig:
      prof?['avatarConfig'] as Map<String, dynamic>?,  // ← was commented out!
      isLiked: likedIds.contains(p.postId),
    );
  }).toList();
}

// ─── signOutProvider ──────────────────────────────────────────────────────────

final signOutProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    await ref.read(authServiceProvider).signOut();
    ref.invalidate(currentAnonIdProvider);
    ref.invalidate(currentProfileProvider);
    ref.invalidate(forYouFeedProvider);
    ref.invalidate(followingFeedProvider);
  };
});
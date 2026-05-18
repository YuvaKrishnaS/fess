import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/post_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/local_storage_service.dart';
import '../providers/feed_provider.dart';
// import 'package:flutter_riverpod/legacy.dart';

class ProfileData {
  final String anonId;
  final String username;
  final Map<String, dynamic> avatarConfig;
  final int totalPostCount;
  final int totalLikeCount;
  final int totalCommentCount;

  const ProfileData({
    required this.anonId,
    required this.username,
    required this.avatarConfig,
    required this.totalPostCount,
    required this.totalLikeCount,
    required this.totalCommentCount,
  });

  factory ProfileData.fromMap(String anonId, Map<String, dynamic> data) {
    return ProfileData(
      anonId: anonId,
      username: data['username'] as String? ?? 'anon',
      avatarConfig: (data['avatarConfig'] as Map<String, dynamic>?) ?? {},
      totalPostCount: (data['totalPostCount'] as int?) ?? 0,
      totalLikeCount: (data['totalLikeCount'] as int?) ?? 0,
      totalCommentCount: (data['totalCommentCount'] as int?) ?? 0,
    );
  }
}

final profileDataProvider =
FutureProvider.family<ProfileData?, String>((ref, anonId) async {
  if (anonId.isEmpty) return null;
  try {
    final doc = await FirebaseService.firestore
        .collection('publicProfiles')
        .doc(anonId)
        .get();

    if (!doc.exists || doc.data() == null) return null;
    return ProfileData.fromMap(anonId, doc.data()!);
  } catch (e) {
    debugPrint('profileDataProvider: $e');
    return null;
  }
});

class ProfileFeedState {
  final List<PostModel> posts;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final DocumentSnapshot? lastDoc;
  final String? error;

  const ProfileFeedState({
    this.posts = const [],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.lastDoc,
    this.error,
  });

  ProfileFeedState copyWith({
    List<PostModel>? posts,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    DocumentSnapshot? lastDoc,
    String? error,
    bool clearLastDoc = false,
    bool clearError = false,
  }) {
    return ProfileFeedState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      lastDoc: clearLastDoc ? null : (lastDoc ?? this.lastDoc),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class MySpillsNotifier extends FamilyAsyncNotifier<ProfileFeedState, String> {
  static const int _limit = 15;

  @override
  Future<ProfileFeedState> build(String anonId) async {
    return _fetchInitial(anonId);
  }

  Future<ProfileFeedState> _fetchInitial(String anonId) async {
    try {
      final snap = await FirebaseService.firestore
          .collection('posts')
          .where('authorId', isEqualTo: anonId)
          .where('type', isEqualTo: 'confession')
          .orderBy('createdAt', descending: true)
          .limit(_limit)
          .get();

      final posts = await _enrichPosts(snap.docs);

      return ProfileFeedState(
        posts: posts,
        isLoading: false,
        hasMore: snap.docs.length == _limit,
        lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
      );
    } catch (e) {
      debugPrint('MySpillsNotifier: $e');
      return const ProfileFeedState(
        isLoading: false,
        hasMore: false,
        error: 'Could not load spills.',
      );
    }
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null ||
        current.isLoadingMore ||
        !current.hasMore ||
        current.lastDoc == null) {
      return;
    }

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));

    try {
      final snap = await FirebaseService.firestore
          .collection('posts')
          .where('authorId', isEqualTo: arg)
          .where('type', isEqualTo: 'confession')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(current.lastDoc!)
          .limit(_limit)
          .get();

      final more = await _enrichPosts(snap.docs);

      state = AsyncValue.data(
        current.copyWith(
          posts: [...current.posts, ...more],
          isLoadingMore: false,
          hasMore: snap.docs.length == _limit,
          lastDoc: snap.docs.isNotEmpty ? snap.docs.last : current.lastDoc,
        ),
      );
    } catch (e) {
      debugPrint('MySpillsNotifier loadMore: $e');
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }
}

final mySpillsProvider = AsyncNotifierProvider.family<MySpillsNotifier,
    ProfileFeedState, String>(MySpillsNotifier.new);

class MyTeaNotifier extends FamilyAsyncNotifier<ProfileFeedState, String> {
  static const int _limit = 15;

  @override
  Future<ProfileFeedState> build(String anonId) async {
    return _fetchInitial(anonId);
  }

  Future<ProfileFeedState> _fetchInitial(String anonId) async {
    try {
      final snap = await FirebaseService.firestore
          .collection('posts')
          .where('authorId', isEqualTo: anonId)
          .where('type', isEqualTo: 'tea')
          .orderBy('createdAt', descending: true)
          .limit(_limit)
          .get();

      final posts = await _enrichPosts(snap.docs);

      return ProfileFeedState(
        posts: posts,
        isLoading: false,
        hasMore: snap.docs.length == _limit,
        lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
      );
    } catch (e) {
      debugPrint('MyTeaNotifier: $e');
      return const ProfileFeedState(
        isLoading: false,
        hasMore: false,
        error: 'Could not load tea.',
      );
    }
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null ||
        current.isLoadingMore ||
        !current.hasMore ||
        current.lastDoc == null) {
      return;
    }

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));

    try {
      final snap = await FirebaseService.firestore
          .collection('posts')
          .where('authorId', isEqualTo: arg)
          .where('type', isEqualTo: 'tea')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(current.lastDoc!)
          .limit(_limit)
          .get();

      final more = await _enrichPosts(snap.docs);

      state = AsyncValue.data(
        current.copyWith(
          posts: [...current.posts, ...more],
          isLoadingMore: false,
          hasMore: snap.docs.length == _limit,
          lastDoc: snap.docs.isNotEmpty ? snap.docs.last : current.lastDoc,
        ),
      );
    } catch (e) {
      debugPrint('MyTeaNotifier loadMore: $e');
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }
}

final myTeaProvider = AsyncNotifierProvider.family<MyTeaNotifier,
    ProfileFeedState, String>(MyTeaNotifier.new);

class MyLikedNotifier extends FamilyAsyncNotifier<ProfileFeedState, String> {
  static const int _limit = 15;

  @override
  Future<ProfileFeedState> build(String anonId) async {
    return _fetchInitial(anonId);
  }

  Future<ProfileFeedState> _fetchInitial(String anonId) async {
    try {
      final likeSnap = await FirebaseService.firestore
          .collection('postlikes')
          .where('anonId', isEqualTo: anonId)
          .orderBy('likedAt', descending: true)
          .limit(_limit)
          .get();

      if (likeSnap.docs.isEmpty) {
        return const ProfileFeedState(
          isLoading: false,
          hasMore: false,
          posts: [],
        );
      }

      final postIds = likeSnap.docs
          .map((d) => d.data()['postId'] as String?)
          .whereType<String>()
          .toList();

      if (postIds.isEmpty) {
        return const ProfileFeedState(
          isLoading: false,
          hasMore: false,
          posts: [],
        );
      }

      final postSnap = await FirebaseService.firestore
          .collection('posts')
          .where(FieldPath.documentId, whereIn: postIds)
          .get();

      final enriched = await _enrichPosts(postSnap.docs);

      final postMap = {for (final p in enriched) p.postId: p};
      final ordered = postIds
          .where(postMap.containsKey)
          .map((id) => postMap[id]!)
          .toList();

      return ProfileFeedState(
        posts: ordered,
        isLoading: false,
        hasMore: likeSnap.docs.length == _limit,
        lastDoc: likeSnap.docs.isNotEmpty ? likeSnap.docs.last : null,
      );
    } catch (e) {
      debugPrint('MyLikedNotifier: $e');
      return const ProfileFeedState(
        isLoading: false,
        hasMore: false,
        error: 'Could not load liked posts.',
      );
    }
  }
}

final myLikedProvider = AsyncNotifierProvider.family<MyLikedNotifier,
    ProfileFeedState, String>(MyLikedNotifier.new);

Future<List<PostModel>> _enrichPosts(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    ) async {
  if (docs.isEmpty) return [];

  final posts = docs.map((d) => PostModel.fromFirestore(d)).toList();

  final authorIds = posts
      .map((p) => p.authorId)
      .whereType<String>()
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList();

  Map<String, Map<String, dynamic>> profileMap = {};

  if (authorIds.isNotEmpty) {
    try {
      for (var i = 0; i < authorIds.length; i += 30) {
        final end = (i + 30 > authorIds.length) ? authorIds.length : i + 30;
        final chunk = authorIds.sublist(i, end);

        final snap = await FirebaseService.firestore
            .collection('publicprofiles')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final d in snap.docs) {
          profileMap[d.id] = d.data();
        }
      }
    } catch (e) {
      debugPrint('_enrichPosts profiles: $e');
    }
  }

  final anonId = LocalStorageService.getCachedAnonId();
  final likedIds = <String>{};

  if (anonId != null && anonId.isNotEmpty) {
    try {
      final checks = await Future.wait(
        posts.map(
              (p) => FirebaseService.firestore
              .collection('postlikes')
              .doc('${p.postId}$anonId')
              .get(),
        ),
      );

      for (final d in checks) {
        if (d.exists) {
          final id = d.data()?['postId'] as String?;
          if (id != null && id.isNotEmpty) likedIds.add(id);
        }
      }
    } catch (e) {
      debugPrint('_enrichPosts likes: $e');
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

final signOutProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    await FirebaseService.auth.signOut();
    await LocalStorageService.clearUserData();
    ref.invalidate(currentAnonIdProvider);
    ref.invalidate(currentProfileProvider);
  };
});
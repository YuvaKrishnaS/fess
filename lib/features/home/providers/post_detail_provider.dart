// ignore_for_file: unused_field

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/models/comment_model.dart';
import '../../../core/models/post_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/local_storage_service.dart';

class PostDetailState {
  final PostModel? post;
  final List<CommentModel> comments;
  final bool isLoadingPost;
  final bool isLoadingComments;
  final bool isSubmitting;
  final String? error;

  const PostDetailState({
    this.post,
    this.comments = const [],
    this.isLoadingPost = true,
    this.isLoadingComments = true,
    this.isSubmitting = false,
    this.error,
  });

  PostDetailState copyWith({
    PostModel? post,
    List<CommentModel>? comments,
    bool? isLoadingPost,
    bool? isLoadingComments,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
  }) =>
      PostDetailState(
        post: post ?? this.post,
        comments: comments ?? this.comments,
        isLoadingPost: isLoadingPost ?? this.isLoadingPost,
        isLoadingComments: isLoadingComments ?? this.isLoadingComments,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        error: clearError ? null : (error ?? this.error),
      );
}

class PostDetailNotifier extends StateNotifier<PostDetailState> {
  final String postId;
  final Ref _ref;

  StreamSubscription<DocumentSnapshot>? _postSub;
  StreamSubscription<QuerySnapshot>? _commentSub;

  PostDetailNotifier(this.postId, this._ref)
      : super(const PostDetailState()) {
    _listenToPost();
    _listenToComments();
  }

  @override
  void dispose() {
    _postSub?.cancel();
    _commentSub?.cancel();
    super.dispose();
  }

  void _listenToPost() {
    _postSub = FirebaseService.firestore
        .collection('posts')
        .doc(postId)
        .snapshots()
        .listen(
          (snap) async {
        if (!snap.exists) {
          state = state.copyWith(isLoadingPost: false, error: 'Post not found.');
          return;
        }
        final post = PostModel.fromFirestore(snap);
        final enriched = await _enrichPost(post);
        if (mounted) state = state.copyWith(post: enriched, isLoadingPost: false);
      },
      onError: (e) {
        debugPrint('[PostDetail] post stream error: $e');
        state = state.copyWith(isLoadingPost: false, error: 'Could not load post.');
      },
    );
  }

  void _listenToComments() {
    _commentSub = FirebaseService.firestore
        .collection('post_comments')
        .where('postId', isEqualTo: postId)
        .orderBy('createdAt', descending: false)
        .limit(100)
        .snapshots()
        .listen(
          (snap) async {
        final raw = snap.docs.map(CommentModel.fromFirestore).toList();
        final enriched = await _enrichComments(raw);
        if (mounted) {
          state = state.copyWith(
            comments: enriched,
            isLoadingComments: false,
          );
        }
      },
      onError: (e) {
        debugPrint('[PostDetail] comments stream error: $e');
        state = state.copyWith(isLoadingComments: false);
      },
    );
  }

  Future<PostModel> _enrichPost(PostModel post) async {
    final anonId = LocalStorageService.getCachedAnonId();
    try {
      final profileDoc = await FirebaseService.firestore
          .collection('public_profiles')
          .doc(post.authorId)
          .get();
      final data = profileDoc.data();

      bool isLiked = false;
      if (anonId != null) {
        final likeDoc = await FirebaseService.firestore
            .collection('post_likes')
            .doc('${post.postId}_$anonId')
            .get();
        isLiked = likeDoc.exists;
      }

      return post.copyWith(
        authorUsername: data?['username'] as String?,
        authorAvatarConfig: data?['avatarConfig'] as Map<String, dynamic>?,
        isLiked: isLiked,
      );
    } catch (e) {
      debugPrint('[PostDetail] enrich post error: $e');
      return post;
    }
  }

  Future<List<CommentModel>> _enrichComments(List<CommentModel> comments) async {
    if (comments.isEmpty) return [];
    final anonId = LocalStorageService.getCachedAnonId();

    final authorIds = comments.map((c) => c.authorId).toSet().toList();
    final Map<String, Map<String, dynamic>> profileMap = {};
    try {
      for (var i = 0; i < authorIds.length; i += 30) {
        final chunk = authorIds.sublist(i, (i + 30).clamp(0, authorIds.length));
        final snaps = await FirebaseService.firestore
            .collection('public_profiles')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final d in snaps.docs) {
          profileMap[d.id] = d.data();
        }
      }
    } catch (e) {
      debugPrint('[PostDetail] enrich profiles error: $e');
    }

    final Set<String> likedCommentIds = {};
    if (anonId != null && comments.isNotEmpty) {
      try {
        final likeChecks = await Future.wait(
          comments.map((c) => FirebaseService.firestore
              .collection('comment_likes')
              .doc('${c.commentId}_$anonId')
              .get()),
        );
        for (int i = 0; i < likeChecks.length; i++) {
          if (likeChecks[i].exists) {
            likedCommentIds.add(comments[i].commentId);
          }
        }
      } catch (e) {
        debugPrint('[PostDetail] enrich comment likes error: $e');
      }
    }

    return comments.map((c) {
      final prof = profileMap[c.authorId];
      return c.copyWith(
        authorUsername: prof?['username'] as String?,
        authorAvatarConfig: prof?['avatarConfig'] as Map<String, dynamic>?,
        isLiked: likedCommentIds.contains(c.commentId),
      );
    }).toList();
  }

  Future<void> togglePostLike() async {
    final anonId = LocalStorageService.getCachedAnonId();
    final post = state.post;
    if (anonId == null || post == null) return;

    final nowLiked = !post.isLiked;
    final newCount = (post.likeCount + (nowLiked ? 1 : -1)).clamp(0, 999999);
    state = state.copyWith(post: post.copyWith(isLiked: nowLiked, likeCount: newCount));

    try {
      final likeId = '${post.postId}_$anonId';
      final batch = FirebaseService.firestore.batch();
      if (nowLiked) {
        batch.set(
          FirebaseService.firestore.collection('post_likes').doc(likeId),
          {'postId': post.postId, 'anonId': anonId, 'likedAt': FieldValue.serverTimestamp()},
        );
        batch.update(
          FirebaseService.firestore.collection('posts').doc(post.postId),
          {'likeCount': FieldValue.increment(1)},
        );
      } else {
        batch.delete(FirebaseService.firestore.collection('post_likes').doc(likeId));
        batch.update(
          FirebaseService.firestore.collection('posts').doc(post.postId),
          {'likeCount': FieldValue.increment(-1)},
        );
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[PostDetail] togglePostLike failed, reverting: $e');
      state = state.copyWith(post: post);
    }
  }

  Future<bool> addComment(String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return false;
    final anonId = LocalStorageService.getCachedAnonId();
    final post = state.post;
    if (anonId == null || post == null) return false;

    state = state.copyWith(isSubmitting: true);

    try {
      final commentRef = FirebaseService.firestore.collection('post_comments').doc();
      final batch = FirebaseService.firestore.batch();
      batch.set(commentRef, {
        'postId': post.postId,
        'authorId': anonId,
        'body': trimmed,
        'likeCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(
        FirebaseService.firestore.collection('posts').doc(post.postId),
        {'commentCount': FieldValue.increment(1)},
      );
      await batch.commit();
      if (mounted) state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      debugPrint('[PostDetail] addComment failed: $e');
      if (mounted) state = state.copyWith(isSubmitting: false, error: 'Failed to post comment.');
      return false;
    }
  }

  Future<void> toggleCommentLike(String commentId) async {
    final anonId = LocalStorageService.getCachedAnonId();
    if (anonId == null) return;

    final idx = state.comments.indexWhere((c) => c.commentId == commentId);
    if (idx == -1) return;
    final comment = state.comments[idx];
    final nowLiked = !comment.isLiked;
    final newCount = (comment.likeCount + (nowLiked ? 1 : -1)).clamp(0, 999999);

    final optimistic = List<CommentModel>.from(state.comments);
    optimistic[idx] = comment.copyWith(isLiked: nowLiked, likeCount: newCount);
    state = state.copyWith(comments: optimistic);

    try {
      final likeId = '${commentId}_$anonId';
      final batch = FirebaseService.firestore.batch();
      if (nowLiked) {
        batch.set(
          FirebaseService.firestore.collection('comment_likes').doc(likeId),
          {'commentId': commentId, 'anonId': anonId, 'likedAt': FieldValue.serverTimestamp()},
        );
        batch.update(
          FirebaseService.firestore.collection('post_comments').doc(commentId),
          {'likeCount': FieldValue.increment(1)},
        );
      } else {
        batch.delete(FirebaseService.firestore.collection('comment_likes').doc(likeId));
        batch.update(
          FirebaseService.firestore.collection('post_comments').doc(commentId),
          {'likeCount': FieldValue.increment(-1)},
        );
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[PostDetail] toggleCommentLike failed, reverting: $e');
      final reverted = List<CommentModel>.from(state.comments);
      reverted[idx] = comment;
      state = state.copyWith(comments: reverted);
    }
  }
}

final postDetailProvider = StateNotifierProvider.family<
    PostDetailNotifier, PostDetailState, String>(
      (ref, postId) => PostDetailNotifier(postId, ref),
);
import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String commentId;
  final String postId;
  final String authorId;
  final String body;
  final int likeCount;
  final DateTime? createdAt;
  final String? authorUsername;
  final Map<String, dynamic>? authorAvatarConfig;
  final bool isLiked;
  final bool isOptimistic;

  const CommentModel({
    required this.commentId,
    required this.postId,
    required this.authorId,
    required this.body,
    required this.likeCount,
    this.createdAt,
    this.authorUsername,
    this.authorAvatarConfig,
    this.isLiked = false,
    this.isOptimistic = false,
  });

  factory CommentModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CommentModel(
      commentId: doc.id,
      postId: d['postId'] as String? ?? '',
      authorId: d['authorId'] as String? ?? '',
      body: d['body'] as String? ?? '',
      likeCount: (d['likeCount'] as num?)?.toInt() ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  CommentModel copyWith({
    String? commentId,
    String? postId,
    String? authorId,
    String? body,
    int? likeCount,
    DateTime? createdAt,
    String? authorUsername,
    Map<String, dynamic>? authorAvatarConfig,
    bool? isLiked,
    bool? isOptimistic,
  }) =>
      CommentModel(
        commentId: commentId ?? this.commentId,
        postId: postId ?? this.postId,
        authorId: authorId ?? this.authorId,
        body: body ?? this.body,
        likeCount: likeCount ?? this.likeCount,
        createdAt: createdAt ?? this.createdAt,
        authorUsername: authorUsername ?? this.authorUsername,
        authorAvatarConfig: authorAvatarConfig ?? this.authorAvatarConfig,
        isLiked: isLiked ?? this.isLiked,
        isOptimistic: isOptimistic ?? this.isOptimistic,
      );
}
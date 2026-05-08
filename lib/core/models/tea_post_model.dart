import 'package:cloud_firestore/cloud_firestore.dart';

class TeaPost {
  final String postId;
  final String authorId;
  final String authorUsername;
  final Map<String, dynamic> authorAvatarConfig;
  final String heading;
  final String audioUrl;
  final int audioDurationSeconds;
  final int likeCount;
  final int commentCount;
  final bool isLikedByMe;
  final DateTime createdAt;

  const TeaPost({
    required this.postId,
    required this.authorId,
    required this.authorUsername,
    required this.authorAvatarConfig,
    required this.heading,
    required this.audioUrl,
    required this.audioDurationSeconds,
    required this.likeCount,
    required this.commentCount,
    required this.isLikedByMe,
    required this.createdAt,
  });

  TeaPost copyWith({
    int? likeCount,
    bool? isLikedByMe,
    int? commentCount,
  }) =>
      TeaPost(
        postId: postId,
        authorId: authorId,
        authorUsername: authorUsername,
        authorAvatarConfig: authorAvatarConfig,
        heading: heading,
        audioUrl: audioUrl,
        audioDurationSeconds: audioDurationSeconds,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        isLikedByMe: isLikedByMe ?? this.isLikedByMe,
        createdAt: createdAt,
      );

  factory TeaPost.fromFirestore(
      DocumentSnapshot doc,
      Map<String, dynamic> profile,
      bool isLiked,
      ) {
    final d = doc.data() as Map<String, dynamic>;
    return TeaPost(
      postId: doc.id,
      authorId: d['authorId'] as String? ?? '',
      authorUsername: profile['username'] as String? ?? 'anonymous',
      authorAvatarConfig:
      profile['avatarConfig'] as Map<String, dynamic>? ?? {},
      heading: d['heading'] as String? ?? '',
      audioUrl: d['audioUrl'] as String? ?? '',
      audioDurationSeconds: (d['audioDuration'] as num?)?.toInt() ?? 0,
      likeCount: (d['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (d['commentCount'] as num?)?.toInt() ?? 0,
      isLikedByMe: isLiked,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String postId;
  final String type; // 'confession' | 'tea'
  final String authorId;
  final String heading;
  final String? body;
  final List<String> imageUrls; // M5: populated then
  final String? audioUrl;
  final int? audioDuration;
  final int likeCount;
  final int commentCount;
  final DateTime? createdAt;

  // Enriched client-side (not stored in post doc)
  final String? authorUsername;
  final Map<String, dynamic>? authorAvatarConfig;
  final bool isLiked;

  const PostModel({
    required this.postId,
    required this.type,
    required this.authorId,
    required this.heading,
    this.body,
    this.imageUrls = const [],
    this.audioUrl,
    this.audioDuration,
    required this.likeCount,
    required this.commentCount,
    this.createdAt,
    this.authorUsername,
    this.authorAvatarConfig,
    this.isLiked = false,
  });

  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PostModel(
      postId: doc.id,
      type: data['type'] as String? ?? 'confession',
      authorId: data['authorId'] as String? ?? '',
      heading: data['heading'] as String? ?? '',
      body: data['body'] as String?,
      imageUrls: (data['imageUrls'] as List?)?.cast<String>() ?? [],
      audioUrl: data['audioUrl'] as String?,
      audioDuration: data['audioDuration'] as int?,
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  PostModel copyWith({
    String? authorUsername,
    Map<String, dynamic>? authorAvatarConfig,
    bool? isLiked,
    int? likeCount,
    int? commentCount,
  }) =>
      PostModel(
        postId: postId,
        type: type,
        authorId: authorId,
        heading: heading,
        body: body,
        imageUrls: imageUrls,
        audioUrl: audioUrl,
        audioDuration: audioDuration,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        createdAt: createdAt,
        authorUsername: authorUsername ?? this.authorUsername,
        authorAvatarConfig: authorAvatarConfig ?? this.authorAvatarConfig,
        isLiked: isLiked ?? this.isLiked,
      );
}
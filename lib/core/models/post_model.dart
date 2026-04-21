import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String postId;
  final String type; // 'confession' | 'tea'
  final String authorId; // anonId
  final String heading;
  final String? body;
  final List<String> imageUrls;
  final String? audioUrl;
  final int? audioDuration; // seconds
  final int likeCount;
  final int commentCount;
  final DateTime createdAt;

  // Local-only (not in Firestore)
  final bool isLiked;
  final String? authorUsername;
  final Map<String, dynamic>? authorAvatarConfig;

  const PostModel({
    required this.postId,
    required this.type,
    required this.authorId,
    required this.heading,
    this.body,
    this.imageUrls = const [],
    this.audioUrl,
    this.audioDuration,
    this.likeCount = 0,
    this.commentCount = 0,
    required this.createdAt,
    this.isLiked = false,
    this.authorUsername,
    this.authorAvatarConfig,
  });

  PostModel copyWith({
    String? postId,
    String? type,
    String? authorId,
    String? heading,
    String? body,
    List<String>? imageUrls,
    String? audioUrl,
    int? audioDuration,
    int? likeCount,
    int? commentCount,
    DateTime? createdAt,
    bool? isLiked,
    String? authorUsername,
    Map<String, dynamic>? authorAvatarConfig,
  }) {
    return PostModel(
      postId: postId ?? this.postId,
      type: type ?? this.type,
      authorId: authorId ?? this.authorId,
      heading: heading ?? this.heading,
      body: body ?? this.body,
      imageUrls: imageUrls ?? this.imageUrls,
      audioUrl: audioUrl ?? this.audioUrl,
      audioDuration: audioDuration ?? this.audioDuration,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt ?? this.createdAt,
      isLiked: isLiked ?? this.isLiked,
      authorUsername: authorUsername ?? this.authorUsername,
      authorAvatarConfig: authorAvatarConfig ?? this.authorAvatarConfig,
    );
  }

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
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'authorId': authorId,
      'heading': heading,
      'body': body,
      'imageUrls': imageUrls,
      'audioUrl': audioUrl,
      'audioDuration': audioDuration,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
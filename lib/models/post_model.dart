import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String id;
  final String userId;
  final String? caption;
  final String? imageUrl;
  final List<String> hashtags;
  final DateTime? scheduledTime;
  final DateTime? postedAt;
  final PostStatus status;
  final Map<String, dynamic>? analytics;
  final String? mood;
  final String? tone;

  PostModel({
    required this.id,
    required this.userId,
    this.caption,
    this.imageUrl,
    this.hashtags = const [],
    this.scheduledTime,
    this.postedAt,
    this.status = PostStatus.draft,
    this.analytics,
    this.mood,
    this.tone,
  });

  factory PostModel.fromFirestore(Map<String, dynamic> data, String id) {
    return PostModel(
      id: id,
      userId: data['userId'] ?? '',
      caption: data['caption'],
      imageUrl: data['imageUrl'],
      hashtags: List<String>.from(data['hashtags'] ?? []),
      scheduledTime: (data['scheduledTime'] as Timestamp?)?.toDate(),
      postedAt: (data['postedAt'] as Timestamp?)?.toDate(),
      status: PostStatus.values.firstWhere(
        (s) => s.name == (data['status'] ?? 'draft'),
        orElse: () => PostStatus.draft,
      ),
      analytics: data['analytics'],
      mood: data['mood'],
      tone: data['tone'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'caption': caption,
      'imageUrl': imageUrl,
      'hashtags': hashtags,
      'scheduledTime': scheduledTime != null
          ? Timestamp.fromDate(scheduledTime!)
          : null,
      'postedAt': postedAt != null ? Timestamp.fromDate(postedAt!) : null,
      'status': status.name,
      'analytics': analytics,
      'mood': mood,
      'tone': tone,
    };
  }
}

enum PostStatus {
  draft,
  scheduled,
  posted,
  failed,
}


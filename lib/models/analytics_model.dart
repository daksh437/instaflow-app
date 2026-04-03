import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyticsModel {
  final String userId;
  final int followers;
  final int following;
  final int posts;
  final double engagementRate;
  final int totalReach;
  final int totalLikes;
  final int totalComments;
  final Map<String, int> bestPostingTimes;
  final List<PostPerformance> topPosts;
  final DateTime lastUpdated;

  AnalyticsModel({
    required this.userId,
    this.followers = 0,
    this.following = 0,
    this.posts = 0,
    this.engagementRate = 0.0,
    this.totalReach = 0,
    this.totalLikes = 0,
    this.totalComments = 0,
    this.bestPostingTimes = const {},
    this.topPosts = const [],
    required this.lastUpdated,
  });

  factory AnalyticsModel.fromFirestore(Map<String, dynamic> data) {
    return AnalyticsModel(
      userId: data['userId'] ?? '',
      followers: data['followers'] ?? 0,
      following: data['following'] ?? 0,
      posts: data['posts'] ?? 0,
      engagementRate: (data['engagementRate'] ?? 0.0).toDouble(),
      totalReach: data['totalReach'] ?? 0,
      totalLikes: data['totalLikes'] ?? 0,
      totalComments: data['totalComments'] ?? 0,
      bestPostingTimes: Map<String, int>.from(data['bestPostingTimes'] ?? {}),
      topPosts: (data['topPosts'] as List<dynamic>?)
              ?.map((e) => PostPerformance.fromMap(e))
              .toList() ??
          [],
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'followers': followers,
      'following': following,
      'posts': posts,
      'engagementRate': engagementRate,
      'totalReach': totalReach,
      'totalLikes': totalLikes,
      'totalComments': totalComments,
      'bestPostingTimes': bestPostingTimes,
      'topPosts': topPosts.map((p) => p.toMap()).toList(),
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }
}

class PostPerformance {
  final String postId;
  final int likes;
  final int comments;
  final int reach;
  final DateTime postedAt;

  PostPerformance({
    required this.postId,
    this.likes = 0,
    this.comments = 0,
    this.reach = 0,
    required this.postedAt,
  });

  factory PostPerformance.fromMap(Map<String, dynamic> map) {
    return PostPerformance(
      postId: map['postId'] ?? '',
      likes: map['likes'] ?? 0,
      comments: map['comments'] ?? 0,
      reach: map['reach'] ?? 0,
      postedAt: (map['postedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'likes': likes,
      'comments': comments,
      'reach': reach,
      'postedAt': Timestamp.fromDate(postedAt),
    };
  }
}


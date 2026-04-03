import 'package:cloud_firestore/cloud_firestore.dart';

/// Enhanced Stats Model for comprehensive analytics
class StatsModel {
  final String userId;
  final int followers;
  final int following;
  final int profileViews;
  final int reach7Days;
  final double engagementRate;
  final int totalLikes;
  final int totalComments;
  final int totalSaves;
  final int totalShares;
  final int posts;
  final List<FollowerGrowthData> followerGrowth;
  final List<PostPerformanceData> topPosts;
  final EngagementStats engagementStats;
  final ProfileHealthScore healthScore;
  final DateTime lastUpdated;

  StatsModel({
    required this.userId,
    this.followers = 0,
    this.following = 0,
    this.profileViews = 0,
    this.reach7Days = 0,
    this.engagementRate = 0.0,
    this.totalLikes = 0,
    this.totalComments = 0,
    this.totalSaves = 0,
    this.totalShares = 0,
    this.posts = 0,
    this.followerGrowth = const [],
    this.topPosts = const [],
    required this.engagementStats,
    required this.healthScore,
    required this.lastUpdated,
  });

  factory StatsModel.fromFirestore(Map<String, dynamic> data) {
    return StatsModel(
      userId: data['userId'] ?? '',
      followers: data['followers'] ?? 0,
      following: data['following'] ?? 0,
      profileViews: data['profileViews'] ?? 0,
      reach7Days: data['reach7Days'] ?? 0,
      engagementRate: (data['engagementRate'] ?? 0.0).toDouble(),
      totalLikes: data['totalLikes'] ?? 0,
      totalComments: data['totalComments'] ?? 0,
      totalSaves: data['totalSaves'] ?? 0,
      totalShares: data['totalShares'] ?? 0,
      posts: data['posts'] ?? 0,
      followerGrowth: (data['followerGrowth'] as List<dynamic>?)
              ?.map((e) => FollowerGrowthData.fromMap(e))
              .toList() ??
          [],
      topPosts: (data['topPosts'] as List<dynamic>?)
              ?.map((e) => PostPerformanceData.fromMap(e))
              .toList() ??
          [],
      engagementStats: EngagementStats.fromMap(data['engagementStats'] ?? {}),
      healthScore: ProfileHealthScore.fromMap(data['healthScore'] ?? {}),
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'followers': followers,
      'following': following,
      'profileViews': profileViews,
      'reach7Days': reach7Days,
      'engagementRate': engagementRate,
      'totalLikes': totalLikes,
      'totalComments': totalComments,
      'totalSaves': totalSaves,
      'totalShares': totalShares,
      'posts': posts,
      'followerGrowth': followerGrowth.map((f) => f.toMap()).toList(),
      'topPosts': topPosts.map((p) => p.toMap()).toList(),
      'engagementStats': engagementStats.toMap(),
      'healthScore': healthScore.toMap(),
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  /// Calculate follower change today
  int get followerChangeToday {
    if (followerGrowth.isEmpty) return 0;
    final today = DateTime.now();
    final todayData = followerGrowth.firstWhere(
      (f) => f.date.year == today.year &&
          f.date.month == today.month &&
          f.date.day == today.day,
      orElse: () => FollowerGrowthData(date: today, count: followers),
    );
    if (followerGrowth.length < 2) return 0;
    final yesterdayData = followerGrowth[1];
    return todayData.count - yesterdayData.count;
  }
}

/// Follower growth data point
class FollowerGrowthData {
  final DateTime date;
  final int count;

  FollowerGrowthData({
    required this.date,
    required this.count,
  });

  factory FollowerGrowthData.fromMap(Map<String, dynamic> map) {
    return FollowerGrowthData(
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      count: map['count'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'count': count,
    };
  }
}

/// Enhanced post performance data
class PostPerformanceData {
  final String postId;
  final String? thumbnailUrl;
  final String? caption;
  final int likes;
  final int comments;
  final int saves;
  final int shares;
  final int views;
  final int reach;
  final DateTime postedAt;
  final double engagementScore;

  PostPerformanceData({
    required this.postId,
    this.thumbnailUrl,
    this.caption,
    this.likes = 0,
    this.comments = 0,
    this.saves = 0,
    this.shares = 0,
    this.views = 0,
    this.reach = 0,
    required this.postedAt,
  }) : engagementScore = _calculateEngagementScore(likes, comments, saves, shares, reach);

  static double _calculateEngagementScore(
    int likes,
    int comments,
    int saves,
    int shares,
    int reach,
  ) {
    if (reach == 0) return 0.0;
    final engagement = (likes * 1.0 + comments * 2.0 + saves * 3.0 + shares * 4.0);
    return (engagement / reach * 100);
  }

  factory PostPerformanceData.fromMap(Map<String, dynamic> map) {
    return PostPerformanceData(
      postId: map['postId'] ?? '',
      thumbnailUrl: map['thumbnailUrl'],
      caption: map['caption'],
      likes: map['likes'] ?? 0,
      comments: map['comments'] ?? 0,
      saves: map['saves'] ?? 0,
      shares: map['shares'] ?? 0,
      views: map['views'] ?? 0,
      reach: map['reach'] ?? 0,
      postedAt: (map['postedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'thumbnailUrl': thumbnailUrl,
      'caption': caption,
      'likes': likes,
      'comments': comments,
      'saves': saves,
      'shares': shares,
      'views': views,
      'reach': reach,
      'postedAt': Timestamp.fromDate(postedAt),
    };
  }

  /// Get why this post performed well (AI-generated insight)
  String get performanceInsight {
    if (engagementScore > 10) {
      return 'Exceptional engagement! Your content resonated strongly with your audience.';
    } else if (engagementScore > 5) {
      return 'Great performance! Strong interaction rates show your content is engaging.';
    } else if (engagementScore > 2) {
      return 'Good performance. Try similar content styles to maintain engagement.';
    } else {
      return 'Room for improvement. Experiment with different content types or posting times.';
    }
  }
}

/// Engagement statistics
class EngagementStats {
  final double averageEngagementRate;
  final int likes7Days;
  final int comments7Days;
  final int saves7Days;
  final int shares7Days;

  EngagementStats({
    this.averageEngagementRate = 0.0,
    this.likes7Days = 0,
    this.comments7Days = 0,
    this.saves7Days = 0,
    this.shares7Days = 0,
  });

  factory EngagementStats.fromMap(Map<String, dynamic> map) {
    return EngagementStats(
      averageEngagementRate: (map['averageEngagementRate'] ?? 0.0).toDouble(),
      likes7Days: map['likes7Days'] ?? 0,
      comments7Days: map['comments7Days'] ?? 0,
      saves7Days: map['saves7Days'] ?? 0,
      shares7Days: map['shares7Days'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'averageEngagementRate': averageEngagementRate,
      'likes7Days': likes7Days,
      'comments7Days': comments7Days,
      'saves7Days': saves7Days,
      'shares7Days': shares7Days,
    };
  }
}

/// Profile health score with sub-metrics
class ProfileHealthScore {
  final int overallScore;
  final int consistencyScore;
  final int engagementScore;
  final int profileOptimizationScore;
  final int hashtagScore;
  final int followerQualityScore;

  ProfileHealthScore({
    this.overallScore = 0,
    this.consistencyScore = 0,
    this.engagementScore = 0,
    this.profileOptimizationScore = 0,
    this.hashtagScore = 0,
    this.followerQualityScore = 0,
  });

  factory ProfileHealthScore.fromMap(Map<String, dynamic> map) {
    return ProfileHealthScore(
      overallScore: map['overallScore'] ?? 0,
      consistencyScore: map['consistencyScore'] ?? 0,
      engagementScore: map['engagementScore'] ?? 0,
      profileOptimizationScore: map['profileOptimizationScore'] ?? 0,
      hashtagScore: map['hashtagScore'] ?? 0,
      followerQualityScore: map['followerQualityScore'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'overallScore': overallScore,
      'consistencyScore': consistencyScore,
      'engagementScore': engagementScore,
      'profileOptimizationScore': profileOptimizationScore,
      'hashtagScore': hashtagScore,
      'followerQualityScore': followerQualityScore,
    };
  }

  List<String> get improvementTips {
    final tips = <String>[];
    if (consistencyScore < 70) {
      tips.add('Post more consistently - aim for 3-5 times per week');
    }
    if (engagementScore < 70) {
      tips.add('Engage with your audience - reply to comments and DMs');
    }
    if (profileOptimizationScore < 70) {
      tips.add('Optimize your profile - add a compelling bio and profile picture');
    }
    if (hashtagScore < 70) {
      tips.add('Use relevant hashtags - mix popular and niche tags');
    }
    if (followerQualityScore < 70) {
      tips.add('Focus on quality content to attract engaged followers');
    }
    if (tips.isEmpty) {
      tips.add('Great job! Keep up the excellent work');
    }
    return tips;
  }
}

/// AI suggestion for growth
class AISuggestion {
  final String type;
  final String suggestion;
  final String? action;

  AISuggestion({
    required this.type,
    required this.suggestion,
    this.action,
  });

  factory AISuggestion.fromMap(Map<String, dynamic> map) {
    return AISuggestion(
      type: map['type'] ?? '',
      suggestion: map['suggestion'] ?? '',
      action: map['action'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'suggestion': suggestion,
      'action': action,
    };
  }
}


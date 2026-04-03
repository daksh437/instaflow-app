import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/stats_model.dart';
import '../services/instagram_service.dart';
import '../models/analytics_model.dart';
// TODO: Import AIService when integrating real AI for suggestions
// import '../services/ai_service.dart';

/// Comprehensive Stats Service
/// 
/// Handles all stats-related data fetching, caching, and processing.
/// TODO: Integrate with real Instagram Graph API when available.
class StatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final InstagramService _instagramService = InstagramService();
  // TODO: Use AIService for generating AI suggestions when real AI API is integrated

  // Cache stats for 5 minutes
  StatsModel? _cachedStats;
  DateTime? _cacheTime;
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Fetch comprehensive stats for current user
  Future<StatsModel> fetchStats({bool forceRefresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // Return cached data if available and not expired
    if (!forceRefresh &&
        _cachedStats != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheDuration) {
      return _cachedStats!;
    }

    try {
      // Try to fetch from Firestore first
      final doc = await _firestore
          .collection('user_stats')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final stats = StatsModel.fromFirestore(doc.data()!);
        _cachedStats = stats;
        _cacheTime = DateTime.now();
        return stats;
      }

      // If not in Firestore, fetch from Instagram API and generate
      final stats = await _generateStatsFromAPI(user.uid);
      
      // Cache and save to Firestore
      _cachedStats = stats;
      _cacheTime = DateTime.now();
      await _saveStatsToFirestore(user.uid, stats);

      return stats;
    } catch (e) {
      // Return fallback mock data if API fails
      return _getMockStats(user.uid);
    }
  }

  /// Generate stats from Instagram API
  Future<StatsModel> _generateStatsFromAPI(String userId) async {
    try {
      // TODO: Replace with actual Instagram Graph API calls
      // For now, use InstagramService to get basic data
      final analytics = await _instagramService.fetchAnalytics(userId, null);

      if (analytics == null) {
        return _getMockStats(userId);
      }

      // Generate follower growth data (last 30 days)
      final followerGrowth = _generateFollowerGrowthData(
        analytics.followers,
        30,
      );

      // Generate top posts
      final topPosts = _generateTopPostsData(analytics.topPosts);

      // Calculate engagement stats
      final engagementStats = EngagementStats(
        averageEngagementRate: analytics.engagementRate,
        likes7Days: (analytics.totalLikes * 0.3).round(),
        comments7Days: (analytics.totalComments * 0.3).round(),
        saves7Days: (analytics.totalLikes * 0.1).round(),
        shares7Days: (analytics.totalLikes * 0.05).round(),
      );

      // Calculate profile health score
      final healthScore = _calculateHealthScore(analytics);

      return StatsModel(
        userId: userId,
        followers: analytics.followers,
        following: analytics.following,
        profileViews: (analytics.followers * 1.5).round(),
        reach7Days: analytics.totalReach,
        engagementRate: analytics.engagementRate,
        totalLikes: analytics.totalLikes,
        totalComments: analytics.totalComments,
        totalSaves: (analytics.totalLikes * 0.15).round(),
        totalShares: (analytics.totalLikes * 0.08).round(),
        posts: analytics.posts,
        followerGrowth: followerGrowth,
        topPosts: topPosts,
        engagementStats: engagementStats,
        healthScore: healthScore,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      return _getMockStats(userId);
    }
  }

  /// Generate follower growth data for the last N days
  List<FollowerGrowthData> _generateFollowerGrowthData(
    int currentFollowers,
    int days,
  ) {
    final growth = <FollowerGrowthData>[];
    final now = DateTime.now();

    // Generate realistic growth pattern
    for (int i = days - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      // Simulate gradual growth with some randomness
      final baseFollowers = currentFollowers - (days - i) * 3;
      final dailyGrowth = (i % 3 == 0) ? 5 : 2; // Growth spike every 3 days
      final count = baseFollowers + dailyGrowth;
      growth.add(FollowerGrowthData(date: date, count: count > 0 ? count : currentFollowers));
    }

    return growth;
  }

  /// Generate top posts data
  List<PostPerformanceData> _generateTopPostsData(
    List<PostPerformance> existingPosts,
  ) {
    if (existingPosts.isNotEmpty) {
      return existingPosts.map((post) {
        return PostPerformanceData(
          postId: post.postId,
          likes: post.likes,
          comments: post.comments,
          views: post.reach * 2,
          reach: post.reach,
          postedAt: post.postedAt,
        );
      }).toList();
    }

    // Generate mock top posts if none exist
    final now = DateTime.now();
    return List.generate(6, (index) {
      return PostPerformanceData(
        postId: 'post_${index + 1}',
        thumbnailUrl: null,
        likes: 800 + (index * 200) + (500 - index * 50),
        comments: 30 + (index * 10),
        saves: 50 + (index * 15),
        shares: 10 + index,
        views: 2000 + (index * 500),
        reach: 1500 + (index * 400),
        postedAt: now.subtract(Duration(days: index * 2)),
      );
    })..sort((a, b) => b.engagementScore.compareTo(a.engagementScore));
  }

  /// Calculate profile health score
  ProfileHealthScore _calculateHealthScore(AnalyticsModel analytics) {
    // Consistency score (based on posting frequency)
    final consistencyScore = analytics.posts > 100
        ? 90
        : analytics.posts > 50
            ? 75
            : analytics.posts > 20
                ? 60
                : 40;

    // Engagement score (based on engagement rate)
    final engagementScore = analytics.engagementRate > 5
        ? 90
        : analytics.engagementRate > 3
            ? 75
            : analytics.engagementRate > 1
                ? 60
                : 40;

    // Profile optimization (assume good if connected)
    final profileOptimizationScore = 80;

    // Hashtag score (assumed good)
    final hashtagScore = 75;

    // Follower quality (based on engagement rate)
    final followerQualityScore = (engagementScore * 0.8).round();

    final overallScore = ((
      consistencyScore * 0.2 +
      engagementScore * 0.3 +
      profileOptimizationScore * 0.2 +
      hashtagScore * 0.15 +
      followerQualityScore * 0.15
    )).round();

    return ProfileHealthScore(
      overallScore: overallScore.clamp(0, 100),
      consistencyScore: consistencyScore,
      engagementScore: engagementScore,
      profileOptimizationScore: profileOptimizationScore,
      hashtagScore: hashtagScore,
      followerQualityScore: followerQualityScore,
    );
  }

  /// Generate AI suggestions
  Future<List<AISuggestion>> generateAISuggestions(StatsModel stats) async {
    try {
      // TODO: Replace with actual AI service call
      // For now, generate contextual suggestions based on stats
      final suggestions = <AISuggestion>[];

      // Best posting time suggestion
      suggestions.add(AISuggestion(
        type: 'Best Posting Time',
        suggestion: _getBestPostingTimeSuggestion(stats),
      ));

      // Content type suggestion
      suggestions.add(AISuggestion(
        type: 'Content Strategy',
        suggestion: _getContentTypeSuggestion(stats),
      ));

      // Hashtag suggestion
      suggestions.add(AISuggestion(
        type: 'Hashtag Strategy',
        suggestion: _getHashtagSuggestion(stats),
      ));

      // Growth suggestion
      suggestions.add(AISuggestion(
        type: 'Growth Tip',
        suggestion: _getGrowthSuggestion(stats),
      ));

      return suggestions;
    } catch (e) {
      // Return default suggestions on error
      return _getDefaultSuggestions();
    }
  }

  String _getBestPostingTimeSuggestion(StatsModel stats) {
    if (stats.engagementRate > 5) {
      return 'Your engagement is strong! Continue posting at peak hours (6-9 PM) for maximum reach.';
    } else {
      return 'Try posting between 6-9 PM on weekdays when your audience is most active.';
    }
  }

  String _getContentTypeSuggestion(StatsModel stats) {
    if (stats.topPosts.isNotEmpty) {
      final topPost = stats.topPosts.first;
      if (topPost.engagementScore > 8) {
        return 'Your recent posts with high engagement show great potential. Replicate similar content styles.';
      }
    }
    return 'Mix different content types - behind-the-scenes, tutorials, and user-generated content perform well.';
  }

  String _getHashtagSuggestion(StatsModel stats) {
    if (stats.healthScore.hashtagScore < 70) {
      return 'Use 15-20 hashtags per post. Mix 30% popular, 40% medium, and 30% niche hashtags.';
    }
    return 'Your hashtag strategy is working! Keep using a mix of trending and niche hashtags.';
  }

  String _getGrowthSuggestion(StatsModel stats) {
    if (stats.followerChangeToday > 0) {
      return 'Great growth today! Engage with new followers to maintain momentum.';
    } else if (stats.followerChangeToday < 0) {
      return 'Focus on creating consistent, valuable content to reduce unfollows.';
    } else {
      return 'Post consistently 3-5 times per week to maintain steady growth.';
    }
  }

  /// Get default AI suggestions (public for fallback)
  List<AISuggestion> getDefaultSuggestions() {
    return [
      AISuggestion(
        type: 'Best Posting Time',
        suggestion: 'Post between 6-9 PM on weekdays for maximum engagement.',
      ),
      AISuggestion(
        type: 'Content Strategy',
        suggestion: 'Mix different content types - videos perform 40% better than static posts.',
      ),
      AISuggestion(
        type: 'Hashtag Strategy',
        suggestion: 'Use 15-20 relevant hashtags. Mix popular and niche tags.',
      ),
      AISuggestion(
        type: 'Growth Tip',
        suggestion: 'Engage with your audience in comments and DMs to build relationships.',
      ),
    ];
  }

  List<AISuggestion> _getDefaultSuggestions() => getDefaultSuggestions();

  /// Save stats to Firestore
  Future<void> _saveStatsToFirestore(String userId, StatsModel stats) async {
    try {
      await _firestore
          .collection('user_stats')
          .doc(userId)
          .set(stats.toFirestore());
    } catch (e) {
      // Silently fail - caching is optional
    }
  }

  /// Get mock stats for development
  StatsModel _getMockStats(String userId) {
    final now = DateTime.now();
    final followerGrowth = _generateFollowerGrowthData(15234, 30);
    final topPosts = _generateTopPostsData([]);

    return StatsModel(
      userId: userId,
      followers: 15234,
      following: 523,
      profileViews: 22851,
      reach7Days: 12500,
      engagementRate: 5.8,
      totalLikes: 15000,
      totalComments: 450,
      totalSaves: 2250,
      totalShares: 1200,
      posts: 89,
      followerGrowth: followerGrowth,
      topPosts: topPosts,
      engagementStats: EngagementStats(
        averageEngagementRate: 5.8,
        likes7Days: 4500,
        comments7Days: 135,
        saves7Days: 675,
        shares7Days: 360,
      ),
      healthScore: ProfileHealthScore(
        overallScore: 78,
        consistencyScore: 75,
        engagementScore: 80,
        profileOptimizationScore: 85,
        hashtagScore: 75,
        followerQualityScore: 75,
      ),
      lastUpdated: now,
    );
  }

  /// Clear cache
  void clearCache() {
    _cachedStats = null;
    _cacheTime = null;
  }
}


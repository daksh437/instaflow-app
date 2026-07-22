import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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

  static const int _defaultGrowthDays = 30;

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[StatsService] $message');
    }
  }

  Future<StatsSnapshot> buildSnapshotFromLiveData({
    required String userId,
    required int followers,
    required int following,
    required int mediaCount,
    required int reach,
    required int impressions,
    required int profileViews,
    required List<PostPerformanceData> topPosts,
    required bool forceRefresh,
  }) async {
    final stats = StatsModel(
      userId: userId,
      followers: followers,
      following: following,
      profileViews: profileViews,
      reach7Days: reach > 0 ? reach : impressions,
      engagementRate: _calculateEngagementRate(followers, topPosts),
      totalLikes: topPosts.fold<int>(0, (sum, post) => sum + post.likes),
      totalComments: topPosts.fold<int>(0, (sum, post) => sum + post.comments),
      totalSaves: topPosts.fold<int>(0, (sum, post) => sum + post.saves),
      totalShares: topPosts.fold<int>(0, (sum, post) => sum + post.shares),
      posts: mediaCount,
      followerGrowth: _generateFollowerGrowthData(followers, _defaultGrowthDays),
      topPosts: topPosts,
      engagementStats: _buildEngagementFromPosts(topPosts),
      healthScore: _calculateHealthScoreFromTopPosts(
        followers: followers,
        posts: mediaCount,
        topPosts: topPosts,
      ),
      lastUpdated: DateTime.now(),
    );

    _cachedStats = stats;
    _cacheTime = DateTime.now();

    if (!forceRefresh) {
      final cached = await _tryLoadFirestoreSnapshot(userId);
      if (cached != null && _isFresh(cached.lastUpdated, _cacheDuration)) {
        _log('Returning firestore cached snapshot');
        return StatsSnapshot(
          stats: cached,
          source: StatsDataSource.cache,
          fetchedAt: DateTime.now(),
        );
      }
    }

    await _saveStatsToFirestore(userId, stats);
    _log('Returning live snapshot');
    return StatsSnapshot(
      stats: stats,
      source: StatsDataSource.live,
      fetchedAt: DateTime.now(),
    );
  }

  Future<StatsSnapshot> fallbackSnapshot({
    required String userId,
    required String reason,
  }) async {
    _log('Fallback requested: $reason');
    throw StatsException(
      'Live stats are currently unavailable. Please check connection and try again.',
      code: StatsErrorCode.liveUnavailable,
    );
  }

  Future<StatsModel?> _tryLoadFirestoreSnapshot(String userId) async {
    try {
      final doc = await _firestore.collection('user_stats').doc(userId).get();
      if (!doc.exists) return null;
      final raw = doc.data();
      if (raw == null) return null;
      return StatsModel.fromFirestore(raw);
    } catch (_) {
      return null;
    }
  }

  bool _isFresh(DateTime time, Duration window) {
    return DateTime.now().difference(time) < window;
  }

  double _calculateEngagementRate(int followers, List<PostPerformanceData> topPosts) {
    if (followers <= 0 || topPosts.isEmpty) return 0;
    final totalEngagement = topPosts.fold<int>(
      0,
      (sum, post) => sum + post.likes + (post.comments * 2) + (post.saves * 3) + (post.shares * 4),
    );
    return ((totalEngagement / topPosts.length) / followers * 100).clamp(0.0, 100.0);
  }

  EngagementStats _buildEngagementFromPosts(List<PostPerformanceData> topPosts) {
    final likes = topPosts.fold<int>(0, (sum, post) => sum + post.likes);
    final comments = topPosts.fold<int>(0, (sum, post) => sum + post.comments);
    final saves = topPosts.fold<int>(0, (sum, post) => sum + post.saves);
    final shares = topPosts.fold<int>(0, (sum, post) => sum + post.shares);
    final avgScore = topPosts.isEmpty
        ? 0.0
        : topPosts.fold<double>(0.0, (sum, post) => sum + post.engagementScore) / topPosts.length;
    return EngagementStats(
      averageEngagementRate: avgScore,
      likes7Days: likes,
      comments7Days: comments,
      saves7Days: saves,
      shares7Days: shares,
    );
  }

  ProfileHealthScore _calculateHealthScoreFromTopPosts({
    required int followers,
    required int posts,
    required List<PostPerformanceData> topPosts,
  }) {
    final avgEngagement = _calculateEngagementRate(followers, topPosts);
    final consistencyScore = posts > 100 ? 90 : posts > 50 ? 75 : posts > 20 ? 60 : 40;
    final engagementScore = avgEngagement > 5 ? 90 : avgEngagement > 3 ? 75 : avgEngagement > 1 ? 60 : 40;
    const profileOptimizationScore = 80;
    const hashtagScore = 75;
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

  /// Fetch comprehensive stats for current user
  Future<StatsModel> fetchStats({bool forceRefresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // Return cached data if available and not expired
    final cached = _cachedStats;
    final cachedAt = _cacheTime;
    if (!forceRefresh &&
        cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _cacheDuration) {
      return cached;
    }

    try {
      // Try to fetch from Firestore first
      final doc = await _firestore
          .collection('user_stats')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final raw = doc.data();
        if (raw == null) {
          throw Exception('Stats data unavailable');
        }
        final stats = StatsModel.fromFirestore(raw);
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
      throw StatsException(
        'Unable to fetch Instagram live stats. Please reconnect Instagram and retry.',
        code: StatsErrorCode.liveUnavailable,
      );
    }
  }

  /// Generate stats from Instagram API
  Future<StatsModel> _generateStatsFromAPI(String userId) async {
    try {
      // TODO: Replace with actual Instagram Graph API calls
      // For now, use InstagramService to get basic data
      final analytics = await _instagramService.fetchAnalytics(userId, null);

      if (analytics == null) {
        throw StatsException(
          'Instagram analytics data unavailable',
          code: StatsErrorCode.liveUnavailable,
        );
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
      if (e is StatsException) rethrow;
      throw StatsException(
        'Failed to generate stats from Instagram API.',
        code: StatsErrorCode.liveUnavailable,
      );
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

    return <PostPerformanceData>[];
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

  /// Clear cache
  void clearCache() {
    _cachedStats = null;
    _cacheTime = null;
  }
}

enum StatsDataSource {
  live,
  cache,
  fallback,
}

class StatsSnapshot {
  final StatsModel stats;
  final StatsDataSource source;
  final DateTime fetchedAt;
  final String? warning;

  const StatsSnapshot({
    required this.stats,
    required this.source,
    required this.fetchedAt,
    this.warning,
  });
}

enum StatsErrorCode {
  liveUnavailable,
}

class StatsException implements Exception {
  final String message;
  final StatsErrorCode code;

  const StatsException(this.message, {this.code = StatsErrorCode.liveUnavailable});

  @override
  String toString() => message;
}


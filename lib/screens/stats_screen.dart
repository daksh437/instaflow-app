import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/main_navigation_wrapper.dart';
import '../services/stats_service.dart';
import '../models/stats_model.dart';
import '../widgets/stats/insight_card.dart';
import '../widgets/stats/follower_growth_chart.dart';
import '../widgets/stats/engagement_metrics_card.dart';
import '../widgets/stats/best_performing_content.dart';
import '../widgets/stats/profile_health_score.dart';
import '../widgets/stats/ai_suggestions_box.dart';
import '../widgets/stats/skeleton_loader.dart';

/// Redesigned Premium Stats Dashboard Screen
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final StatsService _statsService = StatsService();
  StatsModel? _stats;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats({bool forceRefresh = false}) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'Please login to view stats';
          _isLoading = false;
        });
        return;
      }

      final stats = await _statsService.fetchStats(forceRefresh: forceRefresh);
      if (!mounted) return;

      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load stats. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _showPostDetails(PostPerformanceData post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PostDetailsBottomSheet(post: post),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  @override
  Widget build(BuildContext context) {
    return MainNavigationWrapper(
      currentIndex: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: _isLoading
            ? const StatsSkeletonLoader()
            : _errorMessage != null
                ? _buildErrorState()
                : _stats == null
                    ? _buildEmptyState()
                    : _buildStatsContent(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Something went wrong',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _loadStats(forceRefresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B2CBF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'No stats available',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _loadStats(forceRefresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Load Stats'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B2CBF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsContent() {
    final stats = _stats!;
    final followerChange = stats.followerChangeToday;

    return RefreshIndicator(
      onRefresh: () => _loadStats(forceRefresh: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Stats',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Instagram Analytics Dashboard',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => _loadStats(forceRefresh: true),
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Top Insight Cards
            Row(
              children: [
                Expanded(
                  child: InsightCard(
                    title: 'Followers',
                    value: _formatNumber(stats.followers),
                    icon: Icons.people_rounded,
                    change: followerChange,
                    changeLabel: 'Today',
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InsightCard(
                    title: 'Following',
                    value: _formatNumber(stats.following),
                    icon: Icons.person_add_rounded,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF9D4EDD), Color(0xFFC77DFF)],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InsightCard(
                    title: 'Profile Views',
                    value: _formatNumber(stats.profileViews),
                    icon: Icons.remove_red_eye_rounded,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFC77DFF), Color(0xFF9D4EDD)],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InsightCard(
                    title: 'Reach (7-day)',
                    value: _formatNumber(stats.reach7Days),
                    icon: Icons.trending_up_rounded,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7B2CBF), Color(0xFFC77DFF)],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Followers Growth Chart
            FollowerGrowthChart(
              growthData: stats.followerGrowth,
              selectedDays: 7,
            ),
            const SizedBox(height: 24),

            // Engagement Insights
            EngagementMetricsCard(
              engagementStats: stats.engagementStats,
            ),
            const SizedBox(height: 24),

            // Best Performing Content
            BestPerformingContent(
              topPosts: stats.topPosts,
              onTap: _showPostDetails,
            ),
            const SizedBox(height: 24),

            // Profile Health Score
            ProfileHealthScoreWidget(
              healthScore: stats.healthScore,
            ),
            const SizedBox(height: 24),

            // AI Suggestions
            AISuggestionsBox(
              stats: stats,
              statsService: _statsService,
            ),
            const SizedBox(height: 24),

            // Last Updated Info
            Center(
              child: Text(
                'Last updated: ${_formatLastUpdated(stats.lastUpdated)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  String _formatLastUpdated(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

/// Post details bottom sheet
class _PostDetailsBottomSheet extends StatelessWidget {
  final PostPerformanceData post;

  const _PostDetailsBottomSheet({required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Post Performance',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          // Metrics grid
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  icon: Icons.favorite,
                  label: 'Likes',
                  value: _formatNumber(post.likes),
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  icon: Icons.comment,
                  label: 'Comments',
                  value: _formatNumber(post.comments),
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  icon: Icons.bookmark,
                  label: 'Saves',
                  value: _formatNumber(post.saves),
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  icon: Icons.share,
                  label: 'Shares',
                  value: _formatNumber(post.shares),
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  icon: Icons.visibility,
                  label: 'Views',
                  value: _formatNumber(post.views),
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  icon: Icons.trending_up,
                  label: 'Engagement',
                  value: '${post.engagementScore.toStringAsFixed(1)}%',
                  color: const Color(0xFF7B2CBF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Performance Insight',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              post.performanceInsight,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'What to do next',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildNextSteps(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildNextSteps() {
    final suggestions = <String>[
      if (post.engagementScore > 8)
        'Replicate this content style - it resonates with your audience'
      else if (post.engagementScore > 5)
        'Try similar posting times and content themes'
      else
        'Experiment with different content formats or posting times',
      'Engage with comments to boost visibility',
      'Use similar hashtags for consistency',
    ];

    return Column(
      children: suggestions.map((suggestion) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: Color(0xFF7B2CBF),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    suggestion,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          )).toList(),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

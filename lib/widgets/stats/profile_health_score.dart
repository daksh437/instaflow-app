import 'package:flutter/material.dart';
import '../../models/stats_model.dart';

/// Profile health score circular indicator
class ProfileHealthScoreWidget extends StatelessWidget {
  final ProfileHealthScore healthScore;

  const ProfileHealthScoreWidget({
    super.key,
    required this.healthScore,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = healthScore.overallScore / 100;
    final color = _getScoreColor(healthScore.overallScore);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Profile Health Score',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background circle
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[100],
                  ),
                ),
                // Progress circle
                SizedBox(
                  width: 180,
                  height: 180,
                  child: CircularProgressIndicator(
                    value: percentage,
                    strokeWidth: 12,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                // Score text
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${healthScore.overallScore}',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      '/ 100',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Sub-metrics
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SubMetricItem(
                label: 'Consistency',
                score: healthScore.consistencyScore,
              ),
              _SubMetricItem(
                label: 'Engagement',
                score: healthScore.engagementScore,
              ),
              _SubMetricItem(
                label: 'Profile',
                score: healthScore.profileOptimizationScore,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SubMetricItem(
                label: 'Hashtags',
                score: healthScore.hashtagScore,
              ),
              _SubMetricItem(
                label: 'Follower Q',
                score: healthScore.followerQualityScore,
              ),
              const SizedBox(width: 80), // Spacer for alignment
            ],
          ),
          const SizedBox(height: 24),
          // Improvement tips
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lightbulb, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Improvement Tips',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...healthScore.improvementTips.map((tip) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(fontSize: 14)),
                          Expanded(
                            child: Text(
                              tip,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }
}

class _SubMetricItem extends StatelessWidget {
  final String label;
  final int score;

  const _SubMetricItem({
    required this.label,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    final color = score >= 70 ? Colors.green : score >= 50 ? Colors.orange : Colors.red;
    return Column(
      children: [
        Text(
          '$score',
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
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}


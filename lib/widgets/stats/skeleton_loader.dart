import 'package:flutter/material.dart';

/// Skeleton loader for stats cards
class StatsSkeletonLoader extends StatelessWidget {
  const StatsSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Top insight cards skeleton
          Row(
            children: [
              Expanded(child: _SkeletonCard()),
              const SizedBox(width: 12),
              Expanded(child: _SkeletonCard()),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _SkeletonCard()),
              const SizedBox(width: 12),
              Expanded(child: _SkeletonCard()),
            ],
          ),
          const SizedBox(height: 24),
          // Chart skeleton
          _SkeletonBox(height: 280),
          const SizedBox(height: 24),
          // Engagement metrics skeleton
          _SkeletonBox(height: 200),
          const SizedBox(height: 24),
          // Profile health score skeleton
          _SkeletonBox(height: 400),
          const SizedBox(height: 24),
          // AI suggestions skeleton
          _SkeletonBox(height: 250),
        ],
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 60,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 80,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double height;

  const _SkeletonBox({required this.height});

  @override
  Widget build(BuildContext context) {
    // Fixed height for bottom area so Column never needs unbounded constraints
    final remainingHeight = height - 20 - 20 - 16 - 20; // header, padding top/bottom, spacing
    return Container(
      height: height,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 150,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: remainingHeight > 0 ? remainingHeight : 100,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


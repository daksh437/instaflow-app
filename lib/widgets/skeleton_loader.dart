import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Professional skeleton loader widget for AI responses
class SkeletonLoader extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const SkeletonLoader({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: (Colors.grey[300] ?? Colors.grey),
      highlightColor: (Colors.grey[100] ?? Colors.grey),
      child: Container(
        width: width ?? double.infinity,
        height: height ?? 20,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
      ),
    );
  }
}

/// Skeleton loader for AI text response
class AITextSkeleton extends StatelessWidget {
  final int lines;
  final double lineHeight;

  const AITextSkeleton({
    super.key,
    this.lines = 4,
    this.lineHeight = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(
        lines,
        (index) => Padding(
          padding: EdgeInsets.only(
            bottom: index == lines - 1 ? 0 : 12,
          ),
          child: SkeletonLoader(
            height: lineHeight,
            width: index == lines - 1 ? 200 : double.infinity,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

/// Skeleton loader for card content
class CardSkeleton extends StatelessWidget {
  const CardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (Colors.grey[200] ?? Colors.grey)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLoader(height: 20, width: 150),
          const SizedBox(height: 12),
          const AITextSkeleton(lines: 3, lineHeight: 14),
          const SizedBox(height: 16),
          SkeletonLoader(height: 40, borderRadius: BorderRadius.circular(8)),
        ],
      ),
    );
  }
}


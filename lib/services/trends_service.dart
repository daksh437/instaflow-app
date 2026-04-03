import 'dart:math';
import 'package:flutter/foundation.dart';

/// Fetches trend keywords from safe sources. Uses mock list; can be replaced with Google Trends API later.
class TrendsService {
  /// Mock trending keywords (safe, generic). In production, replace with Google Trends API or your backend.
  static const List<String> _mockTrendKeywords = [
    'day in my life',
    'get ready with me',
    'morning routine',
    'productivity tips',
    'mindset shift',
    'behind the scenes',
    'before and after',
    'tutorial',
    'tips and tricks',
    'storytime',
    'challenge',
    'trending sound',
    'relatable',
    'hot take',
    'unpopular opinion',
    'life hack',
    'routine',
    'vlog',
    'transformation',
    'motivation',
  ];

  /// Returns a list of trend keywords for today. Uses date seed so same day gets same order.
  Future<List<String>> getTrendKeywords({int limit = 10}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final seed = DateTime.now().year * 10000 + DateTime.now().month * 100 + DateTime.now().day;
    final shuffled = List<String>.from(_mockTrendKeywords)
      ..shuffle(Random(seed));
    return shuffled.take(limit).toList();
  }

  /// Single trend for today (e.g. for default drop). Deterministic per day.
  Future<String> getTodayTrendKeyword() async {
    final list = await getTrendKeywords(limit: 1);
    return list.isNotEmpty ? list.first : _mockTrendKeywords.first;
  }
}

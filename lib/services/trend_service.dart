import 'dart:math';

/// Safe trend keywords by niche. Static rotating lists, no scraping. Rotates by date hash.
class TrendService {
  TrendService._();
  static const Map<String, List<String>> _nicheTrends = {
    'fitness': [
      'morning routine',
      'workout at home',
      'no equipment',
      'stretch routine',
      'protein tips',
      'before and after',
      'form check',
      'motivation',
    ],
    'cooking': [
      '5 min recipe',
      'one pan',
      'meal prep',
      'healthy swap',
      'kitchen hack',
      'quick dinner',
      'baking fail',
      'taste test',
    ],
    'productivity': [
      'day in my life',
      'morning routine',
      'time blocking',
      'notion tour',
      'focus tips',
      'no phone',
      'deep work',
      'habit stack',
    ],
    'beauty': [
      'get ready with me',
      'skincare routine',
      'makeup tutorial',
      'drugstore dupes',
      'before after',
      'get unready',
      'quick look',
      'hack',
    ],
    'lifestyle': [
      'day in my life',
      'vlog',
      'routine',
      'room tour',
      'favorites',
      'challenge',
      'trending sound',
      'relatable',
    ],
    'business': [
      'side hustle',
      'tips for creators',
      'mindset',
      'productivity',
      'tools I use',
      'behind the scenes',
      'advice',
      'lesson learned',
    ],
  };

  static const List<String> _defaultTrends = [
    'day in my life',
    'get ready with me',
    'morning routine',
    'tips and tricks',
    'before and after',
    'trending sound',
    'challenge',
    'relatable',
    'storytime',
    'tutorial',
  ];

  /// Returns trend keywords for the given niche, rotated by date hash. Same day = same order.
  static List<String> getTrendsForNiche(String niche, {int limit = 10}) {
    final key = niche.trim().toLowerCase();
    final list = _nicheTrends[key] ?? _defaultTrends;
    final seed = _dateSeed();
    final shuffled = List<String>.from(list)..shuffle(Random(seed));
    return shuffled.take(limit).toList();
  }

  /// Single trend for today (deterministic by date).
  static String getTodayTrend(String niche) {
    final trends = getTrendsForNiche(niche, limit: 1);
    return trends.isNotEmpty ? trends.first : _defaultTrends.first;
  }

  static int _dateSeed() {
    final now = DateTime.now();
    return now.year * 10000 + now.month * 100 + now.day;
  }
}

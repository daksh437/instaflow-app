import 'package:cloud_firestore/cloud_firestore.dart';

/// AI-generated daily viral reel plan: theme, concept, shot plan, hooks, caption, CTA, hashtags, best time.
class DailyViralDropModel {
  final String trendTheme;
  final String reelConcept;
  final List<String> shotPlan; // 5 steps
  final List<String> hooks;    // 5 hooks
  final String caption;
  final String cta;
  final List<String> hashtags;
  final String bestPostTime;

  const DailyViralDropModel({
    required this.trendTheme,
    required this.reelConcept,
    required this.shotPlan,
    required this.hooks,
    required this.caption,
    required this.cta,
    required this.hashtags,
    required this.bestPostTime,
  });

  /// Coach summary for voice playback (concise overview).
  String get coachSummary {
    final steps = shotPlan.take(3).join(' Then ');
    return 'Today\'s trend: $trendTheme. Concept: $reelConcept. '
        'Shot plan: $steps. Best time to post: $bestPostTime. CTA: $cta';
  }

  Map<String, dynamic> toMap() {
    return {
      'trendTheme': trendTheme,
      'reelConcept': reelConcept,
      'shotPlan': shotPlan,
      'hooks': hooks,
      'caption': caption,
      'cta': cta,
      'hashtags': hashtags,
      'bestPostTime': bestPostTime,
    };
  }

  factory DailyViralDropModel.fromMap(Map<String, dynamic> map) {
    return DailyViralDropModel(
      trendTheme: (map['trendTheme'] ?? '').toString(),
      reelConcept: (map['reelConcept'] ?? '').toString(),
      shotPlan: _toStringList(map['shotPlan']),
      hooks: _toStringList(map['hooks']),
      caption: (map['caption'] ?? '').toString(),
      cta: (map['cta'] ?? '').toString(),
      hashtags: _toStringList(map['hashtags']),
      bestPostTime: (map['bestPostTime'] ?? '').toString(),
    );
  }

  static List<String> _toStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    }
    return [];
  }
}

/// Firestore cache entry: one drop per user per date.
class DailyViralDropCacheEntry {
  final String userId;
  final String dateKey; // yyyy-MM-dd
  final DailyViralDropModel drop;
  final DateTime createdAt;
  final String? trendKeyword;

  const DailyViralDropCacheEntry({
    required this.userId,
    required this.dateKey,
    required this.drop,
    required this.createdAt,
    this.trendKeyword,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'dateKey': dateKey,
      'drop': drop.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      if (trendKeyword != null) 'trendKeyword': trendKeyword,
    };
  }

  factory DailyViralDropCacheEntry.fromFirestore(Map<String, dynamic> data) {
    final dropMap = data['drop'];
    return DailyViralDropCacheEntry(
      userId: (data['userId'] ?? '').toString(),
      dateKey: (data['dateKey'] ?? '').toString(),
      drop: dropMap is Map<String, dynamic>
          ? DailyViralDropModel.fromMap(dropMap)
          : DailyViralDropModel(
              trendTheme: '',
              reelConcept: '',
              shotPlan: const [],
              hooks: const [],
              caption: '',
              cta: '',
              hashtags: const [],
              bestPostTime: '',
            ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      trendKeyword: data['trendKeyword']?.toString(),
    );
  }
}

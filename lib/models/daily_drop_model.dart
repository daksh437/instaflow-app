/// Daily drop document for Firestore collection daily_drops/{userId_dateKey}.
/// Matches backend JSON: trend_theme, concept, steps, hooks, caption, hashtags, best_time, coach_summary, virality_score.
class DailyDropModel {
  final String date;
  final String niche;
  final String trendTheme;
  final String concept;
  final List<String> steps;
  final List<String> hooks;
  final String caption;
  final List<String> hashtags;
  final String bestTime;
  final String coachSummary;
  final int viralityScore;

  const DailyDropModel({
    required this.date,
    required this.niche,
    required this.trendTheme,
    required this.concept,
    required this.steps,
    required this.hooks,
    required this.caption,
    required this.hashtags,
    required this.bestTime,
    required this.coachSummary,
    this.viralityScore = 0,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'date': date,
      'niche': niche,
      'trend_theme': trendTheme,
      'concept': concept,
      'steps': steps,
      'hooks': hooks,
      'caption': caption,
      'hashtags': hashtags,
      'best_time': bestTime,
      'coach_summary': coachSummary,
      'virality_score': viralityScore,
    };
  }

  factory DailyDropModel.fromFirestore(Map<String, dynamic> data) {
    return DailyDropModel(
      date: (data['date'] ?? '').toString(),
      niche: (data['niche'] ?? '').toString(),
      trendTheme: (data['trend_theme'] ?? '').toString(),
      concept: (data['concept'] ?? '').toString(),
      steps: _toStringList(data['steps']),
      hooks: _toStringList(data['hooks']),
      caption: (data['caption'] ?? '').toString(),
      hashtags: _toStringList(data['hashtags']),
      bestTime: (data['best_time'] ?? '').toString(),
      coachSummary: (data['coach_summary'] ?? '').toString(),
      viralityScore: (data['virality_score'] is int)
          ? data['virality_score'] as int
          : (data['virality_score'] is num)
              ? (data['virality_score'] as num).toInt()
              : 0,
    );
  }

  factory DailyDropModel.fromJson(Map<String, dynamic> json) {
    return DailyDropModel(
      date: (json['date'] ?? '').toString(),
      niche: (json['niche'] ?? '').toString(),
      trendTheme: (json['trend_theme'] ?? '').toString(),
      concept: (json['reel_concept'] ?? json['concept'] ?? '').toString(),
      steps: _toStringList(json['steps']),
      hooks: _toStringList(json['hooks']),
      caption: (json['caption'] ?? '').toString(),
      hashtags: _toStringList(json['hashtags']),
      bestTime: (json['best_post_time'] ?? json['best_time'] ?? '').toString(),
      coachSummary: (json['coach_summary'] ?? '').toString(),
      viralityScore: (json['virality_score'] is int)
          ? json['virality_score'] as int
          : (json['virality_score'] is num)
              ? (json['virality_score'] as num).toInt()
              : 0,
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

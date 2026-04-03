/// Daily Viral Drop prompt template and builder only.
/// No Gemini/API calls from Flutter — generation is server-side only.
/// Reuse this template for consistency; backend uses same prompt in Cloud Function.
class DailyDropAiHelper {
  DailyDropAiHelper._();

  static const String promptTemplate = r'''
You are a viral Instagram reel strategist.

Using today's trend keywords:
{{trend_list}}

Generate ONE daily viral reel execution plan.

Return STRICT JSON:

trend_theme
virality_score
reel_concept
steps (5)
hooks (5)
caption
hashtags (10)
best_post_time
coach_summary

Avoid repeating structure from previous days.
''';

  /// Builds the Daily Drop prompt with trend list injected. Used for reference; backend builds same prompt.
  static String buildDailyDropPrompt(List<String> trendList) {
    final list = trendList.isEmpty ? ['trending reels', 'viral content'] : trendList;
    final trendListStr = list.take(15).join(', ');
    return promptTemplate.replaceAll('{{trend_list}}', trendListStr);
  }
}

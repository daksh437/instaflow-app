import '../config/ai_performance_config.dart';

/// Trims prompt for faster AI requests: whitespace, duplicate newlines, length limit.
String trimPromptForAi(String text) {
  if (text.isEmpty) return text;
  var out = text.trim();
  out = out.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  out = out.replaceAll(RegExp(r'[ \t]+'), ' ');
  if (out.length > AiPerformanceConfig.maxPromptLength) {
    out = '${out.substring(0, AiPerformanceConfig.maxPromptLength)}...';
  }
  return out.trim();
}

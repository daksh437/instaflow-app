/// Prepares text for TTS: trim, limit length, remove emojis/hashtags/markdown.
String prepareTextForSpeech(String text) {
  if (text.trim().isEmpty) return '';
  var out = text.trim();
  out = out.replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true), '');
  out = out.replaceAll(RegExp(r'#\w+'), '');
  out = out.replaceAll(RegExp(r'\*\*|__|\*|_|`|#'), ' ');
  out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (out.length > 600) out = '${out.substring(0, 600)}.';
  return out;
}

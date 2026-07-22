class SharedAiContent {
  const SharedAiContent({
    this.idea = '',
    this.hook = '',
    this.caption = '',
    this.hashtags = const [],
    this.script = const [],
  });

  final String idea;
  final String hook;
  final String caption;
  final List<String> hashtags;
  final List<String> script;

  bool get isEmpty =>
      idea.trim().isEmpty &&
      hook.trim().isEmpty &&
      caption.trim().isEmpty &&
      hashtags.isEmpty &&
      script.isEmpty;

  SharedAiContent copyWith({
    String? idea,
    String? hook,
    String? caption,
    List<String>? hashtags,
    List<String>? script,
  }) {
    return SharedAiContent(
      idea: idea ?? this.idea,
      hook: hook ?? this.hook,
      caption: caption ?? this.caption,
      hashtags: hashtags ?? this.hashtags,
      script: script ?? this.script,
    );
  }
}

import 'package:flutter/foundation.dart';
import '../models/shared_ai_content.dart';

class SharedAiContentStore {
  SharedAiContentStore._();
  static final SharedAiContentStore instance = SharedAiContentStore._();

  final ValueNotifier<SharedAiContent> state =
      ValueNotifier<SharedAiContent>(const SharedAiContent());

  SharedAiContent get current => state.value;

  void setContent(SharedAiContent content) {
    state.value = content;
  }

  void update({
    String? idea,
    String? hook,
    String? caption,
    List<String>? hashtags,
    List<String>? script,
  }) {
    state.value = state.value.copyWith(
      idea: idea,
      hook: hook,
      caption: caption,
      hashtags: hashtags,
      script: script,
    );
  }

  void clear() {
    state.value = const SharedAiContent();
  }
}

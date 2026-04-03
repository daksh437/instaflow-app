import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-speech for AI result playback. Lazy init, error-safe.
class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  FlutterTts? _flutterTts;
  bool _initialized = false;
  bool _isSpeaking = false;
  void Function()? onSpeakingChanged;

  bool get isSpeaking => _isSpeaking;

  void _setSpeaking(bool v) {
    if (_isSpeaking != v) {
      _isSpeaking = v;
      onSpeakingChanged?.call();
    }
  }

  Future<void> _ensureInit() async {
    if (_initialized) return;
    try {
      _flutterTts = FlutterTts();
      await _flutterTts!.setLanguage('en-US');
      await _flutterTts!.setSpeechRate(0.45);
      await _flutterTts!.setPitch(1.0);
      _flutterTts!.setCompletionHandler(() => _setSpeaking(false));
      _initialized = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[VoiceService] init error: $e');
    }
  }

  /// Speak text. Stops previous speech first. Safe text applied by caller.
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    try {
      await _ensureInit();
      if (_flutterTts == null) return;
      await stop();
      _setSpeaking(true);
      await _flutterTts!.speak(text);
    } catch (e) {
      if (kDebugMode) debugPrint('[VoiceService] speak error: $e');
      _setSpeaking(false);
      rethrow;
    }
  }

  Future<void> stop() async {
    try {
      if (_flutterTts != null) await _flutterTts!.stop();
      _setSpeaking(false);
    } catch (e) {
      if (kDebugMode) debugPrint('[VoiceService] stop error: $e');
      _setSpeaking(false);
    }
  }

  Future<void> pause() async {
    try {
      if (_flutterTts != null) await _flutterTts!.pause();
      _setSpeaking(false);
    } catch (e) {
      if (kDebugMode) debugPrint('[VoiceService] pause error: $e');
      _setSpeaking(false);
    }
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Speech-to-text helper with safe one-shot listening and friendly errors.
class SpeechInputService {
  SpeechInputService._();
  static final SpeechInputService instance = SpeechInputService._();

  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;

  bool get isListening => _isListening;

  /// Listens once and returns transcript or null.
  /// Throws [SpeechInputException] with friendly message for UI.
  Future<String?> listenOnce({
    Duration listenFor = const Duration(seconds: 45),
    Duration pauseFor = const Duration(seconds: 4),
    void Function(String status)? onStatus,
  }) async {
    if (_isListening) {
      await stop();
    }

    final completer = Completer<String?>();
    String transcript = '';
    Timer? watchdog;

    try {
      final ok = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (!completer.isCompleted) {
              completer.complete(transcript.trim().isEmpty ? null : transcript.trim());
            }
          }
        },
        onError: (error) {
          if (kDebugMode) debugPrint('[VoiceInput] error: ${error.errorMsg}');
          if (!completer.isCompleted) {
            completer.completeError(
              const SpeechInputException('Couldn\'t understand. Please try again'),
            );
          }
        },
      );
      if (!ok) {
        throw const SpeechInputException('Microphone permission is required');
      }

      _isListening = true;
      if (kDebugMode) debugPrint('[VoiceInput] started');
      onStatus?.call('listening');

      watchdog = Timer(listenFor + const Duration(seconds: 2), () async {
        if (!completer.isCompleted) {
          await stop();
          completer.complete(transcript.trim().isEmpty ? null : transcript.trim());
        }
      });

      await _speech.listen(
        listenFor: listenFor,
        pauseFor: pauseFor,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
        ),
        onResult: (result) {
          transcript = result.recognizedWords;
          if (result.finalResult && !completer.isCompleted) {
            completer.complete(transcript.trim().isEmpty ? null : transcript.trim());
          }
        },
      );

      final spoken = await completer.future;
      if (kDebugMode) {
        debugPrint('[VoiceInput] stopped');
        debugPrint('[VoiceInput] transcriptLength=${spoken?.length ?? 0}');
      }
      if (spoken == null || spoken.trim().isEmpty) {
        throw const SpeechInputException('Couldn\'t understand. Please try again');
      }
      return spoken.trim();
    } on SpeechInputException {
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('[VoiceInput] listen failed: $e');
      throw const SpeechInputException('Something went wrong, try again');
    } finally {
      watchdog?.cancel();
      _isListening = false;
      await stop();
      onStatus?.call('idle');
    }
  }

  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (e) {
      if (kDebugMode) debugPrint('[VoiceInput] stop error: $e');
    } finally {
      _isListening = false;
    }
  }
}

class SpeechInputException implements Exception {
  const SpeechInputException(this.message);
  final String message;

  @override
  String toString() => message;
}

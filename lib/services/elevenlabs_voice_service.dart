import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../config/app_secrets.dart';
import '../utils/voice_text_prep.dart';

/// ElevenLabs text-to-speech: fetch audio, cache locally, play via just_audio.
/// Voice: natural, normal speed, slight enthusiasm, conversational (Instagram reel style).
class ElevenLabsVoiceService {
  ElevenLabsVoiceService._();
  static final ElevenLabsVoiceService instance = ElevenLabsVoiceService._();

  static const String _baseUrl = 'https://api.elevenlabs.io/v1';
  /// Rachel: natural, conversational. Alternative: EXAVITQu4vr4xnSDxMaL (Bella).
  static const String _voiceId = '21m00Tcm4TlvDq8ikWAM';
  static const String _modelId = 'eleven_turbo_v2';

  final AudioPlayer _player = AudioPlayer();
  String? _currentSourceId;
  final Map<String, String> _pathCache = {};

  AudioPlayer get player => _player;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  bool get isPlaying => _player.playing;

  String? get currentSourceId => _currentSourceId;

  Future<void> stop() async {
    try {
      await _player.stop();
      _currentSourceId = null;
    } catch (e) {
      if (kDebugMode) debugPrint('[ElevenLabsVoice] stop: $e');
    }
  }

  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      if (kDebugMode) debugPrint('[ElevenLabsVoice] pause: $e');
    }
  }

  Future<void> playOrPause(String sourceId) async {
    if (_currentSourceId == sourceId && _player.playing) {
      await _player.pause();
      return;
    }
    if (_currentSourceId == sourceId && !_player.playing) {
      await _player.play();
      return;
    }
    final path = _pathCache[sourceId];
    if (path != null && File(path).existsSync()) {
      await _player.setFilePath(path);
      _currentSourceId = sourceId;
      await _player.play();
      return;
    }
  }

  /// Returns cached file path if available; otherwise fetches from API, caches, returns path.
  /// [text] is prepared for speech (trimmed, length-limited). [cacheKey] used for file name (optional).
  Future<String?> getOrFetchAudioPath({
    required String text,
    String? cacheKey,
  }) async {
    final prepared = prepareTextForSpeech(text);
    if (prepared.isEmpty) return null;
    if (!AppSecrets.isElevenLabsConfigured) {
      if (kDebugMode) debugPrint('[ElevenLabsVoice] ELEVENLABS_API_KEY not set');
      return null;
    }
    final key = cacheKey ?? _cacheKeyFor(prepared);
    final dir = await getTemporaryDirectory();
    final cacheDir = Directory('${dir.path}/elevenlabs_voice_cache');
    if (!await cacheDir.exists()) await cacheDir.create(recursive: true);
    final filePath = '${cacheDir.path}/$key.mp3';
    final file = File(filePath);
    if (await file.exists()) return filePath;
    final bytes = await _fetchAudioBytes(prepared);
    if (bytes == null || bytes.isEmpty) return null;
    await file.writeAsBytes(bytes);
    return filePath;
  }

  /// Play text: fetch (or load from cache), then play. Returns sourceId for this playback.
  Future<String?> playText({
    required String text,
    String? cacheKey,
    void Function(bool loading)? onLoadingChanged,
    void Function()? onDone,
  }) async {
    onLoadingChanged?.call(true);
    try {
      final path = await getOrFetchAudioPath(text: text, cacheKey: cacheKey);
      if (path == null) return null;
      final key = cacheKey ?? _cacheKeyFor(prepareTextForSpeech(text));
      _pathCache[key] = path;
      await stop();
      await _player.setFilePath(path);
      _currentSourceId = key;
      await _player.play();
      return key;
    } catch (e) {
      if (kDebugMode) debugPrint('[ElevenLabsVoice] playText: $e');
      return null;
    } finally {
      onLoadingChanged?.call(false);
    }
  }

  Future<Uint8List?> _fetchAudioBytes(String text) async {
    final url = Uri.parse('$_baseUrl/text-to-speech/$_voiceId');
    final body = {
      'text': text,
      'model_id': _modelId,
      'voice_settings': {
        'stability': 0.5,
        'similarity_boost': 0.75,
      },
    };
    try {
      final response = await http.post(
        url,
        headers: {
          'xi-api-key': AppSecrets.elevenLabsApiKey,
          'Content-Type': 'application/json',
          'Accept': 'audio/mpeg',
        },
        body: utf8.encode(jsonEncode(body)),
      );
      if (response.statusCode != 200) {
        if (kDebugMode) debugPrint('[ElevenLabsVoice] API ${response.statusCode}: ${response.body}');
        return null;
      }
      return response.bodyBytes;
    } catch (e) {
      if (kDebugMode) debugPrint('[ElevenLabsVoice] fetch: $e');
      return null;
    }
  }

  static String _cacheKeyFor(String text) {
    final hash = text.hashCode.abs().toRadixString(16);
    final len = text.length.clamp(0, 100);
    return '${hash}_$len';
  }
}

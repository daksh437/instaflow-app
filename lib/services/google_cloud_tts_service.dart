import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../config/app_secrets.dart';
import '../utils/voice_text_prep.dart';

/// Google Cloud Text-to-Speech via backend proxy. Neural2 voices, rate 1.0, slight enthusiasm.
/// API key must stay on server; app only calls proxy.
class GoogleCloudTtsService {
  GoogleCloudTtsService._();
  static final GoogleCloudTtsService instance = GoogleCloudTtsService._();

  final AudioPlayer _player = AudioPlayer();
  String? _currentSourceId;
  final Map<String, String> _pathCache = {};

  AudioPlayer get player => _player;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  bool get isPlaying => _player.playing;
  String? get currentSourceId => _currentSourceId;

  static const String _voiceEn = 'en-IN-Neural2-A';
  static const String _voiceHi = 'hi-IN-Neural2-A';

  Future<void> stop() async {
    try {
      await _player.stop();
      _currentSourceId = null;
    } catch (e) {
      if (kDebugMode) debugPrint('[GoogleCloudTts] stop: $e');
    }
  }

  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      if (kDebugMode) debugPrint('[GoogleCloudTts] pause: $e');
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

  String _voiceNameFor(String languageCode) {
    final code = (languageCode.isEmpty ? 'en-IN' : languageCode).toLowerCase();
    if (code.startsWith('hi')) return _voiceHi;
    return _voiceEn;
  }

  Future<String?> getOrFetchAudioPath({
    required String text,
    String languageCode = 'en-IN',
    String? cacheKey,
  }) async {
    final prepared = prepareTextForSpeech(text);
    if (prepared.isEmpty) return null;
    if (!AppSecrets.isTtsProxyConfigured) {
      if (kDebugMode) debugPrint('[GoogleCloudTts] TTS_PROXY_BASE_URL not set');
      return null;
    }
    final key = cacheKey ?? _cacheKeyFor(prepared, languageCode);
    final dir = await getTemporaryDirectory();
    final cacheDir = Directory('${dir.path}/gcloud_tts_cache');
    if (!await cacheDir.exists()) await cacheDir.create(recursive: true);
    final filePath = '${cacheDir.path}/$key.mp3';
    final file = File(filePath);
    if (await file.exists()) return filePath;
    final bytes = await _fetchAudioBytes(prepared, languageCode);
    if (bytes == null || bytes.isEmpty) return null;
    await file.writeAsBytes(bytes);
    return filePath;
  }

  Future<String?> playText({
    required String text,
    String languageCode = 'en-IN',
    String? cacheKey,
    void Function(bool loading)? onLoadingChanged,
  }) async {
    onLoadingChanged?.call(true);
    try {
      final path = await getOrFetchAudioPath(
        text: text,
        languageCode: languageCode,
        cacheKey: cacheKey,
      );
      if (path == null) return null;
      final key = cacheKey ?? _cacheKeyFor(prepareTextForSpeech(text), languageCode);
      _pathCache[key] = path;
      await stop();
      await _player.setFilePath(path);
      _currentSourceId = key;
      await _player.play();
      return key;
    } catch (e) {
      if (kDebugMode) debugPrint('[GoogleCloudTts] playText: $e');
      return null;
    } finally {
      onLoadingChanged?.call(false);
    }
  }

  Future<Uint8List?> _fetchAudioBytes(String text, String languageCode) async {
    final baseUrl = AppSecrets.ttsProxyBaseUrl.replaceAll(RegExp(r'/$'), '');
    final url = Uri.parse('$baseUrl/api/tts');
    final body = jsonEncode({
      'text': text,
      'languageCode': languageCode.isEmpty ? 'en-IN' : languageCode,
    });
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: body,
      );
      if (response.statusCode != 200) {
        if (kDebugMode) debugPrint('[GoogleCloudTts] proxy ${response.statusCode}: ${response.body}');
        return null;
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>?;
      final base64 = json?['audioContent'] as String?;
      if (base64 == null || base64.isEmpty) return null;
      return Uint8List.fromList(base64Decode(base64));
    } catch (e) {
      if (kDebugMode) debugPrint('[GoogleCloudTts] fetch: $e');
      return null;
    }
  }

  static String _cacheKeyFor(String text, String languageCode) {
    final hash = text.hashCode.abs().toRadixString(16);
    final len = text.length.clamp(0, 100);
    final lang = languageCode.replaceAll(RegExp(r'[^a-zA-Z0-9-]'), '_');
    return '${lang}_${hash}_$len';
  }
}

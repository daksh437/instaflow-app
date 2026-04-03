import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory + SharedPreferences cache for AI responses. Max 50 entries, 24h TTL.
class AiCacheService {
  static final AiCacheService _instance = AiCacheService._internal();
  factory AiCacheService() => _instance;
  AiCacheService._internal();

  static const int maxEntries = 50;
  static const Duration ttl = Duration(hours: 24);
  static const String _prefsPrefix = 'ai_cache_';
  static const String _prefsKeys = 'ai_cache_keys';
  static const String _prefsTimestamps = 'ai_cache_ts';

  final Map<String, _CacheEntry> _memory = {};
  bool _loadedFromPrefs = false;

  String _hash(String key) {
    return key.hashCode.toRadixString(16);
  }

  String _cacheKey(String endpoint, Map<String, dynamic> body) {
    final clone = Map<String, dynamic>.from(body);
    clone.remove('uniqueToken');
    clone.remove('uid');
    final json = jsonEncode(clone);
    return '${endpoint}_${_hash(json)}';
  }

  Future<void> _ensureLoaded() async {
    if (_loadedFromPrefs) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getStringList(_prefsKeys) ?? [];
      final timestamps = prefs.getString(_prefsTimestamps) ?? '{}';
      final tsMap = jsonDecode(timestamps) as Map<String, dynamic>? ?? {};
      final cutoff = DateTime.now().subtract(ttl);
      for (final k in keys) {
        final val = prefs.getString('$_prefsPrefix$k');
        final ts = tsMap[k] is int ? tsMap[k] as int : 0;
        if (val != null && ts > cutoff.millisecondsSinceEpoch) {
          try {
            _memory[k] = _CacheEntry(
              jsonDecode(val) as Map<String, dynamic>,
              DateTime.fromMillisecondsSinceEpoch(ts),
            );
          } catch (_) {}
        }
      }
      _loadedFromPrefs = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[AiCache] load error: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = <String>[];
      final tsMap = <String, int>{};
      for (final e in _memory.entries) {
        keys.add(e.key);
        tsMap[e.key] = e.value.timestamp.millisecondsSinceEpoch;
        await prefs.setString('$_prefsPrefix${e.key}', jsonEncode(e.value.data));
      }
      await prefs.setStringList(_prefsKeys, keys);
      await prefs.setString(_prefsTimestamps, jsonEncode(tsMap));
    } catch (e) {
      if (kDebugMode) debugPrint('[AiCache] persist error: $e');
    }
  }

  /// Returns cached result if valid, else null.
  Future<Map<String, dynamic>?> get(String endpoint, Map<String, dynamic> body) async {
    await _ensureLoaded();
    final key = _cacheKey(endpoint, body);
    final entry = _memory[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.timestamp) > ttl) {
      _memory.remove(key);
      return null;
    }
    if (kDebugMode) debugPrint('[AiCache] hit: $key');
    return entry.data;
  }

  /// Store result in cache.
  Future<void> put(String endpoint, Map<String, dynamic> body, Map<String, dynamic> result) async {
    await _ensureLoaded();
    final key = _cacheKey(endpoint, body);
    _memory[key] = _CacheEntry(result, DateTime.now());
    while (_memory.length > maxEntries) {
      final oldest = _memory.entries
          .reduce((a, b) => a.value.timestamp.isBefore(b.value.timestamp) ? a : b);
      _memory.remove(oldest.key);
    }
    unawaited(_persist());
  }
}

class _CacheEntry {
  _CacheEntry(this.data, this.timestamp);
  final Map<String, dynamic> data;
  final DateTime timestamp;
}

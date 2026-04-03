import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Remote Config: min_app_version forces update when current app version is lower.
class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  static const String _keyMinAppVersion = 'min_app_version';

  Future<void> initialize() async {
    try {
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await _remoteConfig.setDefaults({_keyMinAppVersion: '0.0.0'});
      await _remoteConfig.fetchAndActivate();
      if (kDebugMode) {
        debugPrint('[RemoteConfig] Initialized. min_app_version=${_remoteConfig.getString(_keyMinAppVersion)}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[RemoteConfig] Init error: $e');
    }
  }

  /// Returns true if app must be updated (current version < min_app_version).
  Future<bool> isForceUpdateRequired() async {
    try {
      final minVersion = _remoteConfig.getString(_keyMinAppVersion);
      if (minVersion.isEmpty || minVersion == '0.0.0') return false;

      final packageInfo = await PackageInfo.fromPlatform();
      final current = _normalizeVersion(packageInfo.version);
      final minimum = _normalizeVersion(minVersion);
      final required = current < minimum;
      if (kDebugMode) {
        debugPrint('[RemoteConfig] Version check: current=$current min=$minimum required=$required');
      }
      return required;
    } catch (e) {
      if (kDebugMode) debugPrint('[RemoteConfig] isForceUpdateRequired error: $e');
      return false;
    }
  }

  /// Compare semantic versions (major.minor.patch).
  int _normalizeVersion(String v) {
    final parts = v.split('.').map((e) => int.tryParse(e.trim()) ?? 0).toList();
    while (parts.length < 3) parts.add(0);
    return (parts[0] * 1000000) + (parts[1] * 1000) + parts[2];
  }
}

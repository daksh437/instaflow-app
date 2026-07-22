import 'dart:io';
import 'dart:math';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stable device identifier and model for device binding and session guard.
class DeviceService {
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _kDeviceIdKey = 'stable_device_id_v1';

  String? _cachedDeviceId;
  String? _cachedDeviceModel;

  /// Returns a **stable, persistent** device ID: a random id generated once and
  /// stored in SharedPreferences. This survives app restarts (fixes users being
  /// logged out on reopen — the old id was derived from build info / a timestamp
  /// fallback and changed between launches, tripping the SessionGuard).
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    try {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString(_kDeviceIdKey);
      if (id == null || id.isEmpty) {
        id = _generateStableId();
        await prefs.setString(_kDeviceIdKey, id);
      }
      _cachedDeviceId = id;
      return id;
    } catch (e, stack) {
      if (kDebugMode) debugPrint('[DeviceService] getDeviceId error: $e');
      FirebaseCrashlytics.instance.recordError(e, stack, fatal: false);
      // Constant fallback (NOT a timestamp) so it never triggers a false
      // session mismatch on the same install.
      _cachedDeviceId = 'device_fallback';
      return _cachedDeviceId!;
    }
  }

  String _generateStableId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Human-readable device model (e.g. "Pixel 6", "iPhone14,2").
  Future<String> getDeviceModel() async {
    if (_cachedDeviceModel != null) return _cachedDeviceModel!;
    try {
      if (Platform.isAndroid) {
        final android = await _deviceInfo.androidInfo;
        _cachedDeviceModel = '${android.manufacturer ?? ''} ${android.model ?? ''}'.trim();
        if (_cachedDeviceModel!.isEmpty) _cachedDeviceModel = 'Android';
      } else if (Platform.isIOS) {
        final ios = await _deviceInfo.iosInfo;
        _cachedDeviceModel = ios.utsname.machine ?? ios.model ?? 'iOS';
      } else {
        _cachedDeviceModel = 'Unknown';
      }
      return _cachedDeviceModel!;
    } catch (e, stack) {
      if (kDebugMode) debugPrint('[DeviceService] getDeviceModel error: $e');
      FirebaseCrashlytics.instance.recordError(e, stack, fatal: false);
      _cachedDeviceModel = 'Unknown';
      return _cachedDeviceModel!;
    }
  }

  /// Call after successful login: store activeDeviceId, deviceModel, lastLoginAt in Firestore.
  /// Overwrites previous device (marks previous session invalid).
  Future<void> bindDeviceAfterLogin(String uid) async {
    try {
      final deviceId = await getDeviceId();
      final deviceModel = await getDeviceModel();
      final now = DateTime.now();
      FirebaseCrashlytics.instance.setCustomKey('uid', uid);
      await _firestore.collection('users').doc(uid).set({
        'activeDeviceId': deviceId,
        'deviceModel': deviceModel,
        'lastLoginAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));
      if (kDebugMode) debugPrint('[DeviceService] bound device for $uid: $deviceId');
    } catch (e, stack) {
      if (kDebugMode) debugPrint('[DeviceService] bindDeviceAfterLogin error: $e');
      FirebaseCrashlytics.instance.recordError(e, stack, fatal: false);
    }
  }
}

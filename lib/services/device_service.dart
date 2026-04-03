import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Stable device identifier and model for device binding and session guard.
class DeviceService {
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _cachedDeviceId;
  String? _cachedDeviceModel;

  /// Returns a stable device ID (Android: androidId, iOS: identifierForVendor).
  /// Cached for the app session.
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    try {
      if (Platform.isAndroid) {
        final android = await _deviceInfo.androidInfo;
        _cachedDeviceId = android.id ?? 'android_unknown';
      } else if (Platform.isIOS) {
        final ios = await _deviceInfo.iosInfo;
        _cachedDeviceId = ios.identifierForVendor ?? 'ios_unknown';
      } else {
        _cachedDeviceId = 'unknown_platform';
      }
      return _cachedDeviceId!;
    } catch (e, stack) {
      if (kDebugMode) debugPrint('[DeviceService] getDeviceId error: $e');
      FirebaseCrashlytics.instance.recordError(e, stack, fatal: false);
      _cachedDeviceId = 'error_${DateTime.now().millisecondsSinceEpoch}';
      return _cachedDeviceId!;
    }
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

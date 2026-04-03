import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'device_service.dart';
import 'auth_service.dart';
import 'premium_guard.dart';

/// Validates that the current device is the one bound to the user. If not, signs out and shows dialog.
class SessionGuard {
  static final SessionGuard _instance = SessionGuard._internal();
  factory SessionGuard() => _instance;
  SessionGuard._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DeviceService _deviceService = DeviceService();
  final AuthService _authService = AuthService();

  /// Call on app start and on resume. If user is logged in and device mismatch, signs out and returns true (caller should show dialog).
  /// Returns false if no user or device matches. Never throws.
  Future<bool> checkAndInvalidateIfMismatch() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final currentDeviceId = await _deviceService.getDeviceId();
      final doc = await _firestore.collection('users').doc(user.uid).get().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('SessionGuard fetch timeout'),
      );

      if (!doc.exists) return false;
      final data = doc.data();
      final storedDeviceId = data?['activeDeviceId'] as String?;
      if (storedDeviceId == null || storedDeviceId.isEmpty) return false;

      if (storedDeviceId != currentDeviceId) {
        if (kDebugMode) debugPrint('[SessionGuard] device mismatch: stored=$storedDeviceId current=$currentDeviceId');
        PremiumGuard().invalidateCache();
        await _authService.signOut();
        return true;
      }
      return false;
    } on TimeoutException catch (e, stack) {
      if (kDebugMode) debugPrint('[SessionGuard] timeout: $e');
      FirebaseCrashlytics.instance.recordError(e, stack, fatal: false);
      return false;
    } catch (e, stack) {
      if (kDebugMode) debugPrint('[SessionGuard] check error: $e');
      FirebaseCrashlytics.instance.recordError(e, stack, fatal: false);
      return false;
    }
  }

  /// Show the "logged in on another device" dialog. Call after checkAndInvalidateIfMismatch returns true.
  static Future<void> showAnotherDeviceDialog(BuildContext context) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Session ended'),
        content: const Text(
          'Your account was logged in on another device. Please sign in again on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

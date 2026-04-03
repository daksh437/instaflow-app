import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Premium status from Firestore only (server trust). Never from local purchase state.
/// Caches with short TTL. All premium features must check this — not local bools.
class PremiumGuard {
  static final PremiumGuard _instance = PremiumGuard._internal();
  factory PremiumGuard() => _instance;
  PremiumGuard._internal();

  static const Duration cacheTtl = Duration(seconds: 60);
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool? _cachedValue;
  DateTime? _cacheTime;
  final _controller = StreamController<bool>.broadcast();

  /// Stream of premium status (from Firestore verified flag). Emits on refresh.
  Stream<bool> get isPremiumStream => _controller.stream;

  /// Current cached premium status. Call [refresh] to update.
  bool get isPremiumCached => _cachedValue ?? false;

  /// Alias for cached premium status. True only if subscription active and cache says so.
  bool get isPremiumUser => _cachedValue ?? false;

  /// Fetches from Firestore: premiumVerified or subscription.verified == true.
  /// Uses cache if younger than [cacheTtl]. Never throws; returns false on error.
  Future<bool> isPremium(String? uid) async {
    if (uid == null || uid.isEmpty) return false;
    if (_cacheTime != null && DateTime.now().difference(_cacheTime!) < cacheTtl && _cachedValue != null) {
      return _cachedValue!;
    }
    return refresh(uid);
  }

  /// Force refresh from Firestore and update cache + stream.
  Future<bool> refresh(String? uid) async {
    if (uid == null || uid.isEmpty) {
      _cachedValue = false;
      _cacheTime = DateTime.now();
      _controller.add(false);
      return false;
    }
    try {
      final doc = await _firestore.collection('users').doc(uid).get().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('PremiumGuard fetch timeout'),
      );
      if (!doc.exists) {
        _cachedValue = false;
        _cacheTime = DateTime.now();
        _controller.add(false);
        return false;
      }
      final data = doc.data();
      final premiumVerified = data?['premiumVerified'] == true;
      final subscription = data?['subscription'];
      final subVerified = subscription is Map && (subscription['verified'] == true);
      final verified = premiumVerified || subVerified;
      _cachedValue = verified;
      _cacheTime = DateTime.now();
      _controller.add(verified);
      return verified;
    } on TimeoutException catch (e, stack) {
      if (kDebugMode) debugPrint('[PremiumGuard] timeout: $e');
      FirebaseCrashlytics.instance.recordError(e, stack, fatal: false);
      return _cachedValue ?? false;
    } catch (e, stack) {
      if (kDebugMode) debugPrint('[PremiumGuard] refresh error: $e');
      FirebaseCrashlytics.instance.recordError(e, stack, fatal: false);
      return _cachedValue ?? false;
    }
  }

  /// Invalidate cache so next isPremium() refetches.
  void invalidateCache() {
    _cacheTime = null;
    _cachedValue = null;
  }

  void dispose() {
    _controller.close();
  }
}

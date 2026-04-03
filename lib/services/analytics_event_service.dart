import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Monetization tracking: Firebase Analytics + Firestore app_events.
/// All methods are async, non-blocking, and never throw.
class AnalyticsEventService {
  static final AnalyticsEventService _instance = AnalyticsEventService._internal();
  factory AnalyticsEventService() => _instance;
  AnalyticsEventService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Log to Firebase Analytics and Firestore (app_events). Auto-includes userId if logged in.
  /// Uses collection().add() — no overwrite, non-blocking. Never crashes app.
  Future<void> logEvent(String name, [Map<String, Object?>? params]) async {
    final safeParams = params != null ? Map<String, Object>.from(params) : <String, Object>{};
    final userId = FirebaseAuth.instance.currentUser?.uid;

    try {
      _analytics.logEvent(
        name: name.length > 40 ? name.substring(0, 40) : name,
        parameters: _sanitizeForAnalytics(safeParams),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('ANALYTICS EVENT → $name (FA error): $e');
    }

    try {
      await _firestore.collection('app_events').add({
        'name': name,
        'userId': userId,
        'params': safeParams,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) debugPrint('ANALYTICS EVENT → $name (Firestore error): $e');
    }

    if (kDebugMode) {
      debugPrint('ANALYTICS EVENT → $name $safeParams');
    }
  }

  /// Firebase Analytics has 40-char limit for param keys/values; stringify and truncate.
  static Map<String, Object> _sanitizeForAnalytics(Map<String, Object> params) {
    final out = <String, Object>{};
    for (final e in params.entries) {
      final k = e.key.length > 40 ? e.key.substring(0, 40) : e.key;
      final v = e.value?.toString() ?? '';
      out[k] = v.length > 100 ? v.substring(0, 100) : v;
    }
    return out;
  }

  void logTrialStarted() {
    unawaited(logEvent('trial_started'));
  }

  void logTrialExpired() {
    unawaited(logEvent('trial_expired'));
  }

  void logPaywallOpen() {
    unawaited(logEvent('paywall_open'));
  }

  void logPlanSelected({
    String? planId,
    String? price,
    String? duration,
  }) {
    unawaited(logEvent('plan_selected', {
      if (planId != null && planId.isNotEmpty) 'plan_id': planId,
      if (price != null && price.isNotEmpty) 'price': price,
      if (duration != null && duration.isNotEmpty) 'duration': duration,
    }));
  }

  void logPurchaseStarted({String? productId, String? price}) {
    unawaited(logEvent('purchase_started', {
      if (productId != null && productId.isNotEmpty) 'product_id': productId,
      if (price != null && price.isNotEmpty) 'price': price,
    }));
  }

  void logPurchaseSuccess({String? productId, String? price, String? duration}) {
    unawaited(logEvent('purchase_success', {
      if (productId != null && productId.isNotEmpty) 'product_id': productId,
      if (price != null && price.isNotEmpty) 'price': price,
      if (duration != null && duration.isNotEmpty) 'duration': duration,
    }));
  }

  void logPremiumActivated(String? planId) {
    unawaited(logEvent('premium_activated', {
      if (planId != null && planId.isNotEmpty) 'plan_id': planId,
    }));
  }

  void logRestoreClicked() {
    unawaited(logEvent('restore_clicked'));
  }

  /// Trial → Paid conversion: write to analytics_events for admin/reports.
  /// Doc: { uid, type: 'trial_start'|'purchase_start'|'purchase_success', timestamp, plan }.
  void logAnalyticsEventTrialStart(String uid) {
    unawaited(_writeAnalyticsEvent(uid, 'trial_start', null));
  }

  void logAnalyticsEventPurchaseStart(String uid, String? plan) {
    unawaited(_writeAnalyticsEvent(uid, 'purchase_start', plan));
  }

  void logAnalyticsEventPurchaseSuccess(String uid, String? plan) {
    unawaited(_writeAnalyticsEvent(uid, 'purchase_success', plan));
  }

  Future<void> _writeAnalyticsEvent(String uid, String type, String? plan) async {
    try {
      await _firestore.collection('analytics_events').add({
        'uid': uid,
        'type': type,
        'timestamp': FieldValue.serverTimestamp(),
        if (plan != null && plan.isNotEmpty) 'plan': plan,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('ANALYTICS_EVENTS → $type: $e');
    }
  }

  /// Write to app_events with admin-dashboard shape: type, userId, ...dataMap, ts.
  /// Use for analytics that need type + ts (e.g. ai_used). Non-blocking, never throws.
  Future<void> logAppEvent(String type, [Map<String, dynamic>? dataMap]) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    try {
      final data = <String, dynamic>{
        'type': type,
        'userId': userId,
        'ts': FieldValue.serverTimestamp(),
      };
      if (dataMap != null && dataMap.isNotEmpty) {
        for (final e in dataMap.entries) {
          if (e.value != null) data[e.key] = e.value;
        }
      }
      await _firestore.collection('app_events').add(data);
      if (kDebugMode) debugPrint('ANALYTICS EVENT → app_events $type $dataMap');
    } catch (e) {
      if (kDebugMode) debugPrint('ANALYTICS EVENT → logAppEvent error: $e');
    }
  }
}

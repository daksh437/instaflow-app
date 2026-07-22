import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Firebase Analytics monetization events.
/// Event names and params follow Firebase recommendations (≤40 chars for names/keys).
class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static FirebaseAnalytics get instance => _analytics;

  /// Paywall screen was opened.
  static void logPaywallOpen() {
    _logEvent('paywall_open', null);
  }

  /// User selected a plan (duration card).
  static void logPlanSelected({
    String? productId,
    String? price,
    String? duration,
  }) {
    _logEvent('plan_selected', {
      if (productId != null && productId.isNotEmpty) 'product_id': productId,
      if (price != null && price.isNotEmpty) 'price': price,
      if (duration != null && duration.isNotEmpty) 'duration': duration,
    });
  }

  /// User tapped purchase (flow started).
  static void logPurchaseStarted({
    String? productId,
    String? price,
  }) {
    _logEvent('purchase_started', {
      if (productId != null && productId.isNotEmpty) 'product_id': productId,
      if (price != null && price.isNotEmpty) 'price': price,
    });
  }

  /// Purchase completed successfully (from purchaseStream).
  /// Logs custom [purchase_success] (admin/Firestore funnels) and Firebase [logPurchase]
  /// (recommended event for Google Ads in-app conversion import).
  static void logPurchaseSuccess({
    String? productId,
    String? price,
    double? value,
    String currency = 'INR',
    String? transactionId,
  }) {
    _logEvent('purchase_success', {
      if (productId != null && productId.isNotEmpty) 'product_id': productId,
      if (price != null && price.isNotEmpty) 'price': price,
    });

    final purchaseValue = value ?? parsePriceToValue(price);
    if (purchaseValue == null || purchaseValue <= 0) return;

    try {
      _analytics.logPurchase(
        currency: currency,
        value: purchaseValue,
        transactionId: transactionId,
        items: productId != null && productId.isNotEmpty
            ? [
                AnalyticsEventItem(
                  itemId: productId,
                  itemName: productId,
                  price: purchaseValue,
                  quantity: 1,
                ),
              ]
            : null,
      );
      if (kDebugMode) {
        debugPrint('[Analytics] logPurchase value=$purchaseValue currency=$currency productId=$productId');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Analytics] logPurchase error: $e');
    }
  }

  /// Firebase recommended sign-up event (for Ads / Analytics funnels).
  static void logSignUp({required String method}) {
    _logEvent('sign_up', {'method': method});
  }

  /// Firebase recommended login event (returning users only — not on first sign_up).
  static void logLogin({required String method}) {
    _logEvent('login', {'method': method});
  }

  /// Bind Analytics user id after auth for install → signup → purchase attribution.
  static Future<void> setUserIdentity(User user) async {
    try {
      await _analytics.setUserId(id: user.uid);
      if (kDebugMode) debugPrint('[Analytics] setUserId uid=${user.uid}');
    } catch (e) {
      if (kDebugMode) debugPrint('[Analytics] setUserId error: $e');
    }
  }

  /// Parse localized Play price strings (e.g. "₹999.00") to numeric value.
  static double? parsePriceToValue(String? price) {
    if (price == null || price.trim().isEmpty) return null;
    final cleaned = price.replaceAll(RegExp(r'[^\d.]'), '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  /// User tapped restore purchases.
  static void logRestoreClicked() {
    _logEvent('restore_clicked', null);
  }

  /// Upgrade / limit dialog was shown.
  static void logUpgradeDialogShown({String? source}) {
    _logEvent('upgrade_dialog_shown', {
      if (source != null && source.isNotEmpty) 'source': source,
    });
  }

  /// User completed a rewarded ad (earned reward).
  static void logRewardedAdCompleted({
    String? rewardType,
    int? rewardAmount,
  }) {
    _logEvent('rewarded_ad_completed', {
      if (rewardType != null && rewardType.isNotEmpty) 'reward_type': rewardType,
      if (rewardAmount != null) 'reward_amount': rewardAmount,
    });
  }

  /// AI tool was used (call after successful generation).
  static void logAiToolUsed({String? toolId}) {
    _logEvent('ai_tool_used', {
      if (toolId != null && toolId.isNotEmpty) 'tool_id': toolId,
    });
  }

  /// Logs once per install per [toolId] when user copies AI output (first-win funnel).
  static Future<void> logFirstAiResultCopiedOnce({required String toolId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'fa_first_ai_copy_$toolId';
      if (prefs.getBool(key) == true) return;
      await prefs.setBool(key, true);
      _logEvent('first_ai_result_copied', {
        'tool_id': toolId,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[Analytics] first_ai_result_copied: $e');
    }
  }

  // --- AI usage control events (backend is source of truth; these are for analytics only) ---

  /// AI access allowed (trial / free with credits / premium).
  static void logAiAllowed({String? planType, int? creditsLeftToday}) {
    _logEvent('ai_allowed', {
      if (planType != null && planType.isNotEmpty) 'plan_type': planType,
      if (creditsLeftToday != null) 'credits_left_today': creditsLeftToday,
    });
  }

  /// AI blocked due to daily limit.
  static void logAiBlockedLimit() {
    _logEvent('ai_blocked_limit', null);
  }

  /// User is on active trial (shown in UI or after check).
  static void logAiTrialActive({int? trialDaysLeft}) {
    _logEvent('ai_trial_active', {
      if (trialDaysLeft != null) 'trial_days_left': trialDaysLeft,
    });
  }

  /// Trial expired and auto-converted to free (from backend/check).
  static void logAiTrialExpiredAutoConvert() {
    _logEvent('ai_trial_expired_auto_convert', null);
  }

  /// AI usage recorded (client-side funnel: user completed an AI generation; count is authoritative on backend).
  static void logAiUsageRecorded({String? toolId}) {
    _logEvent('ai_usage_recorded', {
      if (toolId != null && toolId.isNotEmpty) 'tool_id': toolId,
    });
  }

  /// Trial started for user.
  static void logTrialStarted() {
    _logEvent('trial_started', null);
  }

  /// Trial expired.
  static void logTrialExpired() {
    _logEvent('trial_expired', null);
  }

  /// Rewarded ad used for +1 use (alias for analytics naming).
  static void logRewardedAdUsed() {
    _logEvent('rewarded_ad_used', null);
  }

  /// Feedback submitted.
  static void logFeedbackSent({String? type}) {
    _logEvent('feedback_sent', {
      if (type != null && type.isNotEmpty) 'type': type,
    });
  }

  /// AI call took longer than threshold (e.g. > 8 seconds).
  static void logAiSlowCall({String? endpoint, int? durationMs}) {
    _logEvent('ai_slow_call', {
      if (endpoint != null && endpoint.isNotEmpty) 'endpoint': endpoint,
      if (durationMs != null) 'duration_ms': durationMs,
    });
  }

  /// Daily Viral Drop: screen opened.
  static void logDailyDropOpen() {
    _logEvent('daily_drop_open', null);
  }

  /// Daily Viral Drop: new drop generated via AI.
  static void logDailyDropGenerated() {
    _logEvent('daily_drop_generated', null);
  }

  /// Daily Viral Drop: drop loaded from cache.
  static void logDailyDropCached() {
    _logEvent('daily_drop_cached', null);
  }

  static void _logEvent(String name, Map<String, Object>? params) {
    try {
      if (params != null && params.isNotEmpty) {
        _analytics.logEvent(name: name, parameters: params);
      } else {
        _analytics.logEvent(name: name);
      }
      if (kDebugMode) {
        debugPrint('[Analytics] $name ${params ?? {}}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Analytics] Error logging $name: $e');
    }
  }
}

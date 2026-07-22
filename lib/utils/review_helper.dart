import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Asks for a Play Store rating at a happy moment (after a few successful AI
/// generations) using Google's native In-App Review — no leaving the app. More
/// good reviews → higher Play Store ranking → more organic installs.
class ReviewHelper {
  static const _countKey = 'ai_success_count_v1';
  static const _askedKey = 'review_asked_v1';
  static const _triggerAt = 3; // ask after the 3rd successful generation

  static final InAppReview _review = InAppReview.instance;

  /// Call after every successful AI generation. Triggers the review prompt once,
  /// after [_triggerAt] successes.
  static Future<void> onAiSuccess() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_askedKey) == true) return;
      final count = (prefs.getInt(_countKey) ?? 0) + 1;
      await prefs.setInt(_countKey, count);
      if (count >= _triggerAt) {
        await _requestReview(prefs);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ReviewHelper] onAiSuccess: $e');
    }
  }

  static Future<void> _requestReview(SharedPreferences prefs) async {
    try {
      if (await _review.isAvailable()) {
        await _review.requestReview();
        await prefs.setBool(_askedKey, true);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ReviewHelper] requestReview: $e');
    }
  }

  /// Manual "Rate us" (e.g. a Profile button) — opens the store listing.
  static Future<void> openStoreListing() async {
    try {
      await _review.openStoreListing();
    } catch (e) {
      if (kDebugMode) debugPrint('[ReviewHelper] openStoreListing: $e');
    }
  }
}

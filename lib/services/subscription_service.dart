import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../models/plan_option.dart';
import 'play_billing_service.dart';

/// Single subscription ID (premium_monthly) with base plans. Plan options from subscriptionOfferDetails.
class SubscriptionService {
  static const String subscriptionId = 'premium_monthly';

  static const List<String> productIds = [subscriptionId];

  /// Product ID → duration key (for billing/analytics; productId is always premium_monthly).
  static const Map<String, String> productIdToDurationKey = {
    'premium_monthly': '1m',
  };

  static const List<String> durationKeys = ['1m', '3m', '6m', '12m'];

  final PlayBillingService _billing = PlayBillingService();

  /// Query product details once with subscriptionId only. Returns map with one entry if found.
  Future<Map<String, ProductDetails>> getProductMap() async {
    try {
      final ok = await _billing.initialize().timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );
      if (!ok) return {};
      final list = await _billing.getProducts().timeout(
        const Duration(seconds: 8),
        onTimeout: () => <ProductDetails>[],
      );
      final map = <String, ProductDetails>{};
      for (final p in list) {
        if (p.id.isNotEmpty) map[p.id] = p;
      }
      if (kDebugMode) {
        debugPrint('[SubscriptionService] getProductMap: ${map.length} products');
        if (!map.containsKey(subscriptionId)) {
          debugPrint('[SubscriptionService] missing product: $subscriptionId');
        }
      }
      return map;
    } catch (e, stack) {
      if (kDebugMode) debugPrint('[SubscriptionService] getProductMap error: $e');
      try {
        FirebaseCrashlytics.instance.recordError(e, stack, fatal: false);
      } catch (_) {}
      return {};
    }
  }

  /// Sorted plan options from the subscription product (base plans). Empty if product not Google Play or no offers.
  List<PlanOption> getSortedPlanOptions(ProductDetails? product) {
    if (product == null) return [];
    return _billing.parsePlanOptions(product);
  }
}

import 'package:in_app_purchase/in_app_purchase.dart';

/// One subscription offer (base plan) for the premium_monthly product.
/// Built from Google Play subscriptionOfferDetails.
/// [productDetailsForPurchase] is the GooglePlayProductDetails for this offer (used on Android so the plugin reads offerToken from it).
class PlanOption {
  const PlanOption({
    required this.title,
    required this.basePlanId,
    required this.price,
    required this.billingPeriod,
    required this.offerToken,
    this.productDetailsForPurchase,
  });

  final String title;
  final String basePlanId;
  final String price;
  /// ISO 8601 duration from Play (e.g. P1M, P3M, P6M, P1Y).
  final String billingPeriod;
  final String offerToken;
  /// On Android: use this when purchasing so the plugin gets the correct offerToken from it.
  final ProductDetails? productDetailsForPurchase;

  /// Duration key for billing/analytics: 1m, 3m, 6m, 12m.
  String get durationKey => _billingPeriodToDurationKey(billingPeriod);

  static const Map<String, String> billingPeriodToTitle = {
    'P1M': '1 Month',
    'P3M': '3 Months',
    'P6M': '6 Months',
    'P1Y': '12 Months',
  };

  static String titleFromBillingPeriod(String billingPeriod) {
    return billingPeriodToTitle[billingPeriod] ?? billingPeriod;
  }

  static const Map<String, String> _billingPeriodToKey = {
    'P1M': '1m',
    'P3M': '3m',
    'P6M': '6m',
    'P1Y': '12m',
  };

  static String _billingPeriodToDurationKey(String billingPeriod) {
    return _billingPeriodToKey[billingPeriod] ?? '1m';
  }

  /// Sort key for ordering by period ascending (1 month, 3, 6, 12).
  static int orderIndex(String billingPeriod) {
    const order = ['P1M', 'P3M', 'P6M', 'P1Y'];
    final i = order.indexOf(billingPeriod);
    return i >= 0 ? i : 999;
  }
}

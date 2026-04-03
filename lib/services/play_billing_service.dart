import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../models/plan_option.dart';
import '../services/analytics_firestore_service.dart';
import '../services/premium_service.dart';
import 'analytics_event_service.dart';
import 'analytics_service.dart';
import 'firestore_helpers.dart';
import 'subscription_service.dart';

/// Google Play Billing v5 — single subscription ID (premium_monthly) with base plans.
/// Query by subscriptionId only; parse subscriptionOfferDetails for plan options.
/// Never crashes; returns clean bool. Billing init is lazy (paywall only).
class PlayBillingService {
  static final PlayBillingService _instance = PlayBillingService._internal();
  factory PlayBillingService() => _instance;
  PlayBillingService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final PremiumService _premiumService = PremiumService();

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _isAvailable = false;
  bool _isInitialized = false;
  bool _initInProgress = false;
  static bool _purchaseListenerAttached = false;

  static String? selectedDuration;
  static String? get lastPurchaseDuration => selectedDuration;

  /// Initialize billing (call from paywall only — not from main).
  Future<bool> initialize() async {
    if (_isInitialized) return _isAvailable;
    if (_initInProgress) return _isAvailable;

    _initInProgress = true;
    try {
      _isAvailable = await _inAppPurchase.isAvailable();
      if (kDebugMode) debugPrint('[Billing] isAvailable: $_isAvailable');

      if (_isAvailable) {
        if (!_purchaseListenerAttached) {
          _purchaseSubscription?.cancel();
          _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
            _handlePurchaseUpdates,
            onDone: () {
              _purchaseSubscription?.cancel();
              _purchaseSubscription = null;
              _purchaseListenerAttached = false;
            },
            onError: (e) {
              if (kDebugMode) debugPrint('[Billing] purchaseStream error: $e');
            },
          );
          _purchaseListenerAttached = true;
        }
      }
      _isInitialized = true;
      return _isAvailable;
    } catch (e) {
      if (kDebugMode) debugPrint('[Billing] init error: $e');
      return false;
    } finally {
      _initInProgress = false;
    }
  }

  /// Query product details with subscriptionId ONLY: premium_monthly.
  /// Returns list from Play (one ProductDetails for the subscription); never throws.
  Future<List<ProductDetails>> getProducts() async {
    if (!_isInitialized || !_isAvailable) {
      final ok = await initialize().timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );
      if (!ok) return [];
    }
    try {
      const ids = {'premium_monthly'};
      final response = await _inAppPurchase.queryProductDetails(ids).timeout(
        const Duration(seconds: 8),
        onTimeout: () => ProductDetailsResponse(productDetails: [], notFoundIDs: ['premium_monthly']),
      );
      final list = response.productDetails;
      if (kDebugMode) {
        debugPrint('[Billing] queryProductDetails result: ${list.length} products, notFound: ${response.notFoundIDs}');
        for (final p in list) debugPrint('[Billing] product: id=${p.id} price=${p.price}');
      }
      return list;
    } catch (e) {
      if (kDebugMode) debugPrint('[Billing] getProducts error: $e');
      return [];
    }
  }

  /// Parse base plan offers from ProductDetails (Google Play subscription).
  /// Returns list of PlanOption sorted by billing period ascending. Each option carries the
  /// GooglePlayProductDetails for that offer so purchase uses the correct offerToken (plugin reads it from ProductDetails).
  List<PlanOption> parsePlanOptions(ProductDetails product) {
    if (product is! GooglePlayProductDetails) return [];
    final wrapper = product.productDetails;
    final offers = wrapper.subscriptionOfferDetails;
    if (offers == null || offers.isEmpty) return [];
    final googlePlayDetailsList = GooglePlayProductDetails.fromProductDetails(wrapper);
    final options = <PlanOption>[];
    for (var i = 0; i < offers.length; i++) {
      final offer = offers[i];
      final pricingPhases = offer.pricingPhases;
      final phase = pricingPhases.isNotEmpty ? pricingPhases.first : null;
      final formattedPrice = phase?.formattedPrice ?? product.price;
      final billingPeriod = phase?.billingPeriod ?? 'P1M';
      final detailsForPurchase = i < googlePlayDetailsList.length ? googlePlayDetailsList[i] : null;
      final plan = PlanOption(
        title: PlanOption.titleFromBillingPeriod(billingPeriod),
        basePlanId: offer.basePlanId,
        price: formattedPrice,
        billingPeriod: billingPeriod,
        offerToken: offer.offerIdToken,
        productDetailsForPurchase: detailsForPurchase,
      );
      options.add(plan);
      if (kDebugMode) {
        final tokenPreview = plan.offerToken.length > 12 ? '${plan.offerToken.substring(0, 12)}...' : plan.offerToken;
        debugPrint('[Billing] plan: basePlanId=${plan.basePlanId} price=${plan.price} billingPeriod=${plan.billingPeriod} offerToken=$tokenPreview');
      }
    }
    options.sort((a, b) => PlanOption.orderIndex(a.billingPeriod).compareTo(PlanOption.orderIndex(b.billingPeriod)));
    return options;
  }

  /// Buy subscription. Pass the ProductDetails for the selected offer (use PlanOption.productDetailsForPurchase on Android).
  /// The plugin reads offerToken from GooglePlayProductDetails when present.
  Future<bool> buy(ProductDetails product) async {
    if (!_isInitialized || !_isAvailable) {
      final ok = await initialize();
      if (!ok) return false;
    }
    try {
      final param = PurchaseParam(
        productDetails: product,
        applicationUserName: FirebaseAuth.instance.currentUser?.uid,
      );
      return await _inAppPurchase.buyNonConsumable(purchaseParam: param);
    } catch (e) {
      if (kDebugMode) debugPrint('[Billing] buy error: $e');
      return false;
    }
  }

  /// Restore purchases. Returns true if restore was initiated successfully.
  Future<bool> restore() async {
    if (!_isAvailable && !_isInitialized) {
      await initialize();
    }
    if (!_isAvailable) {
      if (kDebugMode) debugPrint('[Billing] restore: billing not available');
      return false;
    }
    try {
      await _inAppPurchase.restorePurchases();
      if (kDebugMode) debugPrint('[Billing] restore: restorePurchases() completed');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[Billing] restore error: $e');
      return false;
    }
  }

  /// Alias for buy (used by paywall). Pass the ProductDetails for the selected plan (use PlanOption.productDetailsForPurchase on Android).
  Future<bool> purchaseSubscription(ProductDetails product) => buy(product);

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (kDebugMode) debugPrint('[Billing] purchaseStream: no user, ignoring ${purchases.length} items');
      return;
    }
    for (final purchase in purchases) {
      try {
        if (kDebugMode) debugPrint('[Billing] purchaseStream: status=${purchase.status} productId=${purchase.productID} pendingComplete=${purchase.pendingCompletePurchase}');
        if (purchase.status == PurchaseStatus.pending) {
          if (kDebugMode) debugPrint('[Billing] purchaseStream: pending — skip');
          continue;
        }
        if (purchase.status == PurchaseStatus.error) {
          if (kDebugMode) debugPrint('[Billing] purchaseStream: error — ${purchase.error?.message ?? "unknown"}');
          if (purchase.pendingCompletePurchase) await _inAppPurchase.completePurchase(purchase);
          continue;
        }
        if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
          final verified = _verifyPurchase(purchase);
          if (!verified) {
            if (kDebugMode) debugPrint('[Billing] purchaseStream: purchased/restored but verify failed');
            if (purchase.pendingCompletePurchase) await _inAppPurchase.completePurchase(purchase);
            continue;
          }
          if (kDebugMode) debugPrint('[Billing] purchaseStream: success ${purchase.status} productId=${purchase.productID}');
          await _handleSuccessfulPurchase(purchase, user.uid);
        }
        if (purchase.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchase);
        }
      } catch (e, stack) {
        if (kDebugMode) debugPrint('[Billing] handle purchase error: $e');
        try { FirebaseCrashlytics.instance.recordError(e, stack, fatal: false); } catch (_) {}
      }
    }
  }

  bool _verifyPurchase(PurchaseDetails purchase) {
    try {
      if (purchase.transactionDate == null) return false;
      final id = purchase.purchaseID;
      if (id == null || id.isEmpty) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchase, String userId) async {
    try {
      final productId = purchase.productID;
      final purchaseToken = purchase.verificationData.serverVerificationData;
      final transactionDateStr = purchase.transactionDate;
      final purchaseTimeMillis = _parseTransactionDateMillis(transactionDateStr);
      final transactionDate = purchaseTimeMillis != null
          ? DateTime.fromMillisecondsSinceEpoch(purchaseTimeMillis)
          : null;
      final purchaseTimeMillisForFirestore = purchaseTimeMillis ?? DateTime.now().millisecondsSinceEpoch;
      final duration = selectedDuration ?? _productIdToDuration(productId);

      AnalyticsService.logPurchaseSuccess(productId: productId);
      AnalyticsEventService().logPurchaseSuccess(productId: productId, duration: duration);
      AnalyticsEventService().logAnalyticsEventPurchaseSuccess(userId, duration);
      try {
        AnalyticsFirestoreService().recordPremiumPurchased();
      } catch (_) {}

      if (kDebugMode) debugPrint('[Billing] purchase result: success productId=$productId duration=$duration');
      await _premiumService.submitPurchaseToFirestore(
        uid: userId,
        productId: productId,
        purchaseToken: purchaseToken,
        purchaseTimeMillis: purchaseTimeMillisForFirestore,
        transactionDate: transactionDate,
        platform: 'android',
        markVerifiedAndActivate: false,
        duration: duration,
      );
    } catch (e, stack) {
      if (kDebugMode) debugPrint('[Billing] purchase result: submitPurchase error $e');
      try {
        FirebaseCrashlytics.instance.recordError(e, stack, fatal: false);
      } catch (_) {}
    }
  }

  /// transactionDate from PurchaseDetails is String? (millis since epoch on Android).
  static int? _parseTransactionDateMillis(String? transactionDateStr) {
    if (transactionDateStr == null || transactionDateStr.isEmpty) return null;
    return int.tryParse(transactionDateStr);
  }

  String _productIdToDuration(String productId) {
    const map = {
      'premium_monthly': '1m',
      'premium_3month': '3m',
      'premium_6month': '6m',
      'premium_12month': '12m',
    };
    return map[productId] ?? selectedDuration ?? '1m';
  }

  /// Check if user has active subscription in Firestore. Safe; returns false on error.
  Future<bool> hasActiveSubscription(String userId) async {
    final data = await FirestoreHelpers.safeGetDocData('users', userId);
    if (data == null) return false;
    final isPremium = data['isPremium'] == true;
    final expiry = data['premiumExpiry'];
    final expiryDate = (expiry is Timestamp) ? expiry.toDate() : null;
    if (!isPremium || expiryDate == null) return false;
    if (!DateTime.now().isBefore(expiryDate)) {
      await FirestoreHelpers.safeUpdateDoc('users', userId, {
        'isPremium': false,
        'premiumPlan': 'none',
        'premiumDuration': 'none',
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      return false;
    }
    return true;
  }

  void dispose() {
    _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
    _purchaseListenerAttached = false;
    _isInitialized = false;
  }
}

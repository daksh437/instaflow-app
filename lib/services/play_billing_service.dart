import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/plan_option.dart';
import '../services/analytics_firestore_service.dart';
import '../services/ai_usage_control_service.dart';
import '../services/api_service.dart';
import '../services/premium_status_notifier.dart';
import 'plan_manager.dart';
import 'analytics_event_service.dart';
import 'analytics_service.dart';
import 'firestore_helpers.dart';

/// Google Play Billing v5 — single subscription ID (premium_monthly) with base plans.
/// [initialize] attaches a **single global** [purchaseStream] listener (idempotent).
class PlayBillingService {
  static final PlayBillingService _instance = PlayBillingService._internal();
  factory PlayBillingService() => _instance;
  PlayBillingService._internal();

  static const _pendingPrefsKey = 'billing_pending_purchases_v1';

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _isAvailable = false;
  bool _isInitialized = false;
  bool _initInProgress = false;
  static bool _purchaseListenerAttached = false;
  static bool _silentRestoreDoneThisSession = false;
  static final Set<String> _loggedPurchaseTransactionIds = {};
  static final List<PurchaseDetails> _pendingPurchaseDetailsInMemory = [];

  static String? selectedDuration;
  static String? lastPurchasePrice;
  static double? lastPurchaseValue;
  static String lastPurchaseCurrency = 'INR';
  static String? get lastPurchaseDuration => selectedDuration;

  Future<bool> initialize() async {
    if (_isInitialized) return _isAvailable;
    if (_initInProgress) return _isAvailable;

    _initInProgress = true;
    try {
      _isAvailable = await _inAppPurchase.isAvailable();
      if (kDebugMode) debugPrint('[Billing] isAvailable: $_isAvailable');

      if (_isAvailable && !_purchaseListenerAttached) {
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
      _isInitialized = true;
      return _isAvailable;
    } catch (e) {
      if (kDebugMode) debugPrint('[Billing] init error: $e');
      return false;
    } finally {
      _initInProgress = false;
    }
  }

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

  /// Replay pending purchases after login (memory queue + SharedPreferences snapshots + Play restore).
  Future<void> processPendingPurchasesIfAny() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await initialize();

    var anyFailed = false;

    final memoryCopy = List<PurchaseDetails>.from(_pendingPurchaseDetailsInMemory);
    _pendingPurchaseDetailsInMemory.clear();
    for (final purchase in memoryCopy) {
      final ok = await _processSinglePurchase(purchase, user.uid);
      if (!ok) anyFailed = true;
    }

    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_pendingPrefsKey) ?? [];
    final remaining = <String>[];
    for (final raw in rawList) {
      try {
        final snap = jsonDecode(raw) as Map<String, dynamic>;
        final ok = await _activateFromSnapshot(user.uid, snap);
        if (ok) {
          await _removePersistedSnapshot(snap);
        } else {
          remaining.add(raw);
          anyFailed = true;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[Billing] pending snapshot parse error: $e');
        remaining.add(raw);
        anyFailed = true;
      }
    }
    await prefs.setStringList(_pendingPrefsKey, remaining);

    if (anyFailed || remaining.isNotEmpty) {
      if (kDebugMode) debugPrint('[Billing] pending purchases remain — triggering restorePurchases()');
      try {
        await _inAppPurchase.restorePurchases();
      } catch (e) {
        if (kDebugMode) debugPrint('[Billing] restore after pending error: $e');
      }
    }
  }

  Future<void> silentRestoreAfterLoginIfNeeded() async {
    if (_silentRestoreDoneThisSession) return;
    _silentRestoreDoneThisSession = true;
    final ok = await initialize();
    if (!ok) {
      if (kDebugMode) debugPrint('[Billing] silentRestore: billing unavailable');
      return;
    }
    try {
      if (kDebugMode) debugPrint('[Billing] silentRestore: restorePurchases()');
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      if (kDebugMode) debugPrint('[Billing] silentRestore error: $e');
    }
  }

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

  Future<bool> purchaseSubscription(ProductDetails product) => buy(product);

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      try {
        // Unconditional (release-visible) log to diagnose activation issues.
        debugPrint(
          '[PAYDBG] update status=${purchase.status} pid=${purchase.productID} '
          'pending=${purchase.pendingCompletePurchase} err=${purchase.error?.message}',
        );

        if (purchase.status == PurchaseStatus.pending) continue;
        if (purchase.status == PurchaseStatus.error) {
          debugPrint('[PAYDBG] purchase ERROR — ${purchase.error?.message ?? "unknown"}');
          continue;
        }

        if (purchase.status != PurchaseStatus.purchased &&
            purchase.status != PurchaseStatus.restored) {
          continue;
        }

        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          debugPrint('[PAYDBG] user NULL at purchase — queued pending');
          await _enqueuePendingPurchase(purchase);
          continue;
        }

        final ok = await _processSinglePurchase(purchase, user.uid);
        debugPrint('[PAYDBG] processSinglePurchase result=$ok uid=${user.uid}');
      } catch (e, stack) {
        debugPrint('[PAYDBG] handle purchase EXCEPTION: $e');
        try {
          FirebaseCrashlytics.instance.recordError(e, stack, fatal: false);
        } catch (_) {}
      }
    }
  }

  Future<bool> _processSinglePurchase(PurchaseDetails purchase, String userId) async {
    if (!_verifyPurchase(purchase)) {
      if (kDebugMode) debugPrint('[Billing] verify soft-fail — still attempting Firestore update');
    }

    final logPurchaseAnalytics = purchase.status == PurchaseStatus.purchased &&
        _markPurchaseAnalyticsIfNew(purchase);

    final firestoreOk = await _handleSuccessfulPurchase(
      purchase,
      userId,
      logPurchaseAnalytics: logPurchaseAnalytics,
    );

    if (firestoreOk) {
      await _clearPersistedSnapshotForPurchase(purchase);
      if (purchase.pendingCompletePurchase) {
        await _completePurchaseSafe(purchase, userId: userId);
      }
    } else if (purchase.pendingCompletePurchase) {
      if (kDebugMode) {
        debugPrint(
          '[Billing] NOT completing purchase — Firestore activation failed '
          'purchaseID=${purchase.purchaseID} uid=$userId',
        );
      }
      try {
        FirebaseCrashlytics.instance.log(
          'billing_activation_failed purchaseID=${purchase.purchaseID} uid=$userId productId=${purchase.productID}',
        );
      } catch (_) {}
    }

    return firestoreOk;
  }

  Future<void> _enqueuePendingPurchase(PurchaseDetails purchase) async {
    _pendingPurchaseDetailsInMemory.add(purchase);
    await _persistPendingSnapshot(purchase);
    if (kDebugMode) {
      debugPrint(
        '[Billing] queued pending purchase (no auth) productId=${purchase.productID} '
        'purchaseID=${purchase.purchaseID}',
      );
    }
  }

  Map<String, dynamic> _snapshotFromPurchase(PurchaseDetails purchase) => {
        'purchaseID': purchase.purchaseID,
        'productID': purchase.productID,
        'purchaseToken': purchase.verificationData.serverVerificationData,
        'transactionDate': purchase.transactionDate,
        'status': purchase.status.name,
        'duration': selectedDuration,
      };

  Future<void> _persistPendingSnapshot(PurchaseDetails purchase) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final snap = _snapshotFromPurchase(purchase);
      final id = purchase.purchaseID ?? purchase.productID;
      final list = prefs.getStringList(_pendingPrefsKey) ?? [];
      list.removeWhere((raw) {
        try {
          final m = jsonDecode(raw) as Map<String, dynamic>;
          final existingId = m['purchaseID'] ?? m['productID'];
          return existingId == id;
        } catch (_) {
          return false;
        }
      });
      list.add(jsonEncode(snap));
      await prefs.setStringList(_pendingPrefsKey, list);
    } catch (e) {
      if (kDebugMode) debugPrint('[Billing] persist pending snapshot error: $e');
    }
  }

  Future<void> _removePersistedSnapshot(Map<String, dynamic> snap) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = snap['purchaseID'] ?? snap['productID'];
      final list = prefs.getStringList(_pendingPrefsKey) ?? [];
      list.removeWhere((raw) {
        try {
          final m = jsonDecode(raw) as Map<String, dynamic>;
          final existingId = m['purchaseID'] ?? m['productID'];
          return existingId == id;
        } catch (_) {
          return false;
        }
      });
      await prefs.setStringList(_pendingPrefsKey, list);
    } catch (e) {
      if (kDebugMode) debugPrint('[Billing] remove persisted snapshot error: $e');
    }
  }

  Future<void> _clearPersistedSnapshotForPurchase(PurchaseDetails purchase) async {
    await _removePersistedSnapshot(_snapshotFromPurchase(purchase));
  }

  Future<bool> _activateFromSnapshot(String uid, Map<String, dynamic> snap) async {
    final productId = snap['productID'] as String? ?? '';
    final token = snap['purchaseToken'] as String? ?? '';
    if (productId.isEmpty || token.isEmpty) return false;
    // Server-authoritative: let the backend verify + grant from the token.
    return await _activateOnServer(token, productId);
  }

  Future<void> _completePurchaseSafe(PurchaseDetails purchase, {required String userId}) async {
    try {
      await InAppPurchase.instance.completePurchase(purchase);
      if (kDebugMode) {
        debugPrint('[Billing] completePurchase() acknowledged for ${purchase.productID} uid=$userId');
      }
    } catch (e, st) {
      if (kDebugMode) debugPrint('[Billing] completePurchase error: $e');
      try {
        FirebaseCrashlytics.instance.recordError(e, st, fatal: false);
      } catch (_) {}
    }
  }

  bool _verifyPurchase(PurchaseDetails purchase) {
    try {
      if (purchase.productID.isEmpty) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _markPurchaseAnalyticsIfNew(PurchaseDetails purchase) {
    final id = purchase.purchaseID;
    if (id == null || id.isEmpty) return true;
    return _loggedPurchaseTransactionIds.add(id);
  }

  Future<bool> _handleSuccessfulPurchase(
    PurchaseDetails purchase,
    String userId, {
    required bool logPurchaseAnalytics,
  }) async {
    try {
      final productId = purchase.productID;
      if (productId.isEmpty) {
        if (kDebugMode) debugPrint('[Billing] _handleSuccessfulPurchase: empty productId, abort');
        return false;
      }
      final purchaseToken = purchase.verificationData.serverVerificationData;
      final duration = selectedDuration ?? _productIdToDuration(productId);

      if (logPurchaseAnalytics) {
        AnalyticsService.logPurchaseSuccess(
          productId: productId,
          price: lastPurchasePrice,
          value: lastPurchaseValue,
          currency: lastPurchaseCurrency,
          transactionId: purchase.purchaseID,
        );
        AnalyticsEventService().logAnalyticsEventPurchaseSuccess(userId, duration);
        try {
          AnalyticsFirestoreService().recordPremiumPurchased();
        } catch (_) {}
      }

      // SERVER-AUTHORITATIVE activation: hand the Play purchase token to the
      // backend, which verifies it with Google Play, enforces one-account-per-
      // purchase (ownership), and writes premiumExpiry. The client no longer
      // writes any premium fields — no races, no stale cache.
      final active = await _activateOnServer(purchaseToken, productId);
      debugPrint('[PAYDBG] server activation -> premium=$active uid=$userId');
      // The server persisted the receipt either way, so acknowledge the purchase.
      // (A restore of a purchase owned by another account returns premium=false;
      // acknowledging is still correct — the money/entitlement lives on Play.)
      return true;
    } catch (e, stack) {
      if (kDebugMode) debugPrint('[Billing] _handleSuccessfulPurchase error: $e');
      try {
        FirebaseCrashlytics.instance.recordError(e, stack, fatal: false);
      } catch (_) {}
      return false;
    }
  }

  /// Send the purchase token to the backend `/activate-premium`, then nudge the
  /// gate to re-ask the server. Returns whether the server granted premium.
  Future<bool> _activateOnServer(String purchaseToken, String productId) async {
    if (purchaseToken.isEmpty) return false;
    bool premium = false;
    try {
      final res = await ApiService().activatePremium(
        purchaseToken: purchaseToken,
        productId: productId,
      );
      premium = res['planType']?.toString().toLowerCase() == 'premium';
    } catch (e) {
      debugPrint('[PAYDBG] activatePremium call failed: $e');
    }
    // Tell the gate to re-check (it reads /check-ai-access — the source of truth).
    PremiumStatusNotifier.instance.markActivated();
    try {
      await PlanManager.instance.refresh();
    } catch (_) {}
    try {
      await AiUsageControlService.instance.refresh(force: true);
    } catch (_) {}
    return premium;
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

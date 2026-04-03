import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'premium_guard.dart';
import '../models/user_model.dart';
import 'analytics_event_service.dart';
import 'analytics_firestore_service.dart';
import 'analytics_service.dart';
import 'notification_service.dart';

class PremiumService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if user has active premium subscription (not trial)
  static bool isPremium(UserModel user) {
    if (!user.isPremium || user.premiumExpiry == null) {
      return false;
    }
    return user.premiumExpiry?.isAfter(DateTime.now()) ?? false;
  }
  
  /// Check if user is currently in trial period
  static bool isTrial(UserModel user) {
    if (!user.isTrialActive || user.trialEnd == null) {
      return false;
    }
    return user.trialEnd?.isAfter(DateTime.now()) ?? false;
  }
  
  /// Check if trial has expired (user was on trial but it ended)
  static bool trialExpired(UserModel user) {
    if (!user.isTrialActive || user.trialEnd == null) {
      return false;
    }
    final end = user.trialEnd;
    return end != null && DateTime.now().isAfter(end);
  }
  
  /// Check if user has active premium OR trial (for feature access)
  static bool hasActivePremium(UserModel user) {
    final now = DateTime.now();
    
    // Check if premium is active
    if (user.isPremium && user.premiumExpiry != null) {
      if (user.premiumExpiry?.isAfter(now) == true) {
        return true;
      }
    }
    
    // Check if trial is active
    if (user.isTrialActive && user.trialEnd != null) {
      if (user.trialEnd?.isAfter(now) == true) {
        return true;
      }
    }
    
    return false;
  }

  /// Check if trial is currently ongoing
  static bool isTrialOngoing(UserModel user) {
    if (!user.isTrialActive || user.trialEnd == null) return false;
    return user.trialEnd?.isAfter(DateTime.now()) ?? false;
  }

  /// Alias for isTrialOngoing
  static bool isTrialActive(UserModel user) => isTrialOngoing(user);

  /// Check if user can access premium features
  static bool canAccessPremiumFeatures(UserModel user) {
    return hasActivePremium(user);
  }

  /// Alias: is premium active (not expired)
  static bool isPremiumActive(UserModel user) => hasActivePremium(user);

  /// Alias: is trial currently active
  static bool trialActive(UserModel user) => isTrialOngoing(user);

  /// Check if trial has expired
  static bool isTrialExpired(UserModel user) {
    final end = user.trialEnd;
    if (!user.isTrialActive || end == null) return false;
    return DateTime.now().isAfter(end);
  }

  /// Get user's subscription status string
  static String getSubscriptionStatus(UserModel user) {
    final now = DateTime.now();
    
    final premiumExpiry = user.premiumExpiry;
    if (user.isPremium && premiumExpiry != null && premiumExpiry.isAfter(now)) {
      final planName = user.premiumPlan == 'basic' ? 'BASIC' : 'PRO';
      return 'Premium: $planName (expires: ${_formatDate(premiumExpiry)})';
    }
    
    final trialEnd = user.trialEnd;
    if (user.isTrialActive && trialEnd != null && trialEnd.isAfter(now)) {
      return 'Trial active – ends on ${_formatDate(trialEnd)}';
    }
    
    return 'Free plan – Upgrade to unlock all AI tools';
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// Initialize trial for new user
  Future<void> initializeTrial(String uid) async {
    try {
      final now = DateTime.now();
      final trialEnd = now.add(const Duration(days: 7));
      
      // Check if document exists
      final userDoc = await _firestore.collection('users').doc(uid).get();
      
      if (userDoc.exists) {
        await _firestore.collection('users').doc(uid).set({
          'isTrialActive': true,
          'trialStart': Timestamp.fromDate(now),
          'trialEnd': Timestamp.fromDate(trialEnd),
          'trialExpiry': Timestamp.fromDate(trialEnd),
          'isPremium': userDoc.data()?['isPremium'] ?? false,
          'premiumPlan': userDoc.data()?['premiumPlan'] ?? 'none',
          'premiumDuration': userDoc.data()?['premiumDuration'] ?? 'none',
          'premiumExpiry': userDoc.data()?['premiumExpiry'],
        }, SetOptions(merge: true));
      } else {
        final authUser = FirebaseAuth.instance.currentUser;
        await _firestore.collection('users').doc(uid).set({
          'email': authUser?.email ?? '',
          'displayName': authUser?.displayName,
          'photoURL': authUser?.photoURL,
          'subscriptionPlan': 'trial',
          'createdAt': FieldValue.serverTimestamp(),
          'preferences': {},
          'isTrialActive': true,
          'trialStart': Timestamp.fromDate(now),
          'trialEnd': Timestamp.fromDate(trialEnd),
          'trialExpiry': Timestamp.fromDate(trialEnd),
          'isPremium': false,
          'premiumPlan': 'none',
          'premiumDuration': 'none',
          'premiumExpiry': null,
          'dailyAiUsed': 0,
          'lastAiReset': Timestamp.fromDate(now),
        });
      }
      AnalyticsEventService().logTrialStarted();
      AnalyticsEventService().logAnalyticsEventTrialStart(uid);
      AnalyticsService.logTrialStarted();
      AnalyticsFirestoreService().recordTrialStarted();
    } catch (e) {
      if (kDebugMode) debugPrint('Error initializing trial: $e');
      rethrow;
    }
  }

  /// Activate premium: write isPremium, premiumStart (serverTimestamp), premiumExpiry, planDuration (months).
  /// Auto-remove expired is done in checkPremiumExpiry / on read where needed.
  Future<void> activatePremium(String uid, int durationMonths) async {
    final now = DateTime.now();
    final expiry = DateTime(now.year, now.month + durationMonths, now.day, now.hour, now.minute);
    try {
      final updates = <String, dynamic>{
        'isPremium': true,
        'premiumStart': FieldValue.serverTimestamp(),
        'premiumExpiry': Timestamp.fromDate(expiry),
        'planDuration': durationMonths,
        'premiumPlan': 'pro',
        'premiumDuration': _durationKeyFromMonths(durationMonths),
        'isTrialActive': false,
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      await _firestore.collection('users').doc(uid).update(updates);
      if (kDebugMode) debugPrint('[PremiumService] activatePremium uid=$uid months=$durationMonths expiry=$expiry');
    } catch (e) {
      if (kDebugMode) debugPrint('[PremiumService] activatePremium error: $e');
      rethrow;
    }
  }

  static String _durationKeyFromMonths(int months) {
    if (months <= 1) return '1m';
    if (months <= 3) return '3m';
    if (months <= 6) return '6m';
    return '12m';
  }

  /// Premium expiry auto check. Call on app start and after login.
  /// If premiumExpiry - now <= 1 day and not notified → sendPremiumExpiringSoonNotification, set premiumExpiryNotified=true.
  /// If isPremium == true AND premiumExpiry < now → set isPremium = false, sendPremiumExpiredNotification.
  Future<void> checkPremiumExpiry(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return;
      final data = doc.data();
      if (data == null) return;
      final isPremium = data['isPremium'] == true;
      final premiumExpiry = (data['premiumExpiry'] as Timestamp?)?.toDate();
      if (!isPremium || premiumExpiry == null) return;

      final now = DateTime.now();
      if (now.isAfter(premiumExpiry)) {
        await _firestore.collection('users').doc(uid).update({
          'isPremium': false,
          'premiumPlan': 'none',
          'premiumDuration': 'none',
          'premiumExpiry': null,
          'premiumStartDate': null,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        await NotificationService().sendPremiumExpiredNotification(uid);
        if (kDebugMode) debugPrint('[PremiumService] Premium expired for $uid (expiry was $premiumExpiry)');
        return;
      }

      final oneDay = const Duration(days: 1);
      if (premiumExpiry.difference(now) <= oneDay && data['premiumExpiryNotified'] != true) {
        await NotificationService().sendPremiumExpiringSoonNotification(uid);
        await _firestore.collection('users').doc(uid).update({'premiumExpiryNotified': true});
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[PremiumService] checkPremiumExpiry error: $e');
    }
  }

  /// Trial expiry auto check. Call after login and on app start.
  /// Uses normalized fields: trialEndDate (or trialEnd). If trial ended → planType=free, daily reset. No legacy flags.
  Future<void> checkAndUpdateTrialExpiry(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) return;

      final data = userDoc.data();
      if (data == null) return;
      final planType = (data['planType'] as String?)?.toLowerCase();
      final trialEnd = (data['trialEndDate'] as Timestamp?)?.toDate() ?? (data['trialEnd'] as Timestamp?)?.toDate();
      if (trialEnd == null) return;

      final now = DateTime.now();
      final bool trialStillActive = !now.isAfter(trialEnd);

      if (planType == 'trial' && trialStillActive) {
        final oneDay = const Duration(days: 1);
        if (trialEnd.difference(now) <= oneDay && data['trialEndingNotified'] != true) {
          await NotificationService().sendTrialEndingSoonNotification(uid);
          await _firestore.collection('users').doc(uid).update({'trialEndingNotified': true});
        }
        return;
      }

      if ((planType == 'trial' || planType == null) && !trialStillActive) {
        final now = DateTime.now();
        final todayMidnight = DateTime(now.year, now.month, now.day);
        await _firestore.collection('users').doc(uid).update({
          'planType': 'free',
          'dailyUsedCount': 0,
          'dailyResetDate': Timestamp.fromDate(todayMidnight),
        });
        AnalyticsEventService().logTrialExpired();
        AnalyticsService.logTrialExpired();
        await NotificationService().sendTrialExpiredNotification(uid);
        if (kDebugMode) debugPrint('[PremiumService] Trial expired for $uid: planType=free');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[PremiumService] checkAndUpdateTrialExpiry error: $e');
    }
  }

  /// Update user to premium with plan/duration (legacy). Use activatePremium(uid, months) or activatePremiumForDuration for billing.
  Future<void> activatePremiumWithPlan({
    required String uid,
    required String plan,
    required String duration,
    DateTime? premiumStartDate,
    DateTime? premiumExpiry,
  }) async {
    final now = DateTime.now();
    final start = premiumStartDate ?? now;
    final expiry = premiumExpiry ??
        DateTime(
          now.year,
          now.month + _getMonthsFromDuration(duration),
          now.day,
          now.hour,
          now.minute,
        );

    String subscriptionType = 'premium_monthly';
    switch (duration) {
      case '1m':
        subscriptionType = 'premium_monthly';
        break;
      case '3m':
        subscriptionType = 'premium_3month';
        break;
      case '6m':
        subscriptionType = 'premium_6month';
        break;
      case '12m':
        subscriptionType = 'premium_12month';
        break;
      default:
        subscriptionType = 'premium_monthly';
    }

    final doc = await _firestore.collection('users').doc(uid).get();
    final hadTrial = doc.exists && doc.data()?['trialStart'] != null;
    final updates = <String, dynamic>{
      'isPremium': true,
      'premiumPlan': plan,
      'premiumDuration': duration,
      'subscriptionType': subscriptionType,
      'premiumStartDate': Timestamp.fromDate(start),
      'premiumExpiry': Timestamp.fromDate(expiry),
      'isTrialActive': false,
      'trialExpired': false,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
    if (hadTrial) updates['convertedFromTrial'] = true;
    await _firestore.collection('users').doc(uid).update(updates);

    AnalyticsEventService().logPremiumActivated(plan);

    final notificationService = NotificationService();
    await notificationService.sendSubscriptionSuccessNotification(plan);
    await notificationService.cancelTrialExpiryWarning();
    await notificationService.schedulePremiumExpiryWarning(expiry);
    if (kDebugMode) debugPrint('[PremiumService] activatePremiumWithPlan: expiry=$expiry, notification scheduled (expiry - 1 day)');
  }

  /// Activate premium from purchase/restore/renewal.
  /// productId is always premium_monthly; duration (1m, 3m, 6m, 12m) comes from selected base plan.
  /// duration: optional — when productId is premium_monthly, use this to get days (1m=30, 3m=90, 6m=180, 12m=365).
  Future<void> activatePremiumByProductId(String uid, String productId, {String? duration}) async {
    int days = 30;
    if (productId == 'premium_monthly' && duration != null) {
      const durationDays = {'1m': 30, '3m': 90, '6m': 180, '12m': 365};
      days = durationDays[duration] ?? 30;
    } else {
      const legacyDurationDays = {
        'premium_monthly': 30,
        'premium_3month': 90,
        'premium_6month': 180,
        'premium_12month': 365,
      };
      days = legacyDurationDays[productId] ?? 30;
    }

    String durationKey = duration ?? '1m';
    if (productId != 'premium_monthly') {
      if (productId == 'premium_3month') durationKey = '3m';
      else if (productId == 'premium_6month') durationKey = '6m';
      else if (productId == 'premium_12month') durationKey = '12m';
    }

    final now = DateTime.now();
    final docRef = _firestore.collection('users').doc(uid);
    final doc = await docRef.get();

    bool isRenewal = false;
    DateTime expiry = now.add(Duration(days: days));

    if (doc.exists) {
      final data = doc.data();
      if (data != null) {
        final currentExpiry = (data['premiumExpiry'] as Timestamp?)?.toDate();
        final storedProductId = data['premiumProductId'] as String?;
        final isPremium = data['isPremium'] ?? false;

        if (isPremium &&
            storedProductId == productId &&
            currentExpiry != null &&
            currentExpiry.isAfter(now)) {
          isRenewal = true;
          expiry = currentExpiry.add(Duration(days: days));
          if (kDebugMode) debugPrint(
              '[PremiumService] Renewal detected: productId=$productId, extending expiry from $currentExpiry to $expiry');
        }
      }
    }

    if (!isRenewal) {
      expiry = now.add(Duration(days: days));
      if (kDebugMode) debugPrint(
          '[PremiumService] New purchase/restore: productId=$productId days=$days expiry=$expiry');
    }

    if (isRenewal) {
      await docRef.update({
        'premiumExpiry': Timestamp.fromDate(expiry),
        'premiumExpiryNotified': false,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } else {
      final docData = doc.data();
      final data = (doc.exists && docData != null) ? docData : <String, dynamic>{};
      final hadTrial = data['trialStart'] != null;
      final updates = <String, dynamic>{
        'isPremium': true,
        'premiumPlan': 'pro',
        'premiumDuration': durationKey,
        'premiumProductId': productId,
        'premiumStartDate': Timestamp.fromDate(now),
        'premiumExpiry': Timestamp.fromDate(expiry),
        'isTrialActive': false,
        'trialExpired': false,
        'premiumExpiryNotified': false,
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      if (hadTrial) updates['convertedFromTrial'] = true;
      await docRef.update(updates);
      AnalyticsEventService().logPremiumActivated(durationKey);
    }

    final notificationService = NotificationService();
    await notificationService.cancelTrialExpiryWarning();
    await notificationService.schedulePremiumExpiryWarning(expiry);
    await notificationService.sendPremiumActivatedNotification(uid, expiry);
    if (!isRenewal) {
      await notificationService.sendSubscriptionSuccessNotification('pro');
    }
    if (kDebugMode) debugPrint(
        '[PremiumService] activatePremiumByProductId: productId=$productId days=$days expiry=$expiry isRenewal=$isRenewal');
  }

  /// Called after Firestore is updated by billing. Schedules "Premium Ending Soon" and sends success notification.
  Future<void> onPremiumActivated(String uid, DateTime premiumExpiry) async {
    final notificationService = NotificationService();
    await notificationService.cancelTrialExpiryWarning();
    await notificationService.schedulePremiumExpiryWarning(premiumExpiry);
    await notificationService.sendSubscriptionSuccessNotification('pro');
    await notificationService.sendPremiumActivatedNotification(uid, premiumExpiry);
    await _firestore.collection('users').doc(uid).update({'premiumExpiryNotified': false});
    if (kDebugMode) debugPrint('[PremiumService] onPremiumActivated: notification scheduled for expiry - 1 day ($premiumExpiry)');
  }

  int _getMonthsFromDuration(String duration) {
    switch (duration) {
      case '1m':
        return 1;
      case '3m':
        return 3;
      case '6m':
        return 6;
      case '12m':
        return 12;
      default:
        return 1;
    }
  }

  /// Get user data with subscription info
  Future<Map<String, dynamic>?> getUserSubscriptionData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Can user use AI this time? Premium → true; Trial → true; Free → dailyAiUsed < 2.
  static bool canUseAi(UserModel user) {
    if (hasActivePremium(user)) return true;
    if (isTrialActive(user)) return true;
    final used = user.dailyFreeUsedCount;
    return used < 2;
  }

  /// Reset daily count if lastAiReset is not today. Call before checking canUseAi.
  Future<void> resetDailyIfNeeded(String uid) async {
    try {
      final docRef = _firestore.collection('users').doc(uid);
      final doc = await docRef.get().timeout(const Duration(seconds: 5));
      if (!doc.exists) return;
      final data = doc.data() ?? {};
      final resetDate = (data['dailyResetDate'] as Timestamp?)?.toDate() ?? (data['lastAiReset'] as Timestamp?)?.toDate();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (resetDate == null) return;
      final resetDay = DateTime(resetDate.year, resetDate.month, resetDate.day);
      if (resetDay.isBefore(today)) {
        await docRef.update({
          'dailyUsedCount': 0,
          'dailyResetDate': Timestamp.fromDate(today),
        });
        if (kDebugMode) debugPrint('[PremiumService] Daily AI reset for $uid');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[PremiumService] resetDailyIfNeeded error: $e');
    }
  }

  /// Increment daily AI usage (legacy). Prefer MonetizationService.checkAndConsumeAIUsage which handles consume.
  /// Writes dailyUsedCount/dailyResetDate and ai_usage_logs for analytics.
  Future<void> incrementDailyAiUsage(String uid, {String? toolName}) async {
    try {
      final now = DateTime.now();
      final docRef = _firestore.collection('users').doc(uid);
      final doc = await docRef.get().timeout(const Duration(seconds: 5));
      if (!doc.exists) return;
      final data = doc.data() ?? {};
      final today = DateTime(now.year, now.month, now.day);
      final resetDate = (data['dailyResetDate'] as Timestamp?)?.toDate();
      int count = 0;
      if (resetDate != null) {
        final resetDay = DateTime(resetDate.year, resetDate.month, resetDate.day);
        if (!resetDay.isBefore(today)) {
          final raw = data['dailyUsedCount'] ?? data['dailyAiUsed'];
          count = raw is int ? raw : (raw is num ? raw.toInt() : 0);
        }
      }
      final aiToday = (data['aiUsesToday'] is int ? data['aiUsesToday'] as int : (data['aiUsesToday'] is num ? (data['aiUsesToday'] as num).toInt() : 0));
      final aiTotal = (data['aiUsesTotal'] is int ? data['aiUsesTotal'] as int : (data['aiUsesTotal'] is num ? (data['aiUsesTotal'] as num).toInt() : 0));

      await docRef.update({
        'dailyUsedCount': count + 1,
        'dailyResetDate': Timestamp.fromDate(today),
        'aiUsesToday': aiToday + 1,
        'aiUsesTotal': aiTotal + 1,
      });
      final email = (doc.data()?['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '').toString();
      await _firestore.collection('ai_usage_logs').add({
        'uid': uid,
        'email': email,
        'usedAt': FieldValue.serverTimestamp(),
        'toolName': (toolName == null || toolName.isEmpty) ? 'unknown' : toolName,
      });
      if (kDebugMode) debugPrint('[PremiumService] incrementDailyAiUsage $uid → ${count + 1}');
    } catch (e) {
      if (kDebugMode) debugPrint('[PremiumService] incrementDailyAiUsage error: $e');
    }
  }

  /// Activate premium for duration. Duration: 1m=30, 3m=90, 6m=180, 12m=365 days.
  /// Writes premiumStart (serverTimestamp), premiumExpiry, planDuration (months). Used by billing.
  /// [purchaseToken] from Play Billing (serverVerificationData) for backend refund verification.
  Future<void> activatePremiumForDuration(String uid, String duration, {String? purchaseToken}) async {
    const durationDays = {'1m': 30, '3m': 90, '6m': 180, '12m': 365};
    const durationMonths = {'1m': 1, '3m': 3, '6m': 6, '12m': 12};
    final days = durationDays[duration] ?? 30;
    final months = durationMonths[duration] ?? 1;
    final now = DateTime.now();
    final expiry = now.add(Duration(days: days));
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final hadTrial = doc.exists && doc.data()?['trialStart'] != null;
      final updates = <String, dynamic>{
        'isPremium': true,
        'premiumPlan': 'pro',
        'premiumDuration': duration,
        'premiumExpiry': Timestamp.fromDate(expiry),
        'premiumStart': FieldValue.serverTimestamp(),
        'premiumStartDate': Timestamp.fromDate(now),
        'planDuration': months,
        'isTrialActive': false,
        'trialExpired': true,
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      if (hadTrial) updates['convertedFromTrial'] = true;
      if (purchaseToken != null && purchaseToken.trim().isNotEmpty) {
        updates['subscriptionPurchaseToken'] = purchaseToken.trim();
      }
      await _firestore.collection('users').doc(uid).update(updates);
      AnalyticsEventService().logPremiumActivated(duration);
      final notificationService = NotificationService();
      await notificationService.sendPremiumActivatedNotification(uid, expiry);
      if (kDebugMode) debugPrint('[PremiumService] activatePremium $uid duration=$duration expiry=$expiry');
    } catch (e) {
      if (kDebugMode) debugPrint('[PremiumService] activatePremium error: $e');
      rethrow;
    }
  }

  /// Start 7-day trial for user. Writes trialStart, trialExpiry (and trialEnd for compat).
  Future<void> startTrial(String uid) async {
    await initializeTrial(uid);
  }

  /// Submits purchase to Firestore for server verification. Writes subscription payload with verified=false.
  /// Backend should validate purchaseToken and set subscription.verified = true (and isPremium/premiumExpiry).
  /// [markVerifiedAndActivate] true = MVP client-side unlock; false = production (unlock only after backend verification).
  Future<void> submitPurchaseToFirestore({
    required String uid,
    required String productId,
    required String purchaseToken,
    required int purchaseTimeMillis,
    DateTime? transactionDate,
    String platform = 'android',
    bool markVerifiedAndActivate = false,
    String? duration,
  }) async {
    try {
      final now = DateTime.now();
      final updates = <String, dynamic>{
        'subscription': {
          'productId': productId,
          'purchaseToken': purchaseToken,
          'purchaseTime': purchaseTimeMillis,
          'transactionDate': transactionDate != null ? Timestamp.fromDate(transactionDate) : purchaseTimeMillis,
          'platform': platform,
          'verified': markVerifiedAndActivate,
          'updatedAt': Timestamp.fromDate(now),
        },
        if (markVerifiedAndActivate) 'premiumVerified': true,
      };
      await _firestore.collection('users').doc(uid).set(updates, SetOptions(merge: true));
      if (markVerifiedAndActivate && duration != null) {
        await activatePremiumForDuration(uid, duration, purchaseToken: purchaseToken);
      }
      PremiumGuard().invalidateCache();
    } catch (e, stack) {
      if (kDebugMode) debugPrint('[PremiumService] submitPurchaseToFirestore error: $e');
      FirebaseCrashlytics.instance.recordError(e, stack, fatal: false);
      rethrow;
    }
  }

  /// Check if user can access premium features (without UserModel)
  static Future<bool> canAccessPremium(String uid) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      
      if (!userDoc.exists) return false;
      
      final data = userDoc.data();
      if (data == null) return false;
      final isPremium = data['isPremium'] ?? false;
      final premiumExpiry = (data['premiumExpiry'] as Timestamp?)?.toDate();
      final isTrialActive = data['isTrialActive'] ?? false;
      final trialEnd = (data['trialEnd'] as Timestamp?)?.toDate();
      
      final now = DateTime.now();
      
      if (isPremium && premiumExpiry != null && premiumExpiry.isAfter(now)) {
        return true;
      }
      
      if (isTrialActive && trialEnd != null && trialEnd.isAfter(now)) {
        return true;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }
}


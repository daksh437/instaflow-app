import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'premium_service.dart';
import 'premium_guard.dart';
import 'usage_tracking_service.dart';

/// Central access control: premium = unlimited + no ads; trial = unlimited + show ads; free = 2 AI/day + show ads.
class AccessControlService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UsageTrackingService _usage = UsageTrackingService();

  /// Load user from Firestore.
  Future<UserModel?> getUser(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data();
      if (doc.exists && data != null) {
        return UserModel.fromFirestore(data, userId);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// True if user has active premium (Google Play purchase, premiumExpiry in future).
  bool isPremium(UserModel user) => PremiumService.isPremium(user);

  /// True if user is in 7-day trial (trialEnd in future).
  bool isTrial(UserModel user) => PremiumService.isTrialOngoing(user);

  /// True if trial has ended (free tier).
  bool isFreeAfterTrial(UserModel user) =>
      !PremiumService.hasActivePremium(user) &&
      (user.trialStart != null || user.trialEnd != null);

  /// canUseAI(uid): server-verified premium → true; trial → true; free → usageTracking.canUseAITool.
  Future<bool> canUseAI(String userId) async {
    if (await PremiumGuard().isPremium(userId)) return true;
    final user = await getUser(userId);
    if (user == null) return false;
    if (user.isTrialActive && user.trialEnd?.isAfter(DateTime.now()) == true) return true;
    return _usage.canUseAITool(userId);
  }

  /// remainingFreeUsesToday(uid): server-verified premium or trial → -1; else 2 - dailyFreeUsedCount.
  Future<int> remainingFreeUsesToday(String userId) async {
    if (await PremiumGuard().isPremium(userId)) return -1;
    final user = await getUser(userId);
    if (user == null) return 0;
    if (user.isTrialActive && user.trialEnd?.isAfter(DateTime.now()) == true) return -1;
    final used = await _usage.getDailyFreeUsedCount(userId);
    return (2 - used).clamp(0, 2);
  }

  /// Remaining rewarded-ad bonuses available today (0..3). Free users only; premium/trial returns 0.
  Future<int> remainingRewardedBonusesToday(String userId) async {
    if (await PremiumGuard().isPremium(userId)) return 0;
    final user = await getUser(userId);
    if (user == null) return 0;
    if (PremiumService.hasActivePremium(user)) return 0;
    final bonus = await _usage.getRewardedBonusCountToday(userId);
    return (UsageTrackingService.rewardedBonusMaxPerDay - bonus).clamp(0, UsageTrackingService.rewardedBonusMaxPerDay);
  }

  /// Record one AI use (call after successful generation). Handles free-user increment.
  Future<void> recordAiUse(String userId) async {
    if (await PremiumGuard().isPremium(userId)) return;
    final user = await getUser(userId);
    if (user == null) return;
    if (PremiumService.hasActivePremium(user)) return;
    await _usage.recordAiUse(userId);
  }

  /// Apply trial expiry: delegates to PremiumService.checkAndUpdateTrialExpiry.
  Future<void> applyTrialExpiryIfNeeded(String userId) async {
    await PremiumService().checkAndUpdateTrialExpiry(userId);
  }
}

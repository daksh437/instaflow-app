import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'premium_service.dart';

/// Usage: premium/trial = unlimited; free = 2 AI/day (+ rewarded bonuses). Reset dailyFreeUsedCount when lastUsageDate is not today. Increment only after successful AI generation.
class UsageTrackingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Max AI tool uses per day for free users (after trial), before any rewarded-ad bonuses.
  static const int freeDailyLimit = 2;

  /// Max rewarded-ad bonuses per day (+1 extra use each, up to 3).
  static const int rewardedBonusMaxPerDay = 3;

  // AI Tools (2 uses/day total after trial)
  static const List<String> aiTools = [
    'hashtag-generator',
    'bio-maker',
    'post-ideas',
    'trending-hashtags',
    'viral-hook',
    'comment-reply',
    'carousel-writer',
  ];

  // AI Marketing Tools (same 2/day limit after trial; blocked only if you want stricter — we treat same as aiTools)
  static const List<String> aiMarketingTools = [
    'ai-caption',
    'ai-captions',
    'ai-calendar',
    'ai-strategy',
    'niche-analysis',
    'reels-script',
  ];

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Returns current daily count for free users (after reset if new day). Does not modify.
  Future<int> getDailyFreeUsedCount(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return 0;
      final data = doc.data();
      if (data == null) return 0;
      final lastUsage = (data['lastUsageDate'] as Timestamp?)?.toDate();
      final raw = data['dailyFreeUsedCount'];
      final count = raw is int ? raw : (raw is num ? raw.toInt() : 0);
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      if (lastUsage == null) return 0;
      final lastDay = DateTime(lastUsage.year, lastUsage.month, lastUsage.day);
      if (lastDay.isBefore(today)) return 0;
      return count;
    } catch (e) {
      if (kDebugMode) debugPrint('[UsageTracking] getDailyFreeUsedCount error: $e');
      return 0;
    }
  }

  /// Daily reset: if lastUsageDate is not today, set dailyFreeUsedCount = 0.
  Future<void> _resetDailyIfNewDay(String userId) async {
    try {
      final docRef = _firestore.collection('users').doc(userId);
      final doc = await docRef.get();
      if (!doc.exists) return;
      final data = doc.data();
      if (data == null) return;
      final lastUsage = (data['lastUsageDate'] as Timestamp?)?.toDate();
      if (lastUsage == null) return;
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final lastDay = DateTime(lastUsage.year, lastUsage.month, lastUsage.day);
      if (lastDay.isBefore(today)) {
        await docRef.update({
          'dailyFreeUsedCount': 0,
          'lastUsageDate': Timestamp.fromDate(DateTime.now()),
          if (data.containsKey('rewardedBonusCountToday')) 'rewardedBonusCountToday': 0,
        });
        if (kDebugMode) debugPrint('[UsageTracking] Daily counter reset for $userId (lastUsage was not today)');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[UsageTracking] _resetDailyIfNewDay error: $e');
    }
  }

  /// Rewarded-ad bonus count for today (0 if new day or none yet). Resets when lastRewardedBonusDate is not today.
  Future<int> getRewardedBonusCountToday(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return 0;
      final data = doc.data();
      if (data == null) return 0;
      final lastBonus = (data['lastRewardedBonusDate'] as Timestamp?)?.toDate();
      if (lastBonus == null) return 0;
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final lastDay = DateTime(lastBonus.year, lastBonus.month, lastBonus.day);
      if (lastDay.isBefore(today)) return 0;
      return (data['rewardedBonusCountToday'] as int?) ?? 0;
    } catch (e) {
      if (kDebugMode) debugPrint('[UsageTracking] getRewardedBonusCountToday error: $e');
      return 0;
    }
  }

  /// Grant +1 extra AI use today when user completes a rewarded ad. Max 3 per day. Call from onUserEarnedReward.
  /// Decrements dailyFreeUsedCount (and dailyAiUsed) by 1 so user gets one more use; also records bonus count for cap.
  Future<void> addRewardedBonus(String userId) async {
    try {
      await grantRewardedExtraUse(userId);
    } catch (e) {
      if (kDebugMode) debugPrint('[UsageTracking] addRewardedBonus error: $e');
    }
  }

  /// Grant +1 use by decrementing daily count (min 0). Max 3 rewards per day. Call after rewarded ad success.
  Future<void> grantRewardedExtraUse(String userId) async {
    try {
      final docRef = _firestore.collection('users').doc(userId);
      final doc = await docRef.get();
      if (!doc.exists) return;
      final data = doc.data();
      if (data == null) return;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final lastBonus = (data['lastRewardedBonusDate'] as Timestamp?)?.toDate();
      int currentBonus = 0;
      if (lastBonus != null) {
        final lastDay = DateTime(lastBonus.year, lastBonus.month, lastBonus.day);
        if (!lastDay.isBefore(today)) {
          currentBonus = (data['rewardedBonusCountToday'] as int?) ?? 0;
        }
      }
      if (currentBonus >= rewardedBonusMaxPerDay) {
        if (kDebugMode) debugPrint('[UsageTracking] grantRewardedExtraUse: already at max ($rewardedBonusMaxPerDay) for today');
        return;
      }
      final lastUsage = (data['lastUsageDate'] as Timestamp?)?.toDate() ?? (data['lastAiReset'] as Timestamp?)?.toDate();
      final rawCount = data['dailyFreeUsedCount'] ?? data['dailyAiUsed'];
      int used = rawCount is int ? rawCount : (rawCount is num ? rawCount.toInt() : 0);
      if (lastUsage != null) {
        final lastDay = DateTime(lastUsage.year, lastUsage.month, lastUsage.day);
        if (lastDay.isBefore(today)) used = 0;
      }
      final newCount = (used - 1).clamp(0, 999);
      await docRef.update({
        'dailyFreeUsedCount': newCount,
        'dailyAiUsed': newCount,
        'lastUsageDate': Timestamp.fromDate(now),
        'lastAiReset': Timestamp.fromDate(now),
        'rewardedBonusCountToday': currentBonus + 1,
        'lastRewardedBonusDate': Timestamp.fromDate(now),
      });
      if (kDebugMode) debugPrint('[UsageTracking] grantRewardedExtraUse: +1 use (${currentBonus + 1}/$rewardedBonusMaxPerDay today), count now $newCount');
    } catch (e) {
      if (kDebugMode) debugPrint('[UsageTracking] grantRewardedExtraUse error: $e');
    }
  }

  /// Effective daily limit = 2 base + min(rewarded bonuses today, 3).
  Future<int> getEffectiveDailyLimit(String userId) async {
    final bonus = await getRewardedBonusCountToday(userId);
    return freeDailyLimit + (bonus > rewardedBonusMaxPerDay ? rewardedBonusMaxPerDay : bonus);
  }

  /// canUseAITool(uid): premium → true; trial (isTrialActive / trialEnd > now) → true; else free: reset if lastUsageDate not today, allow only if dailyFreeUsedCount < 2.
  Future<bool> canUseAITool(String userId) async {
    try {
      final userData = await _getUserData(userId);
      if (userData == null) return false;
      final user = UserModel.fromFirestore(userData, userId);

      if (user.isPremium && user.premiumExpiry != null && user.premiumExpiry!.isAfter(DateTime.now())) return true;
      if (user.isTrialActive && user.trialEnd != null && user.trialEnd?.isAfter(DateTime.now()) == true) return true;

      await _resetDailyIfNewDay(userId);
      final count = await getDailyFreeUsedCount(userId);
      final allowed = freeDailyLimit;
      return count < allowed;
    } catch (e) {
      if (kDebugMode) debugPrint('[UsageTracking] canUseAITool error: $e');
      return false;
    }
  }

  /// Same as canUseAITool for marketing tools (same limit: 2/day after trial).
  Future<bool> canUseAIMarketingTool(String userId) async => canUseAITool(userId);

  /// Legacy: per-tool check. Now uses global daily count.
  Future<bool> canUseAIToolById(String toolId, String userId) async => canUseAITool(userId);

  /// recordAiUse(uid): reset counter if date changed; increment dailyFreeUsedCount; set lastUsageDate = now. Call only after successful AI generation.
  Future<void> recordAiUse(String userId) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final docRef = _firestore.collection('users').doc(userId);
      final doc = await docRef.get();
      if (!doc.exists) return;

      final data = doc.data();
      if (data == null) return;
      final lastUsage = (data['lastUsageDate'] as Timestamp?)?.toDate();
      final rawCount = data['dailyFreeUsedCount'];
      final currentCount = rawCount is int ? rawCount : (rawCount is num ? rawCount.toInt() : 0);

      if (lastUsage == null) {
        await docRef.update({
          'dailyFreeUsedCount': 1,
          'lastUsageDate': Timestamp.fromDate(now),
        });
        if (kDebugMode) debugPrint('[UsageTracking] Usage recorded for $userId: count=1 (first today)');
        return;
      }

      final lastDay = DateTime(lastUsage.year, lastUsage.month, lastUsage.day);
      if (lastDay.isBefore(today)) {
        await docRef.update({
          'dailyFreeUsedCount': 1,
          'lastUsageDate': Timestamp.fromDate(now),
        });
        if (kDebugMode) debugPrint('[UsageTracking] Usage recorded for $userId: count=1 (new day reset)');
      } else {
        await docRef.update({
          'dailyFreeUsedCount': currentCount + 1,
          'lastUsageDate': Timestamp.fromDate(now),
        });
        if (kDebugMode) debugPrint('[UsageTracking] Usage recorded for $userId: count=${currentCount + 1}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[UsageTracking] recordAiUse error: $e');
    }
  }

  /// Track tool usage: for free users increments global daily count; also keeps per-tool subcollection for analytics.
  Future<void> trackToolUsage(String toolId, String userId) async {
    try {
      final userData = await _getUserData(userId);
      if (userData != null) {
        final user = UserModel.fromFirestore(userData, userId);
        if (!PremiumService.hasActivePremium(user)) {
          await recordAiUse(userId);
        }
      }

      final now = DateTime.now();
      final todayKey = _todayKey();
      final usageRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('tool_usage')
          .doc(toolId);

      final doc = await usageRef.get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          final lastDate = (data['lastDate'] as String?) ?? '';
          if (lastDate == todayKey) {
            await usageRef.update({
              'count': FieldValue.increment(1),
              'lastUsed': FieldValue.serverTimestamp(),
              'lastDate': todayKey,
            });
          } else {
            await usageRef.update({
              'count': 1,
              'lastUsed': FieldValue.serverTimestamp(),
              'lastDate': todayKey,
            });
          }
        }
      } else {
        await usageRef.set({
          'toolId': toolId,
          'count': 1,
          'lastUsed': FieldValue.serverTimestamp(),
          'lastDate': todayKey,
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[UsageTracking] trackToolUsage error: $e');
    }
  }

  Future<Map<String, dynamic>?> _getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, int>> getAllToolUsage(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('tool_usage')
          .get();
      final usage = <String, int>{};
      for (var doc in snapshot.docs) {
        usage[doc.id] = (doc.data()['count'] as int?) ?? 0;
      }
      return usage;
    } catch (e) {
      return {};
    }
  }

  static bool isAITool(String toolId) => aiTools.contains(toolId);
  static bool isAIMarketingTool(String toolId) => aiMarketingTools.contains(toolId);
}




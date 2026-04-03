import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/daily_viral_drop_model.dart';
import 'firestore_helpers.dart';
import 'premium_service.dart';
import '../models/user_model.dart';

/// Firestore: daily_viral_drops collection. Each doc = one drop (userId, dateKey, drop, createdAt).
/// Limits: premium = 3 drops/day, free = 1 drop/day. Streak = consecutive days with at least one drop.
class DailyViralDropService {
  static const String _collection = 'daily_viral_drops';
  static const int maxDropsFree = 1;
  static const int maxDropsPremium = 3;

  static String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Max drops per day for this user (does not touch billing/auth).
  int maxDropsPerDay(UserModel? user) {
    if (user == null) return maxDropsFree;
    return PremiumService.hasActivePremium(user) ? maxDropsPremium : maxDropsFree;
  }

  /// Number of drops already used today by this user.
  Future<int> getDropsUsedToday(String userId) async {
    final dateKey = _dateKey(DateTime.now());
    try {
      final docs = await FirestoreHelpers.safeQuery(
        FirebaseFirestore.instance
            .collection(_collection)
            .where('userId', isEqualTo: userId)
            .where('dateKey', isEqualTo: dateKey),
      );
      return docs.length;
    } catch (e) {
      if (kDebugMode) debugPrint('[DailyViralDropService] getDropsUsedToday: $e');
      return 0;
    }
  }

  /// Whether user can request another drop today.
  Future<bool> canRequestDropToday(String userId, UserModel? user) async {
    final used = await getDropsUsedToday(userId);
    final max = maxDropsPerDay(user);
    return used < max;
  }

  /// Remaining drops for today.
  Future<int> remainingDropsToday(String userId, UserModel? user) async {
    final used = await getDropsUsedToday(userId);
    final max = maxDropsPerDay(user);
    return (max - used).clamp(0, max);
  }

  /// Get cached drop for user for a given date (one doc for that user+date).
  Future<DailyViralDropCacheEntry?> getCachedDrop(String userId, String dateKey) async {
    final docs = await FirestoreHelpers.safeQuery(
      FirebaseFirestore.instance
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('dateKey', isEqualTo: dateKey)
          .limit(1),
    );
    if (docs.isEmpty) return null;
    final data = docs.first.data();
    if (data == null) return null;
    return DailyViralDropCacheEntry.fromFirestore(data);
  }

  /// Get today's cached drop if any.
  Future<DailyViralDropCacheEntry?> getTodayCachedDrop(String userId) async {
    return getCachedDrop(userId, _dateKey(DateTime.now()));
  }

  /// Save a drop for user for today (adds a doc; premium can have up to 3 per day).
  Future<bool> saveCachedDrop({
    required String userId,
    required DailyViralDropModel drop,
    String? trendKeyword,
  }) async {
    final dateKey = _dateKey(DateTime.now());
    final entry = DailyViralDropCacheEntry(
      userId: userId,
      dateKey: dateKey,
      drop: drop,
      createdAt: DateTime.now(),
      trendKeyword: trendKeyword,
    );
    final id = await FirestoreHelpers.safeAddDoc(_collection, entry.toFirestore());
    return id != null;
  }

  /// Streak: consecutive days (including today) with at least one drop. Queries last 30 days.
  Future<int> getStreak(String userId) async {
    try {
      final now = DateTime.now();
      int streak = 0;
      for (int i = 0; i < 30; i++) {
        final d = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
        final key = _dateKey(d);
        final cached = await getCachedDrop(userId, key);
        if (cached != null) {
          streak++;
        } else {
          if (i == 0) continue;
          break;
        }
      }
      return streak;
    } catch (e) {
      if (kDebugMode) debugPrint('[DailyViralDropService] getStreak: $e');
      return 0;
    }
  }
}

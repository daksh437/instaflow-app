import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/daily_drop_model.dart';
import '../models/user_model.dart';
import 'firestore_helpers.dart';
import 'premium_service.dart';

/// Daily drop: 1 claim per day per user. Reset at midnight (00:00 local).
/// User doc: dailyDropCount (int), dailyDropLastDate (Timestamp).
/// Global drop at daily_drops/{date} (UTC).
class DailyDropService {
  static const String _dropsCollection = 'daily_drops';
  static const String _usersCollection = 'users';
  static const int limitFree = 1;
  static const int limitPremium = 3;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static DateTime _midnightToday(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _nextMidnight(DateTime from) =>
      _midnightToday(from).add(const Duration(days: 1));

  /// Time remaining until next local midnight (00:00).
  static Duration getTimeUntilMidnight() {
    final now = DateTime.now();
    final next = _nextMidnight(now);
    final d = next.difference(now);
    return d.isNegative ? Duration.zero : d;
  }

  /// Claim daily viral drop once per day. Returns true if claim allowed and applied; false if already claimed today.
  Future<bool> claimDailyDrop() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final uid = user.uid;
    final ref = _firestore.collection(_usersCollection).doc(uid);
    DocumentSnapshot<Map<String, dynamic>> doc;
    try {
      doc = await ref.get();
    } catch (e) {
      if (kDebugMode) debugPrint('[DailyDropService] claimDailyDrop get: $e');
      return false;
    }
    final now = DateTime.now();
    final todayMidnight = _midnightToday(now);
    final todayTs = Timestamp.fromDate(todayMidnight);

    Map<String, dynamic> data = doc.exists ? (doc.data() ?? {}) : {};
    final lastDate = _toDate(data['dailyDropLastDate']);
    final isToday = lastDate != null &&
        lastDate.year == now.year &&
        lastDate.month == now.month &&
        lastDate.day == now.day;

    if (!isToday) {
      try {
        await ref.set({
          'dailyDropCount': 0,
          'dailyDropLastDate': todayTs,
        }, SetOptions(merge: true));
      } catch (e) {
        if (kDebugMode) debugPrint('[DailyDropService] claimDailyDrop reset: $e');
        return false;
      }
      data = (await ref.get()).data() ?? data;
    }

    int count = (data['dailyDropCount'] is int)
        ? data['dailyDropCount'] as int
        : (data['dailyDropCount'] is num ? (data['dailyDropCount'] as num).toInt() : 0);
    count = count.clamp(0, 1);

    if (count >= 1) return false;

    try {
      await ref.set({
        'dailyDropCount': 1,
        'dailyDropLastDate': todayTs,
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('[DailyDropService] claimDailyDrop increment: $e');
      return false;
    }
    return true;
  }

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  /// Whether user has already claimed today (dailyDropCount == 1 for today).
  Future<bool> hasClaimedToday(String userId) async {
    final data = await FirestoreHelpers.safeGetDocData(_usersCollection, userId);
    if (data == null) return false;
    final lastDate = _toDate(data['dailyDropLastDate']);
    final now = DateTime.now();
    final isToday = lastDate != null &&
        lastDate.year == now.year &&
        lastDate.month == now.month &&
        lastDate.day == now.day;
    if (!isToday) return false;
    final count = data['dailyDropCount'];
    final n = count is int ? count : (count is num ? count.toInt() : 0);
    return n >= 1;
  }

  /// Stream of claim state: true if already claimed today.
  Stream<bool> hasClaimedTodayStream(String userId) {
    return _firestore.collection(_usersCollection).doc(userId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return false;
      final data = doc.data()!;
      final lastDate = _toDate(data['dailyDropLastDate']);
      final now = DateTime.now();
      final isToday = lastDate != null &&
          lastDate.year == now.year &&
          lastDate.month == now.month &&
          lastDate.day == now.day;
      if (!isToday) return false;
      final count = data['dailyDropCount'];
      final n = count is int ? count : (count is num ? count.toInt() : 0);
      return n >= 1;
    });
  }

  int _limitForUser(UserModel? user) {
    if (user == null) return limitFree;
    return PremiumService.hasActivePremium(user) ? limitPremium : limitFree;
  }

  Future<Map<String, dynamic>> _getUserDropFields(String userId) async {
    final data = await FirestoreHelpers.safeGetDocData(_usersCollection, userId);
    if (data == null) return {};
    final lastDate = _toDate(data['dailyDropLastDate']);
    final count = data['dailyDropCount'];
    final streak = data['streakDays'];
    return {
      'dailyDropLastDate': lastDate,
      'dailyDropCount': count is int ? count : (count is num ? count.toInt() : 0),
      'streakDays': streak is int ? streak : (streak is num ? streak.toInt() : 0),
    };
  }

  Future<bool> _updateUserDropFields(String userId, Map<String, dynamic> fields) async {
    return FirestoreHelpers.safeSetDoc(_usersCollection, userId, fields, merge: true);
  }

  Future<void> _normalizeUserDropState(String userId) async {
    final now = DateTime.now();
    final today = _midnightToday(now);
    final stored = await _getUserDropFields(userId);
    final lastDate = stored['dailyDropLastDate'] as DateTime?;
    int streak = stored['streakDays'] as int? ?? 0;

    if (lastDate == null) {
      await _updateUserDropFields(userId, {
        'dailyDropLastDate': Timestamp.fromDate(now),
        'dailyDropCount': 0,
        'streakDays': 1,
      });
      return;
    }

    final lastDay = _midnightToday(lastDate);
    final daysDiff = today.difference(lastDay).inDays;

    if (daysDiff == 0) return;
    if (daysDiff == 1) {
      streak = streak + 1;
    } else {
      streak = 1;
    }
    await _updateUserDropFields(userId, {
      'dailyDropLastDate': Timestamp.fromDate(now),
      'dailyDropCount': 0,
      'streakDays': streak,
    });
  }

  Future<int> getStreakDays(String userId) async {
    final stored = await _getUserDropFields(userId);
    final lastDate = stored['dailyDropLastDate'] as DateTime?;
    final streak = stored['streakDays'] as int? ?? 0;
    final now = DateTime.now();
    final today = _midnightToday(now);
    if (lastDate == null) return 0;
    final lastDay = _midnightToday(lastDate);
    if (lastDay.isBefore(today)) return 0;
    return streak;
  }

  Future<({int remaining, int limit, bool canRequest})> checkDailyLimit(
    String userId,
    UserModel? user,
  ) async {
    await _normalizeUserDropState(userId);
    final stored = await _getUserDropFields(userId);
    final lastDate = stored['dailyDropLastDate'] as DateTime?;
    final count = stored['dailyDropCount'] as int? ?? 0;
    final now = DateTime.now();
    final today = _midnightToday(now);
    final lastDay = lastDate != null ? _midnightToday(lastDate) : null;
    final countForToday = (lastDay != null && lastDay == today) ? count : 0;
    final limit = _limitForUser(user);
    final remaining = (limit - countForToday).clamp(0, limit);
    return (remaining: remaining, limit: limit, canRequest: remaining > 0);
  }

  static String _dateKeyUtc(DateTime d) {
    final utc = d.toUtc();
    return '${utc.year}-${utc.month.toString().padLeft(2, '0')}-${utc.day.toString().padLeft(2, '0')}';
  }

  Future<DailyDropModel?> getTodayDrop() async {
    final dateKey = _dateKeyUtc(DateTime.now());
    final data = await FirestoreHelpers.safeGetDocData(_dropsCollection, dateKey);
    if (data == null) return null;
    data['date'] = dateKey;
    return DailyDropModel.fromFirestore(data);
  }

  Future<bool> recordDropView(String userId, UserModel? user) async {
    final now = DateTime.now();
    final today = _midnightToday(now);
    final stored = await _getUserDropFields(userId);
    final lastDate = stored['dailyDropLastDate'] as DateTime?;
    int count = stored['dailyDropCount'] as int? ?? 0;
    int streak = stored['streakDays'] as int? ?? 0;
    final lastDay = lastDate != null ? _midnightToday(lastDate) : null;

    if (lastDay == null || lastDay.isBefore(today)) {
      count = 1;
      if (lastDay != null) {
        final daysDiff = today.difference(lastDay).inDays;
        streak = daysDiff == 1 ? streak + 1 : 1;
      } else {
        streak = 1;
      }
    } else {
      count += 1;
    }
    return _updateUserDropFields(userId, {
      'dailyDropLastDate': Timestamp.fromDate(now),
      'dailyDropCount': count,
      'streakDays': streak,
    });
  }

  DateTime get nextDropAt => _nextMidnight(DateTime.now());
}

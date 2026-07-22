import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/admin_user_row.dart';
import '../models/ai_usage_log_row.dart';
import '../models/refunded_user_row.dart';

/// Live admin dashboard stats from Firestore users (and ai_usage_logs). Error-safe.
/// Admin rule: users/{uid}.isAdmin == true.
class AdminDashboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static DateTime get _todayStart {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Live stream of dashboard counts. Recomputed on every users snapshot.
  Stream<AdminDashboardSnapshot> dashboardStream() {
    return _firestore.collection('users').snapshots().asyncMap((snapshot) async {
      try {
        return await _computeSnapshot(snapshot);
      } catch (e) {
        if (kDebugMode) debugPrint('[AdminDashboard] stream error: $e');
        return AdminDashboardSnapshot.zero();
      }
    }).handleError((e) {
      if (kDebugMode) debugPrint('[AdminDashboard] stream error: $e');
    });
  }

  Future<AdminDashboardSnapshot> _computeSnapshot(QuerySnapshot snapshot) async {
    final now = DateTime.now();
    final todayStart = _todayStart;
    int total = snapshot.docs.length;
    int premium = 0;
    int trialActive = 0;
    int dailyActive = 0;
    int todayAiUses = 0;

    for (final doc in snapshot.docs) {
      final row = AdminUserRow.fromDoc(doc);
      // AdminUserRow.isPremium already means "active premium" (valid future expiry).
      if (row.isPremium) {
        premium++;
      }
      if (row.trialEnd != null && row.trialEnd!.isAfter(now)) {
        trialActive++;
      }
      if (row.lastActiveAt != null && !row.lastActiveAt!.isBefore(todayStart)) {
        dailyActive++;
      }
      todayAiUses += row.aiUsesToday;
    }

    double conversionPct = total > 0 ? (premium / total) * 100 : 0.0;
    if (kDebugMode) {
      debugPrint(
        '[AdminStats] total=$total premium=$premium trial=$trialActive dailyActive=$dailyActive todayAiUses=$todayAiUses',
      );
    }

    return AdminDashboardSnapshot(
      totalUsers: total,
      premiumUsers: premium,
      trialActive: trialActive,
      dailyActiveUsers: dailyActive,
      todayAiUses: todayAiUses,
      conversionPct: conversionPct,
    );
  }

  /// One-time fetch (for fallback or refresh).
  Future<AdminDashboardSnapshot> getDashboardSnapshot() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      return _computeSnapshot(snapshot);
    } catch (e) {
      if (kDebugMode) debugPrint('[AdminDashboard] getDashboardSnapshot: $e');
      return AdminDashboardSnapshot.zero();
    }
  }

  /// Purchase breakdown by duration (1m, 3m, 6m, 12m).
  Future<Map<String, int>> getPurchaseBreakdown() async {
    const durations = ['1m', '3m', '6m', '12m'];
    final out = <String, int>{};
    for (final d in durations) {
      out[d] = 0;
    }
    try {
      var snapshot = await _firestore
          .collection('app_events')
          .where('type', isEqualTo: 'purchase_success')
          .get();
      if (snapshot.docs.isEmpty) {
        snapshot = await _firestore
            .collection('app_events')
            .where('name', isEqualTo: 'purchase_success')
            .get();
      }
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final duration = data['duration'] as String? ??
            (data['params'] is Map ? (data['params'] as Map)['duration'] as String? : null);
        if (duration != null && out.containsKey(duration)) {
          out[duration] = (out[duration] ?? 0) + 1;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[AdminDashboard] getPurchaseBreakdown: $e');
    }
    return out;
  }

  // ─── List queries (paginated, for detail screens) ────────────────────────

  static const int _pageSize = 30;

  /// All users, paginated by page. Search filters by email.
  Future<List<AdminUserRow>> getUsersPage({
    int limit = _pageSize,
    int page = 0,
    String search = '',
  }) async {
    try {
      final snapshot = await _firestore.collection('users').limit(500).get();
      var list = snapshot.docs.map((d) => AdminUserRow.fromDoc(d)).toList();
      list.sort((a, b) {
        final aTime = a.lastActiveAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.lastActiveAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      if (search.trim().isNotEmpty) {
        final lower = search.trim().toLowerCase();
        list = list
            .where((u) =>
                u.identity.toLowerCase().contains(lower) || u.uid.toLowerCase().contains(lower))
            .toList();
      }
      final start = (page * limit).clamp(0, list.length);
      return list.skip(start).take(limit).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[AdminDashboard] getUsersPage: $e');
      return [];
    }
  }

  /// Premium users: isPremium && premiumExpiry > now. Paginated by page.
  Future<List<AdminUserRow>> getPremiumUsersPage({
    int limit = _pageSize,
    int page = 0,
    String search = '',
  }) async {
    try {
      final snapshot = await _firestore.collection('users').get();
      // AdminUserRow.isPremium already means "active premium" (valid future expiry).
      var list = snapshot.docs
          .map((d) => AdminUserRow.fromDoc(d))
          .where((u) => u.isPremium)
          .toList();
      list.sort((a, b) => (a.email).compareTo(b.email));
      if (search.trim().isNotEmpty) {
        final lower = search.trim().toLowerCase();
        list = list.where((u) => u.email.toLowerCase().contains(lower)).toList();
      }
      final start = (page * limit).clamp(0, list.length);
      return list.skip(start).take(limit).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[AdminDashboard] getPremiumUsersPage: $e');
      return [];
    }
  }

  /// Trial active: trialEnd > now.
  Future<List<AdminUserRow>> getTrialActivePage({
    int limit = _pageSize,
    int page = 0,
    String search = '',
  }) async {
    try {
      final snapshot = await _firestore.collection('users').get();
      final now = DateTime.now();
      var list = snapshot.docs
          .map((d) => AdminUserRow.fromDoc(d))
          .where((u) => u.trialEnd != null && u.trialEnd!.isAfter(now))
          .toList();
      list.sort((a, b) {
        final ta = b.trialEnd ?? DateTime(0);
        final tb = a.trialEnd ?? DateTime(0);
        return ta.compareTo(tb);
      });
      if (search.trim().isNotEmpty) {
        final lower = search.trim().toLowerCase();
        list = list
            .where((u) =>
                u.identity.toLowerCase().contains(lower) || u.uid.toLowerCase().contains(lower))
            .toList();
      }
      final start = (page * limit).clamp(0, list.length);
      return list.skip(start).take(limit).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[AdminDashboard] getTrialActivePage: $e');
      return [];
    }
  }

  /// Daily active: lastActiveAt >= todayStart.
  Future<List<AdminUserRow>> getDailyActivePage({
    int limit = _pageSize,
    int page = 0,
    String search = '',
  }) async {
    try {
      final snapshot = await _firestore.collection('users').get();
      final todayStart = _todayStart;
      var list = snapshot.docs
          .map((d) => AdminUserRow.fromDoc(d))
          .where((u) => u.lastActiveAt != null && !u.lastActiveAt!.isBefore(todayStart))
          .toList();
      list.sort((a, b) {
        final ta = b.lastActiveAt ?? DateTime(0);
        final tb = a.lastActiveAt ?? DateTime(0);
        return ta.compareTo(tb);
      });
      if (search.trim().isNotEmpty) {
        final lower = search.trim().toLowerCase();
        list = list.where((u) => u.email.toLowerCase().contains(lower)).toList();
      }
      final start = (page * limit).clamp(0, list.length);
      return list.skip(start).take(limit).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[AdminDashboard] getDailyActivePage: $e');
      return [];
    }
  }

  /// AI usage: users with aiUsesToday > 0. Paginated.
  Future<List<AdminUserRow>> getTodayAiUsagePage({
    int limit = _pageSize,
    int page = 0,
    String search = '',
  }) async {
    try {
      final snapshot = await _firestore.collection('users').get();
      var list = snapshot.docs
          .map((d) => AdminUserRow.fromDoc(d))
          .where((u) => u.aiUsesToday > 0)
          .toList();
      list.sort((a, b) => b.aiUsesToday.compareTo(a.aiUsesToday));
      if (search.trim().isNotEmpty) {
        final lower = search.trim().toLowerCase();
        list = list.where((u) => u.email.toLowerCase().contains(lower)).toList();
      }
      final start = (page * limit).clamp(0, list.length);
      return list.skip(start).take(limit).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[AdminDashboard] getTodayAiUsagePage: $e');
      return [];
    }
  }

  /// Today's AI usage log entries (who used which tool, when) — from
  /// `ai_usage_logs`, written by the backend on every AI call. Newest first.
  Future<List<AiUsageLogRow>> getTodayAiUsageLogs({
    int limit = 200,
    String search = '',
  }) async {
    try {
      final snapshot = await _firestore
          .collection('ai_usage_logs')
          .where('usedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_todayStart))
          .orderBy('usedAt', descending: true)
          .limit(limit)
          .get();
      var list = snapshot.docs.map((d) => AiUsageLogRow.fromDoc(d)).toList();
      if (search.trim().isNotEmpty) {
        final lower = search.trim().toLowerCase();
        list = list
            .where((r) =>
                r.email.toLowerCase().contains(lower) ||
                r.toolName.toLowerCase().contains(lower))
            .toList();
      }
      return list;
    } catch (e) {
      if (kDebugMode) debugPrint('[AdminDashboard] getTodayAiUsageLogs: $e');
      return [];
    }
  }

  /// Count of today's AI uses (from ai_usage_logs).
  Future<int> getTodayAiUsageCount() async {
    try {
      final agg = await _firestore
          .collection('ai_usage_logs')
          .where('usedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_todayStart))
          .count()
          .get();
      return agg.count ?? 0;
    } catch (e) {
      if (kDebugMode) debugPrint('[AdminDashboard] getTodayAiUsageCount: $e');
      return 0;
    }
  }

  /// Refunded users: from refund_logs (written by Cloud Function when premium is revoked).
  Future<int> getRefundedCount() async {
    try {
      final snapshot = await _firestore.collection('refund_logs').get();
      return snapshot.docs.length;
    } catch (e) {
      if (kDebugMode) debugPrint('[AdminDashboard] getRefundedCount: $e');
      return 0;
    }
  }

  Future<List<RefundedUserRow>> getRefundedPage({
    int limit = _pageSize,
    int page = 0,
    String search = '',
  }) async {
    try {
      final snapshot = await _firestore
          .collection('refund_logs')
          .orderBy('revokedAt', descending: true)
          .limit(500)
          .get();
      var list = snapshot.docs.map((d) => RefundedUserRow.fromDoc(d)).toList();
      if (search.trim().isNotEmpty) {
        final lower = search.trim().toLowerCase();
        list = list.where((u) => u.email.toLowerCase().contains(lower)).toList();
      }
      final start = (page * limit).clamp(0, list.length);
      return list.skip(start).take(limit).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[AdminDashboard] getRefundedPage: $e');
      return [];
    }
  }
}

/// Snapshot of dashboard counts for StreamBuilder.
class AdminDashboardSnapshot {
  const AdminDashboardSnapshot({
    required this.totalUsers,
    required this.premiumUsers,
    required this.trialActive,
    required this.dailyActiveUsers,
    required this.todayAiUses,
    required this.conversionPct,
  });

  factory AdminDashboardSnapshot.zero() {
    return const AdminDashboardSnapshot(
      totalUsers: 0,
      premiumUsers: 0,
      trialActive: 0,
      dailyActiveUsers: 0,
      todayAiUses: 0,
      conversionPct: 0,
    );
  }

  final int totalUsers;
  final int premiumUsers;
  final int trialActive;
  final int dailyActiveUsers;
  final int todayAiUses;
  final double conversionPct;
}

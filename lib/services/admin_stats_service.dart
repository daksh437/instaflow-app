import 'package:cloud_firestore/cloud_firestore.dart';

/// Fetches admin metrics from Firestore. No mock data — live only.
class AdminStatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Total number of users (users collection).
  Future<int> getTotalUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  /// Users where isPremium == true.
  Future<int> getPremiumUsers() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('isPremium', isEqualTo: true)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  /// Users where isTrialActive == true.
  Future<int> getTrialUsers() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('isTrialActive', isEqualTo: true)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  /// Count of app_events where type/name == 'ai_used' and ts/timestamp is today (local date).
  Future<int> getTodayAiUsage() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      final startTs = Timestamp.fromDate(startOfDay);
      final endTs = Timestamp.fromDate(endOfDay);

      // Try 'type' first (admin format), then 'name' (AnalyticsEventService format)
      var snapshot = await _firestore
          .collection('app_events')
          .where('type', isEqualTo: 'ai_used')
          .where('ts', isGreaterThanOrEqualTo: startTs)
          .where('ts', isLessThan: endTs)
          .get();
      if (snapshot.docs.isEmpty) {
        snapshot = await _firestore
            .collection('app_events')
            .where('name', isEqualTo: 'ai_used')
            .where('timestamp', isGreaterThanOrEqualTo: startTs)
            .where('timestamp', isLessThan: endTs)
            .get();
      }
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  /// Count of app_events where type/name == 'trial_started'.
  Future<int> getTrialStarts() async {
    try {
      var snapshot = await _firestore
          .collection('app_events')
          .where('type', isEqualTo: 'trial_started')
          .get();
      if (snapshot.docs.isEmpty) {
        snapshot = await _firestore
            .collection('app_events')
            .where('name', isEqualTo: 'trial_started')
            .get();
      }
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  /// Trial → Premium conversion %: (premium users count) / (trial_started events).
  /// Returns 0 if no trial starts; otherwise percentage 0–100.
  Future<double> getPremiumConversions() async {
    try {
      final trialStarts = await getTrialStarts();
      if (trialStarts == 0) return 0.0;
      final premium = await getPremiumUsers();
      return (premium / trialStarts) * 100;
    } catch (e) {
      return 0.0;
    }
  }

  /// Purchase counts by duration (1m, 3m, 6m, 12m) from app_events type/name == 'purchase_success'.
  /// Returns map with keys '1m', '3m', '6m', '12m' (missing = 0).
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
      // keep zeros
    }
    return out;
  }
}


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../config/monetization_config.dart';
import '../models/monetization_state.dart';

class MonetizationService {
  MonetizationService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static MonetizationService? _instance;
  static MonetizationService get instance => _instance ??= MonetizationService();

  CollectionReference<Map<String, dynamic>> get _users => _firestore.collection('users');

  static const _dailyLimit = MonetizationConfig.dailyFreeUsesLimit;

  static bool _isSameCalendarDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static DateTime _midnightToday(DateTime d) {
    return DateTime(d.year, d.month, d.day);
  }

  static DateTime _nextMidnight(DateTime from) {
    return _midnightToday(from).add(const Duration(days: 1));
  }

  /// Time remaining until next local midnight (00:00).
  static Duration getTimeUntilMidnight() {
    final now = DateTime.now();
    final next = _nextMidnight(now);
    final d = next.difference(now);
    return d.isNegative ? Duration.zero : d;
  }

  /// Call from every AI tool button. Returns true if allowed (consumes 1 for free). Else navigates to premium and returns false.
  static Future<bool> checkAndConsumeAIUsage(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (context.mounted) Navigator.pushNamed(context, '/premium');
      return false;
    }
    final uid = user.uid;
    final svc = instance;

    await svc.ensureUserMonetizationFields(uid);
    final ref = svc._users.doc(uid);
    DocumentSnapshot<Map<String, dynamic>> doc = await ref.get();
    if (!doc.exists) {
      if (context.mounted) Navigator.pushNamed(context, '/premium');
      return false;
    }

    Map<String, dynamic> data = doc.data()!;
    final now = DateTime.now();

    final planType = (data['planType'] ?? 'free').toString();
    final premiumExpiry = _toDate(data['premiumExpiry']);
    final trialEndDate = _toDate(data['trialEndDate']);

    if (planType == 'premium' && premiumExpiry != null && now.isBefore(premiumExpiry)) {
      return true;
    }
    if (planType == 'trial' && trialEndDate != null && now.isBefore(trialEndDate)) {
      return true;
    }

    final resetDate = _toDate(data['dailyResetDate']);
    if (!_isSameCalendarDay(resetDate, now)) {
      final todayMidnight = _midnightToday(now);
      await ref.update({
        'dailyUsedCount': 0,
        'dailyResetDate': Timestamp.fromDate(todayMidnight),
      });
      doc = await ref.get();
      data = doc.data() ?? data;
    }

    int count = (data['dailyUsedCount'] is int) ? data['dailyUsedCount'] as int : 0;
    count = count.clamp(0, _dailyLimit);

    if (count < _dailyLimit) {
      await ref.update({'dailyUsedCount': count + 1});
      return true;
    }

    if (context.mounted) Navigator.pushNamed(context, '/premium');
    return false;
  }

  Stream<MonetizationState> get stateStream {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(_emptyState);
    return _users.doc(uid).snapshots().asyncMap((doc) async {
      if (!doc.exists) {
        await ensureUserMonetizationFields(uid);
        final again = await _users.doc(uid).get();
        return _computeState(again.data(), uid);
      }
      return _computeState(doc.data(), uid);
    });
  }

  static final MonetizationState _emptyState = MonetizationState(
    isTrialActive: false,
    trialDaysLeft: 0,
    isPremiumActive: false,
    freeUsesLeftToday: 0,
    dailyLimit: _dailyLimit,
    nextResetAt: null,
    canUseAi: false,
    statusMessage: 'Sign in to use AI',
    trialEndDate: null,
    premiumExpiry: null,
  );

  Future<void> ensureUserMonetizationFields(String uid) async {
    final ref = _users.doc(uid);
    final doc = await ref.get();
    final now = DateTime.now();
    final todayMidnight = _midnightToday(now);
    final nowTs = Timestamp.fromDate(now);
    final midnightTs = Timestamp.fromDate(todayMidnight);

    if (!doc.exists) {
      final trialEnd = now.add(const Duration(days: MonetizationConfig.trialDaysCount));
      await ref.set({
        'planType': 'trial',
        'trialEndDate': Timestamp.fromDate(trialEnd),
        'premiumExpiry': null,
        'dailyUsedCount': 0,
        'dailyResetDate': midnightTs,
        'createdAt': nowTs,
      }, SetOptions(merge: true));
      return;
    }

    final data = doc.data();
    if (data == null) return;

    final updates = <String, dynamic>{};
    if (data['dailyUsedCount'] == null) updates['dailyUsedCount'] = 0;
    if (data['dailyResetDate'] == null) updates['dailyResetDate'] = midnightTs;
    if (updates.isNotEmpty) await ref.update(updates);
  }

  Future<MonetizationState> getState(String uid) async {
    await ensureUserMonetizationFields(uid);
    final doc = await _users.doc(uid).get();
    return _computeState(doc.data(), uid);
  }

  MonetizationState _computeState(Map<String, dynamic>? data, String uid) {
    if (data == null) return _emptyState;

    final now = DateTime.now();
    final planType = (data['planType'] ?? 'free').toString();
    final trialEndDate = _toDate(data['trialEndDate']);
    final premiumExpiry = _toDate(data['premiumExpiry']);

    final isPremiumActive = planType == 'premium' && premiumExpiry != null && now.isBefore(premiumExpiry);
    final isTrialActive = planType == 'trial' && trialEndDate != null && now.isBefore(trialEndDate);
    final trialDaysLeft = isTrialActive ? trialEndDate!.difference(now).inDays.clamp(0, 999) : 0;

    int remaining = 0;
    DateTime? nextResetAt;
    bool canUseAi = false;
    String statusMessage;

    if (isPremiumActive) {
      canUseAi = true;
      statusMessage = 'Unlimited';
      nextResetAt = null;
    } else if (isTrialActive) {
      canUseAi = true;
      statusMessage = 'Trial Unlimited';
      nextResetAt = null;
    } else {
      final resetDate = _toDate(data['dailyResetDate']);
      int count = (data['dailyUsedCount'] is int) ? data['dailyUsedCount'] as int : 0;
      if (!_isSameCalendarDay(resetDate, now)) count = 0;
      count = count.clamp(0, _dailyLimit);
      remaining = (_dailyLimit - count).clamp(0, _dailyLimit);
      nextResetAt = _nextMidnight(now);
      canUseAi = remaining > 0;
      statusMessage = canUseAi ? '$remaining / $_dailyLimit uses left today' : 'Daily limit reached';
    }

    return MonetizationState(
      isTrialActive: isTrialActive,
      trialDaysLeft: trialDaysLeft,
      isPremiumActive: isPremiumActive,
      freeUsesLeftToday: remaining,
      dailyLimit: _dailyLimit,
      nextResetAt: nextResetAt,
      canUseAi: canUseAi,
      statusMessage: statusMessage,
      trialEndDate: trialEndDate,
      premiumExpiry: premiumExpiry,
    );
  }

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}

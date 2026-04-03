import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for Home top card: derived from Firebase Auth + Firestore users/{uid}.
class UserPlanData {
  const UserPlanData({
    required this.firstName,
    required this.planType,
    this.trialDaysLeft,
    this.remainingCredits,
    this.dailyLimit,
  });

  final String firstName;
  final String planType;
  final int? trialDaysLeft;
  final int? remainingCredits;
  final int? dailyLimit;
}

/// Listens to current user and users/{uid}, computes plan and display fields.
/// Plan type priority: premium (isPremium or premiumExpiry > now) > trial (trialEndDate > now) > free.
class UserPlanService {
  UserPlanService();

  Stream<UserPlanData?> streamUserPlan() {
    return FirebaseAuth.instance.authStateChanges().asyncExpand((User? user) {
      if (user == null) return Stream<UserPlanData?>.value(null);
      return FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .map((snapshot) {
        if (!snapshot.exists) return null;
        final data = snapshot.data() as Map<String, dynamic>?;
        if (data == null) return null;
        return _parseUserPlanData(user, data);
      });
    });
  }

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is Map && v['_seconds'] != null) return DateTime.fromMillisecondsSinceEpoch((v['_seconds'] as int) * 1000);
    return null;
  }

  /// Plan type priority: premium > trial > free. Do not rely on stored planType alone.
  static String _resolvePlanType(Map<String, dynamic> data) {
    final now = DateTime.now().toUtc();

    final isPremium = data['isPremium'] == true;
    final premiumExpiry = _toDate(data['premiumExpiry'] ?? data['premium_expiry']);
    if (isPremium || (premiumExpiry != null && now.isBefore(premiumExpiry))) {
      return 'premium';
    }

    final trialEndDate = _toDate(data['trialEndDate'] ?? data['trialEnd'] ?? data['trial_end']);
    if (trialEndDate != null && now.isBefore(trialEndDate)) {
      return 'trial';
    }

    return 'free';
  }

  static String _firstNameFromUser(User user) {
    final email = user.email?.trim();
    if (email != null && email.isNotEmpty) {
      final beforeAt = email.split('@').first;
      if (beforeAt.isNotEmpty) {
        final lower = beforeAt.toLowerCase();
        return lower.length > 1 ? '${lower[0].toUpperCase()}${lower.substring(1)}' : lower.toUpperCase();
      }
    }
    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) {
      return name.split(' ').first;
    }
    return 'Creator';
  }

  static UserPlanData _parseUserPlanData(User user, Map<String, dynamic> data) {
    final firstName = _firstNameFromUser(user);
    final planType = _resolvePlanType(data);

    int? trialDaysLeft;
    int? remainingCredits;
    int? dailyLimit;

    final trialEndDate = _toDate(data['trialEndDate'] ?? data['trialEnd'] ?? data['trial_end']);
    if (planType == 'trial' && trialEndDate != null) {
      trialDaysLeft = trialEndDate.difference(DateTime.now()).inDays.clamp(0, 999);
    }

    if (planType == 'free') {
      final limit = data['dailyLimit'] is int ? data['dailyLimit'] as int : (data['daily_limit'] is int ? data['daily_limit'] as int : 2);
      final used = data['dailyAiUsed'] is int ? data['dailyAiUsed'] as int : (data['daily_ai_used'] is int ? data['daily_ai_used'] as int : 0);
      dailyLimit = limit;
      remainingCredits = (limit - used).clamp(0, limit);
    }

    return UserPlanData(
      firstName: firstName,
      planType: planType,
      trialDaysLeft: trialDaysLeft,
      remainingCredits: remainingCredits,
      dailyLimit: dailyLimit,
    );
  }
}

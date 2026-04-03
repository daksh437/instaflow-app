import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoURL;
  final String? instagramUsername;
  final String? instagramAccessToken;
  final SubscriptionPlan subscriptionPlan;
  final DateTime createdAt;
  final DateTime? trialEndsAt;
  final String? stripeCustomerId;
  final String? stripeSubscriptionId;
  final DateTime? subscriptionRenewsAt;
  final Map<String, dynamic>? preferences;

  // Trial: 7-day free trial for new users
  final bool isTrialActive;
  final DateTime? trialStart;      // trialStartDate
  final DateTime? trialEnd;        // trialEndDate
  final bool isPremium;
  final String premiumPlan;        // 'none', 'basic', 'pro'
  final String premiumDuration;    // 'none', '1m', '3m', '6m', '12m'
  final DateTime? premiumStartDate;
  final DateTime? premiumExpiry;

  // Free tier (after trial): 2 AI uses per day, reset daily
  final int dailyFreeUsedCount;
  final DateTime? lastUsageDate;

  /// Admin role: can access dashboard and feedback panel. From Firestore users/{uid}.isAdmin.
  final bool isAdmin;

  const UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoURL,
    this.instagramUsername,
    this.instagramAccessToken,
    this.subscriptionPlan = SubscriptionPlan.trial,
    required this.createdAt,
    this.trialEndsAt,
    this.stripeCustomerId,
    this.stripeSubscriptionId,
    this.subscriptionRenewsAt,
    this.preferences,
    this.isTrialActive = false,
    this.trialStart,
    this.trialEnd,
    this.isPremium = false,
    this.premiumPlan = 'none',
    this.premiumDuration = 'none',
    this.premiumStartDate,
    this.premiumExpiry,
    this.dailyFreeUsedCount = 0,
    this.lastUsageDate,
    this.isAdmin = false,
  });

  /// Trial start (alias for trialStartDate)
  DateTime? get trialStartDate => trialStart;
  /// Trial end (alias for trialEndDate)
  DateTime? get trialEndDate => trialEnd;

  bool get hasActiveTrial => isTrialActive && 
      trialEnd != null && 
      DateTime.now().isBefore(trialEnd!);

  factory UserModel.fromFirestore(Map<String, dynamic> data, String uid) {
    final planString = (data['subscriptionPlan'] ?? 'trial').toString();
    final rawCount = data['dailyAiUsed'] ?? data['dailyFreeUsedCount'];
    final dailyFreeUsedCount = rawCount is int
        ? rawCount
        : (rawCount is num ? rawCount.toInt() : 0);
    final lastUsage = (data['lastAiReset'] as Timestamp?)?.toDate() ?? (data['lastUsageDate'] as Timestamp?)?.toDate();
    final trialEndDate = (data['trialExpiry'] as Timestamp?)?.toDate() ?? (data['trialEnd'] as Timestamp?)?.toDate();
    return UserModel(
      uid: uid,
      email: (data['email'] ?? '').toString(),
      displayName: data['displayName']?.toString(),
      photoURL: data['photoURL']?.toString(),
      instagramUsername: data['instagramUsername']?.toString(),
      instagramAccessToken: data['instagramAccessToken']?.toString(),
      subscriptionPlan: SubscriptionPlanParser.fromString(planString),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      trialEndsAt: (data['trialEndsAt'] as Timestamp?)?.toDate(),
      stripeCustomerId: data['stripeCustomerId']?.toString(),
      stripeSubscriptionId: data['stripeSubscriptionId']?.toString(),
      subscriptionRenewsAt:
          (data['subscriptionRenewsAt'] as Timestamp?)?.toDate(),
      preferences: data['preferences'] is Map<String, dynamic> ? data['preferences'] as Map<String, dynamic>? : null,
      isTrialActive: data['isTrialActive'] == true,
      trialStart: (data['trialStart'] as Timestamp?)?.toDate() ?? (data['trialStartDate'] as Timestamp?)?.toDate(),
      trialEnd: trialEndDate,
      isPremium: data['isPremium'] == true,
      premiumPlan: (data['premiumPlan'] ?? 'none').toString(),
      premiumDuration: (data['premiumDuration'] ?? 'none').toString(),
      premiumStartDate: (data['premiumStartDate'] as Timestamp?)?.toDate(),
      premiumExpiry: (data['premiumExpiry'] as Timestamp?)?.toDate(),
      dailyFreeUsedCount: dailyFreeUsedCount.clamp(0, 999),
      lastUsageDate: lastUsage,
      isAdmin: data['isAdmin'] == true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'instagramUsername': instagramUsername,
      'instagramAccessToken': instagramAccessToken,
      'subscriptionPlan': subscriptionPlan.apiName,
      'createdAt': Timestamp.fromDate(createdAt),
      if (trialEndsAt != null) 'trialEndsAt': Timestamp.fromDate(trialEndsAt!),
      if (stripeCustomerId != null) 'stripeCustomerId': stripeCustomerId,
      if (stripeSubscriptionId != null)
        'stripeSubscriptionId': stripeSubscriptionId,
      if (subscriptionRenewsAt != null)
        'subscriptionRenewsAt': Timestamp.fromDate(subscriptionRenewsAt!),
      'preferences': preferences,
      // New premium fields
      'isTrialActive': isTrialActive,
      if (trialStart != null) 'trialStart': Timestamp.fromDate(trialStart!),
      if (trialEnd != null) 'trialEnd': Timestamp.fromDate(trialEnd!),
      'isPremium': isPremium,
      'premiumPlan': premiumPlan,
      'premiumDuration': premiumDuration,
      if (premiumStartDate != null) 'premiumStartDate': Timestamp.fromDate(premiumStartDate!),
      if (premiumExpiry != null) 'premiumExpiry': Timestamp.fromDate(premiumExpiry!),
      'dailyFreeUsedCount': dailyFreeUsedCount,
      if (lastUsageDate != null) 'lastUsageDate': Timestamp.fromDate(lastUsageDate!),
      'isAdmin': isAdmin,
    };
  }
}

// ─── Firestore user document model (freemium) ───────────────────────────────
// Collection: users
// Fields:
//   email, displayName, photoURL, createdAt, preferences
//   subscriptionPlan: 'trial' | 'free' | 'pro' | 'ultra'
//   isTrialActive: bool
//   trialStart / trialStartDate: Timestamp   (trial start)
//   trialEnd / trialEndDate: Timestamp       (trial end = now + 7 days for new users)
//   isPremium: bool
//   premiumPlan: 'none' | 'basic' | 'pro'
//   premiumDuration: 'none' | '1m' | '3m' | '6m' | '12m'
//   premiumExpiry: Timestamp?
//   dailyFreeUsedCount: number (reset daily for free users)
//   lastUsageDate: Timestamp? (date of last AI use for daily reset)
//   trialExpired: bool? (optional)

enum SubscriptionPlan {
  trial,
  free,
  pro,
  ultra,
}

class SubscriptionPlanParser {
  static SubscriptionPlan fromString(String value) {
    final match = SubscriptionPlan.values.firstWhere(
      (plan) => plan.apiName == value.toLowerCase(),
      orElse: () => SubscriptionPlan.free,
    );
    return match;
  }
}

extension SubscriptionPlanExtension on SubscriptionPlan {
  String get apiName {
    switch (this) {
      case SubscriptionPlan.trial:
        return 'trial';
      case SubscriptionPlan.free:
        return 'free';
      case SubscriptionPlan.pro:
        return 'pro';
      case SubscriptionPlan.ultra:
        return 'ultra';
    }
  }

  String get displayName {
    switch (this) {
      case SubscriptionPlan.trial:
        return 'Free Trial';
      case SubscriptionPlan.free:
        return 'Free';
      case SubscriptionPlan.pro:
        return 'Pro';
      case SubscriptionPlan.ultra:
        return 'Ultra Pro';
    }
  }

  bool get isPaid => this == SubscriptionPlan.pro || this == SubscriptionPlan.ultra;

  bool get hasUnlimitedCaptions =>
      this == SubscriptionPlan.pro || this == SubscriptionPlan.ultra || this == SubscriptionPlan.trial;

  bool get hasAnalytics =>
      this == SubscriptionPlan.pro || this == SubscriptionPlan.ultra || this == SubscriptionPlan.trial;

  bool get hasScheduling =>
      this == SubscriptionPlan.pro || this == SubscriptionPlan.ultra || this == SubscriptionPlan.trial;

  bool get hasAdvancedAiTools =>
      this == SubscriptionPlan.pro || this == SubscriptionPlan.ultra || this == SubscriptionPlan.trial;

  bool get hasCollaboration => this == SubscriptionPlan.ultra;

  int get maxCaptionsPerDay {
    switch (this) {
      case SubscriptionPlan.trial:
        return -1; // unlimited
      case SubscriptionPlan.free:
        return 5;
      case SubscriptionPlan.pro:
        return -1;
      case SubscriptionPlan.ultra:
        return -1;
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

/// One user row for admin list screens. Fields from Firestore users collection.
class AdminUserRow {
  const AdminUserRow({
    required this.uid,
    required this.email,
    this.displayName,
    this.phone,
    this.isPremium = false,
    this.premiumDuration,
    this.premiumExpiry,
    this.trialStart,
    this.trialEnd,
    this.lastActiveAt,
    this.aiUsesToday = 0,
    this.aiUsesTotal = 0,
    this.purchaseDate,
    this.createdAt,
    this.productId,
    this.purchaseToken,
  });

  final String uid;
  final String email;
  final String? displayName;
  final String? phone;
  final bool isPremium;
  final String? premiumDuration;
  final DateTime? premiumExpiry;
  final DateTime? trialStart;
  final DateTime? trialEnd;
  final DateTime? lastActiveAt;
  final int aiUsesToday;
  final int aiUsesTotal;
  final DateTime? purchaseDate;
  final DateTime? createdAt;

  /// Google Play product id of the subscription (e.g. `premium_monthly`).
  final String? productId;

  /// Google Play purchase token — the unique identifier for this user's
  /// subscription (used to verify/refund a purchase in Play Console).
  final String? purchaseToken;

  String get identity {
    if (email.trim().isNotEmpty) return email.trim();
    if ((displayName ?? '').trim().isNotEmpty) return displayName!.trim();
    if ((phone ?? '').trim().isNotEmpty) return phone!.trim();
    return 'No email';
  }

  String get plan => isPremium ? 'Premium' : (_isTrialActive ? 'Trial' : 'Free');
  String get planDetail => (premiumDuration ?? '').trim().isEmpty ? 'none' : premiumDuration!.trim();

  bool get _isTrialActive {
    if (trialEnd == null) return false;
    return trialEnd!.isAfter(DateTime.now());
  }

  DateTime? get activeExpiry {
    if (isPremium) return premiumExpiry;
    if (_isTrialActive) return trialEnd;
    return null;
  }

  String get status {
    if (!isPremium) return '—';
    if (premiumExpiry == null) return '—';
    return (premiumExpiry?.isAfter(DateTime.now()) ?? false) ? 'active' : 'expired';
  }

  static AdminUserRow fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final premiumExpiry = _firstDate([
      d['premiumExpiry'],
      d['premium_expiry'],
      d['premiumExpiryDate'],
    ]);
    final trialStart = _firstDate([
      d['trialStart'],
      d['trialStartDate'],
      d['trialStartedAt'],
    ]);
    final trialEnd = _firstDate([
      d['trialEndDate'],
      d['trialEnd'],
      d['trialExpiry'],
    ]);
    final now = DateTime.now();
    // Premium = a valid future expiry, matching the backend's authoritative
    // definition (planResolver.js: premiumExpiry > now). The `isPremium` boolean
    // flag is NOT required — some grant paths set premiumExpiry without it, and
    // requiring the flag would hide real premium users from the admin panel.
    final isPremiumNow = premiumExpiry != null && premiumExpiry.isAfter(now);
    final isTrialNow = d['isTrialActive'] == true && trialEnd != null && trialEnd.isAfter(now);

    final email = _firstNonEmpty([
      d['email'],
      d['userEmail'],
      d['loginEmail'],
    ]);
    final displayName = _firstNonEmpty([
      d['displayName'],
      d['name'],
    ]);
    final phone = _firstNonEmpty([
      d['phoneNumber'],
      d['phone'],
    ]);

    final lastActive = _firstDate([
      d['lastActiveAt'],
      d['lastActive'],
      d['lastSeen'],
      d['lastUpdated'],
    ]);

    final createdAt = _firstDate([
      d['createdAt'],
      d['signupAt'],
      d['registeredAt'],
    ]);

    final planDetail = _firstNonEmpty([
      d['premiumPlan'],
      d['subscriptionPlan'],
      d['premiumDuration'],
      d['productId'],
    ]);

    final todayUsage = _firstInt([
      d['dailyAiUsed'],
      d['dailyUsedCount'],
      d['todayUsage'],
      d['aiUsesToday'],
    ]);
    final totalUsage = _firstInt([
      d['totalAiUsed'],
      d['totalUsageCount'],
      d['usageCount'],
      d['aiUsesTotal'],
    ]);

    return AdminUserRow(
      uid: doc.id,
      email: email ?? '',
      displayName: displayName,
      phone: phone,
      isPremium: isPremiumNow,
      premiumDuration: planDetail ?? (isTrialNow ? 'trial' : null),
      premiumExpiry: premiumExpiry,
      trialStart: trialStart,
      trialEnd: trialEnd,
      lastActiveAt: lastActive,
      aiUsesToday: todayUsage,
      aiUsesTotal: totalUsage,
      purchaseDate: _firstDate([d['premiumStartDate'], d['premiumStart'], d['purchaseDate']]),
      createdAt: createdAt,
      productId: _firstNonEmpty([
        d['premiumProductId'],
        d['iapProductId'],
        d['productId'],
      ]),
      purchaseToken: _firstNonEmpty([
        d['subscriptionPurchaseToken'],
        d['lastProcessedPurchaseToken'],
        d['purchaseToken'],
      ]),
    );
  }

  static String _asString(dynamic v) {
    if (v == null) return '';
    return v.toString().trim();
  }

  static String? _firstNonEmpty(List<dynamic> values) {
    for (final v in values) {
      final s = _asString(v);
      if (s.isNotEmpty && s.toLowerCase() != 'null') return s;
    }
    return null;
  }

  static DateTime? _firstDate(List<dynamic> values) {
    for (final v in values) {
      final dt = _toDate(v);
      if (dt != null) return dt;
    }
    return null;
  }

  static int _firstInt(List<dynamic> values) {
    for (final v in values) {
      final n = safeInt(v);
      if (n > 0) return n;
    }
    return 0;
  }

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) {
      final ms = v > 9999999999 ? v : v * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    if (v is num) {
      final i = v.toInt();
      final ms = i > 9999999999 ? i : i * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    if (v is String) {
      final parsedNum = int.tryParse(v);
      if (parsedNum != null) {
        final ms = parsedNum > 9999999999 ? parsedNum : parsedNum * 1000;
        return DateTime.fromMillisecondsSinceEpoch(ms);
      }
      return DateTime.tryParse(v);
    }
    return null;
  }

  static int safeInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

}

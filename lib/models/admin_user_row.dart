import 'package:cloud_firestore/cloud_firestore.dart';

/// One user row for admin list screens. Fields from Firestore users collection.
class AdminUserRow {
  const AdminUserRow({
    required this.uid,
    required this.email,
    this.isPremium = false,
    this.premiumDuration,
    this.premiumExpiry,
    this.trialStart,
    this.trialEnd,
    this.lastActiveAt,
    this.aiUsesToday = 0,
    this.aiUsesTotal = 0,
    this.purchaseDate,
  });

  final String uid;
  final String email;
  final bool isPremium;
  final String? premiumDuration;
  final DateTime? premiumExpiry;
  final DateTime? trialStart;
  final DateTime? trialEnd;
  final DateTime? lastActiveAt;
  final int aiUsesToday;
  final int aiUsesTotal;
  final DateTime? purchaseDate;

  String get plan => isPremium ? 'Premium' : (trialEnd != null ? 'Trial' : 'Free');
  String get status {
    if (!isPremium) return '—';
    if (premiumExpiry == null) return '—';
    return (premiumExpiry?.isAfter(DateTime.now()) ?? false) ? 'active' : 'expired';
  }

  static AdminUserRow fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return AdminUserRow(
      uid: doc.id,
      email: (d['email'] ?? '').toString(),
      isPremium: d['isPremium'] == true,
      premiumDuration: d['premiumDuration']?.toString(),
      premiumExpiry: (d['premiumExpiry'] as Timestamp?)?.toDate(),
      trialStart: (d['trialStart'] as Timestamp?)?.toDate(),
      trialEnd: (d['trialEnd'] as Timestamp?)?.toDate(),
      lastActiveAt: (d['lastActiveAt'] as Timestamp?)?.toDate(),
      aiUsesToday: _int(d['aiUsesToday']),
      aiUsesTotal: _int(d['aiUsesTotal']),
      purchaseDate: (d['premiumStartDate'] as Timestamp?)?.toDate(),
    );
  }

  static int safeInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  static int _int(dynamic v) => safeInt(v);
}

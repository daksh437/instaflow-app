import 'package:cloud_firestore/cloud_firestore.dart';

/// One row for admin Refunded Users list. From refund_logs collection.
class RefundedUserRow {
  const RefundedUserRow({
    required this.uid,
    required this.email,
    this.duration,
    this.purchaseDate,
    this.revokedAt,
    this.reason,
  });

  final String uid;
  final String email;
  final String? duration;
  final DateTime? purchaseDate;
  final DateTime? revokedAt;
  final String? reason;

  /// Email to show in the admin UI — falls back to uid (never blank).
  String get emailDisplay {
    if (email.trim().isNotEmpty) return email.trim();
    if (uid.trim().isNotEmpty) return uid.trim();
    return 'No email';
  }

  static RefundedUserRow fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    DateTime? purchaseDate;
    final purchaseDateVal = d['purchaseDate'];
    if (purchaseDateVal is String) {
      purchaseDate = DateTime.tryParse(purchaseDateVal);
    } else if (purchaseDateVal is Timestamp) {
      purchaseDate = purchaseDateVal.toDate();
    }
    return RefundedUserRow(
      uid: (d['uid'] ?? '').toString(),
      email: (d['email'] ?? '').toString(),
      duration: d['duration']?.toString(),
      purchaseDate: purchaseDate,
      revokedAt: (d['revokedAt'] as Timestamp?)?.toDate(),
      reason: d['reason']?.toString(),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

/// One row from the `ai_usage_logs` collection — who used which AI tool, when.
class AiUsageLogRow {
  const AiUsageLogRow({
    required this.email,
    required this.uid,
    required this.toolName,
    required this.plan,
    required this.usedAt,
  });

  final String email;
  final String uid;
  final String toolName;
  final String plan;
  final DateTime? usedAt;

  String get identity => email.isNotEmpty ? email : uid;

  factory AiUsageLogRow.fromDoc(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    DateTime? usedAt;
    final ts = d['usedAt'];
    if (ts is Timestamp) usedAt = ts.toDate();

    return AiUsageLogRow(
      email: (d['email'] as String?)?.trim() ?? '',
      uid: (d['uid'] as String?)?.trim() ?? '',
      toolName: (d['toolName'] as String?)?.trim().isNotEmpty == true
          ? (d['toolName'] as String).trim()
          : 'unknown',
      plan: (d['plan'] as String?)?.trim() ?? '',
      usedAt: usedAt,
    );
  }
}

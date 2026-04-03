import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// One-time migration: normalizes all user documents to a single structure.
/// Run from admin flow or main() during migration window.
/// Does NOT delete old fields; only adds/updates normalized fields.
class UserMigrationService {
  UserMigrationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const _batchSize = 500;

  /// Migrates all users in the [users] collection to the final normalized structure.
  /// Uses batched writes (max 500 per batch). Logs each migrated user to console.
  Future<void> migrateAllUsers() async {
    final usersRef = _firestore.collection('users');
    DocumentSnapshot? lastDoc;
    int totalMigrated = 0;
    int totalProcessed = 0;

    if (kDebugMode) {
      debugPrint('[UserMigration] Starting migration of users collection...');
    }

    while (true) {
      final QuerySnapshot<Map<String, dynamic>> snapshot = lastDoc == null
          ? await usersRef.orderBy(FieldPath.documentId).limit(_batchSize).get()
          : await usersRef
              .orderBy(FieldPath.documentId)
              .startAfterDocument(lastDoc)
              .limit(_batchSize)
              .get();

      if (snapshot.docs.isEmpty) break;

      final batch = _firestore.batch();

      for (final doc in snapshot.docs) {
        totalProcessed++;
        final data = doc.data();
        final updates = _computeUpdates(data);

        if (updates.isNotEmpty) {
          batch.update(doc.reference, updates);
          totalMigrated++;
          if (kDebugMode) {
            debugPrint('[UserMigration] Migrated user: ${doc.id} | updates: ${updates.keys.join(", ")}');
          }
        }
      }

      await batch.commit();
      lastDoc = snapshot.docs.last;

      if (snapshot.docs.length < _batchSize) break;
    }

    if (kDebugMode) {
      debugPrint('[UserMigration] Done. Processed: $totalProcessed, migrated: $totalMigrated');
    }
  }

  /// Builds update map for a single user. Only includes keys that need to be set.
  /// Does not remove any existing fields.
  Map<String, dynamic> _computeUpdates(Map<String, dynamic> data) {
    final now = DateTime.now();
    final nowTs = Timestamp.fromDate(now);
    final updates = <String, dynamic>{};

    // createdAt
    if (data['createdAt'] == null) {
      updates['createdAt'] = nowTs;
    }

    // trialStartDate from trialStart
    if (data['trialStartDate'] == null && data['trialStart'] != null) {
      updates['trialStartDate'] = _toTimestamp(data['trialStart']);
    }

    // trialEndDate from trialEnd
    if (data['trialEndDate'] == null && data['trialEnd'] != null) {
      updates['trialEndDate'] = _toTimestamp(data['trialEnd']);
    }

    // dailyUsedCount from legacy fields
    if (data['dailyUsedCount'] == null) {
      final count = _firstInt(data, ['dailyFreeUsedCount', 'dailyDropCount', 'dailyAiUsed']);
      updates['dailyUsedCount'] = count ?? 0;
    }

    // dailyResetDate from dailyDropLastDate or now
    if (data['dailyResetDate'] == null) {
      if (data['dailyDropLastDate'] != null) {
        updates['dailyResetDate'] = _toTimestamp(data['dailyDropLastDate']);
      } else {
        updates['dailyResetDate'] = nowTs;
      }
    }

    // planType: derive if missing
    if (data['planType'] == null || (data['planType'] is! String)) {
      final planType = _derivePlanType(data, now);
      updates['planType'] = planType;
    }

    return updates;
  }

  String _derivePlanType(Map<String, dynamic> data, DateTime now) {
    final premiumExpiry = _toDate(data['premiumExpiry']);
    if (premiumExpiry != null) {
      return 'premium';
    }
    final trialEndDate = _toDate(data['trialEndDate']) ?? _toDate(data['trialEnd']);
    if (trialEndDate != null && now.isBefore(trialEndDate)) {
      return 'trial';
    }
    return 'free';
  }

  static Timestamp? _toTimestamp(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v;
    if (v is DateTime) return Timestamp.fromDate(v);
    return null;
  }

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  static int? _firstInt(Map<String, dynamic> data, List<String> keys) {
    for (final k in keys) {
      final v = data[k];
      if (v == null) continue;
      if (v is int) return v;
      if (v is num) return v.toInt();
    }
    return null;
  }
}

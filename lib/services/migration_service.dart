import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

const int _batchSize = 500;

Future<void> migrateAllUsers() async {
  final firestore = FirebaseFirestore.instance;
  final usersRef = firestore.collection('users');
  DocumentSnapshot? lastDoc;
  int totalMigrated = 0;
  int totalProcessed = 0;

  if (kDebugMode) debugPrint('[Migration] Starting users migration...');

  while (true) {
    final QuerySnapshot<Map<String, dynamic>> snapshot = lastDoc == null
        ? await usersRef.orderBy(FieldPath.documentId).limit(_batchSize).get()
        : await usersRef
            .orderBy(FieldPath.documentId)
            .startAfterDocument(lastDoc)
            .limit(_batchSize)
            .get();

    if (snapshot.docs.isEmpty) break;

    final batch = firestore.batch();

    for (final doc in snapshot.docs) {
      totalProcessed++;
      final data = doc.data();
      final updates = _computeUpdates(data);

      if (updates.isNotEmpty) {
        batch.update(doc.reference, updates);
        totalMigrated++;
        if (kDebugMode) {
          debugPrint('[Migration] Migrated user: ${doc.id} | ${updates.keys.join(", ")}');
        }
      }
    }

    await batch.commit();
    lastDoc = snapshot.docs.last;

    if (snapshot.docs.length < _batchSize) break;
  }

  if (kDebugMode) {
    debugPrint('[Migration] Processed: $totalProcessed, migrated: $totalMigrated');
    debugPrint('Migration Completed');
  }
}

Map<String, dynamic> _computeUpdates(Map<String, dynamic> data) {
  final now = DateTime.now();
  final nowTs = Timestamp.fromDate(now);
  final updates = <String, dynamic>{};

  if (data['createdAt'] == null) {
    updates['createdAt'] = nowTs;
  }

  if (data['trialStartDate'] == null && data['trialStart'] != null) {
    final t = _toTimestamp(data['trialStart']);
    if (t != null) updates['trialStartDate'] = t;
  }

  if (data['trialEndDate'] == null && data['trialEnd'] != null) {
    final t = _toTimestamp(data['trialEnd']);
    if (t != null) updates['trialEndDate'] = t;
  }

  if (data['dailyUsedCount'] == null) {
    final count = _firstInt(data, ['dailyFreeUsedCount', 'dailyDropCount', 'dailyAiUsed']);
    updates['dailyUsedCount'] = count ?? 0;
  }

  if (data['dailyResetDate'] == null) {
    if (data['dailyDropLastDate'] != null) {
      final t = _toTimestamp(data['dailyDropLastDate']);
      if (t != null) {
        updates['dailyResetDate'] = t;
      } else {
        updates['dailyResetDate'] = nowTs;
      }
    } else {
      updates['dailyResetDate'] = nowTs;
    }
  }

  if (data['planType'] == null || data['planType'] is! String) {
    updates['planType'] = _derivePlanType(data, now);
  }

  return updates;
}

String _derivePlanType(Map<String, dynamic> data, DateTime now) {
  final premiumExpiry = _toDate(data['premiumExpiry']);
  if (premiumExpiry != null && now.isBefore(premiumExpiry)) {
    return 'premium';
  }
  final trialEndDate = _toDate(data['trialEndDate']) ?? _toDate(data['trialEnd']);
  if (trialEndDate != null && now.isBefore(trialEndDate)) {
    return 'trial';
  }
  return 'free';
}

Timestamp? _toTimestamp(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v;
  if (v is DateTime) return Timestamp.fromDate(v);
  return null;
}

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}

int? _firstInt(Map<String, dynamic> data, List<String> keys) {
  for (final k in keys) {
    final v = data[k];
    if (v == null) continue;
    if (v is int) return v;
    if (v is num) return v.toInt();
  }
  return null;
}

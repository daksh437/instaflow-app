import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Writes daily analytics to Firestore: analytics/daily_YYYY_MM_DD.
/// Only when user is authenticated. Error-safe (try/catch, debugPrint).
class AnalyticsFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static String _dailyDocId() {
    final now = DateTime.now();
    return 'daily_${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _increment(String field) async {
    if (_auth.currentUser == null) return;
    try {
      final ref = _firestore.collection('analytics').doc(_dailyDocId());
      await ref.set({
        field: FieldValue.increment(1),
      }, SetOptions(merge: true));
      if (kDebugMode) debugPrint('[AnalyticsFirestore] $field +1');
    } catch (e) {
      if (kDebugMode) debugPrint('[AnalyticsFirestore] $field: $e');
    }
  }

  void recordTrialStarted() {
    _increment('trialStarted');
  }

  void recordPremiumPurchased() {
    _increment('premiumPurchased');
  }

  void recordAiUsed() {
    _increment('aiUsed');
  }
}

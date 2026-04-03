import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/whatsapp_bot_setup.dart';

/// Persists WhatsApp Bot shop + AI settings under the signed-in user in Firestore.
/// No-ops when not signed in so local-only flows keep working.
class WhatsAppBotFirestoreService {
  WhatsAppBotFirestoreService._();
  static final WhatsAppBotFirestoreService instance =
      WhatsAppBotFirestoreService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>>? _configRef() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('whatsapp_bot').doc('config');
  }

  Future<void> saveShopInfo(WhatsAppBotSetup setup) async {
    final ref = _configRef();
    if (ref == null) return;
    await ref.set(
      {
        'shop': {
          'shopName': setup.shopName,
          'category': setup.category,
          'city': setup.city,
          'whatsappDisplayName': setup.whatsappDisplayName,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      },
      SetOptions(merge: true),
    );
  }

  Future<void> saveAiSettings(WhatsAppBotSetup setup) async {
    final ref = _configRef();
    if (ref == null) return;
    await ref.set(
      {
        'ai': {
          'productsOrServices': setup.productsOrServices,
          'aiWorkingHours': setup.aiWorkingHours,
          'languages': setup.languages,
          'sharePrice': setup.sharePrice,
          'greetingMessage': setup.greetingMessage,
          'aiEnabled': setup.aiEnabled,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        'status': {
          'connected': setup.connected,
          'onboardingCompleted': setup.onboardingCompleted,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      },
      SetOptions(merge: true),
    );
  }

  /// Optional: full snapshot after local save.
  Future<void> syncFromLocalSetup(WhatsAppBotSetup setup) async {
    try {
      await saveShopInfo(setup);
      await saveAiSettings(setup);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[WhatsAppBotFirestore] syncFromLocalSetup: $e');
        debugPrint('$st');
      }
    }
  }
}

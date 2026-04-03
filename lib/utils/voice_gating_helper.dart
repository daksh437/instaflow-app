import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/premium_service.dart';
import '../widgets/upgrade_dialog.dart';

/// Voice play gating: Premium = unlimited, Free = 3/day. Uses Firestore voicePlaysToday, voiceLastUsedDate.
class VoiceGatingHelper {
  static const int freeDailyLimit = 3;

  /// Returns true if user can use voice. If false, shows paywall and returns false.
  static Future<bool> checkCanSpeak(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showPaywall(context);
      return false;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 5));
      if (!doc.exists || doc.data() == null) {
        _showPaywall(context);
        return false;
      }
      final data = doc.data()!;
      final userModel = UserModel.fromFirestore(data, user.uid);
      if (PremiumService.hasActivePremium(userModel)) return true;

      final didReset = await _resetDailyIfNeeded(user.uid, data);
      final plays = didReset
          ? 0
          : (data['voicePlaysToday'] is int
              ? data['voicePlaysToday'] as int
              : (data['voicePlaysToday'] is num ? (data['voicePlaysToday'] as num).toInt() : 0));
      if (plays >= freeDailyLimit) {
        _showPaywall(context);
        return false;
      }
      return true;
    } catch (_) {
      _showPaywall(context);
      return false;
    }
  }

  static Future<bool> _resetDailyIfNeeded(String uid, Map<String, dynamic> data) async {
    final last = data['voiceLastUsedDate'];
    if (last == null) return false;
    DateTime? lastDate;
    if (last is Timestamp) lastDate = last.toDate();
    else if (last is String) lastDate = DateTime.tryParse(last);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (lastDate == null) return false;
    final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);
    if (lastDay.isBefore(today)) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'voicePlaysToday': 0,
        'voiceLastUsedDate': Timestamp.fromDate(now),
      });
      return true;
    }
    return false;
  }

  static void _showPaywall(BuildContext context) {
    UpgradeDialog.show(
      context,
      title: 'Voice limit reached',
      message: 'Free users get 3 voice plays per day. Upgrade to Premium for unlimited voice playback!',
      primaryActionLabel: 'Go Premium',
      onDismiss: () => Navigator.pop(context),
    );
  }

  /// Call after successful speak to increment counter.
  static Future<void> recordVoiceUse(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data() ?? {};
      final last = data['voiceLastUsedDate'];
      DateTime? lastDate;
      if (last is Timestamp) lastDate = last.toDate();
      else if (last is String) lastDate = DateTime.tryParse(last);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      int plays = 0;
      if (lastDate != null) {
        final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);
        if (!lastDay.isBefore(today)) {
          plays = data['voicePlaysToday'] is int
              ? data['voicePlaysToday'] as int
              : (data['voicePlaysToday'] is num ? (data['voicePlaysToday'] as num).toInt() : 0);
        }
      }
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'voicePlaysToday': plays + 1,
        'voiceLastUsedDate': Timestamp.fromDate(now),
      }, SetOptions(merge: true));
    } catch (e) {
      if (false) debugPrint('[VoiceGating] recordVoiceUse error: $e');
    }
  }
}

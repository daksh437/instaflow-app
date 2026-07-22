import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/analytics_firestore_service.dart';
import '../services/premium_service.dart';
import '../services/ad_service.dart';
import '../services/analytics_service.dart';
import '../widgets/upgrade_dialog.dart';
import 'connectivity_guard.dart';

/// Premium guard: Premium → allow; Trial → allow; Free → allow if dailyAiUsed < 2; else block + show paywall. Record usage only after success.
Future<void> requirePremiumOrTrial(
  BuildContext context,
  User? user,
  Future<void> Function() onSuccess, {
  String? message,
  String? toolId,
}) async {
  if (!await ConnectivityGuard.ensureConnected(context)) return;

  if (user == null) {
    _showUpgradePopup(
      context,
      title: 'Login required',
      message: message ?? 'Please log in to use this feature.',
    );
    return;
  }

  await PremiumService().resetDailyIfNeeded(user.uid);

  DocumentSnapshot? userDoc;
  try {
    userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get()
        .timeout(const Duration(seconds: 5));
  } catch (_) {
    _showUpgradePopup(
      context,
      title: 'Error',
      message: message ?? 'Could not load user data. Please try again.',
    );
    return;
  }

  if (!userDoc.exists || userDoc.data() == null) {
    _showUpgradePopup(
      context,
      title: 'Error',
      message: message ?? 'User data not found. Please try again.',
    );
    return;
  }

  final userData = UserModel.fromFirestore(
      userDoc.data()! as Map<String, dynamic>, user.uid);

  if (PremiumService.canUseAi(userData)) {
    await onSuccess();
    AnalyticsService.logAiToolUsed(toolId: toolId);
    try {
      AnalyticsFirestoreService().recordAiUsed();
    } catch (_) {}
    await PremiumService().incrementDailyAiUsage(user.uid, toolName: toolId);
    if (!PremiumService.hasActivePremium(userData)) {
      final adService = AdService();
      await adService.showInterstitialAd();
      adService.loadInterstitialAd();
    }
    return;
  }

  _showUpgradePopup(
    context,
    source: 'daily_limit',
    title: 'Daily limit reached',
    message: message ??
        'You\'ve used your free AI uses for today. Upgrade to Premium for unlimited AI and no ads!',
  );
}

/// Check if user can access premium features (sync).
bool canAccessFeature(UserModel user) {
  return PremiumService.hasActivePremium(user);
}

void _showUpgradePopup(
  BuildContext context, {
  String? source,
  required String title,
  required String message,
}) {
  AnalyticsService.logUpgradeDialogShown(source: source);
  UpgradeDialog.show(
    context,
    title: title,
    message: message,
    primaryActionLabel: 'Go Premium',
  );
}

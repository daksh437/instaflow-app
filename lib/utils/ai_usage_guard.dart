import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/access_control_service.dart';
import '../services/ai_usage_control_service.dart';
import '../utils/ai_access_exception.dart';
import '../utils/premium_guard.dart';
import '../services/analytics_service.dart';
import '../widgets/upgrade_dialog.dart';

/// Backend is source of truth: call /check-ai-access, then run AI or show paywall.
/// On DAILY_LIMIT_REACHED from API: stop retry, show paywall, log event.
Future<T?> runWithBackendAiGuard<T>(
  BuildContext context, {
  required Future<T> Function() onGenerate,
  String? limitReachedMessage,
  AiUsageControlService? service,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    UpgradeDialog.show(
      context,
      title: 'Login required',
      message: 'Please log in to use AI.',
    );
    return null;
  }
  final svc = service ?? AiUsageControlService.instance;
  final state = await svc.refresh(force: true);
  // Trial and premium: unlimited — never show upgrade dialog
  if (state.planType == 'trial' || state.planType == 'premium') {
    return await onGenerate();
  }
  // Free only: show upgrade dialog only when limit reached
  if (state.planType == 'free' && state.isLimitReached) {
    AnalyticsService.logUpgradeDialogShown(source: 'backend_ai_guard');
    UpgradeDialog.show(
      context,
      title: "Today's free uses complete",
      message: limitReachedMessage ?? state.message ?? "Today's free uses complete. Continue to go premium for unlimited AI. New free credits reset at midnight UTC.",
    );
    return null;
  }
  try {
    return await onGenerate();
  } on DailyLimitReachedException catch (e) {
    AnalyticsService.logUpgradeDialogShown(source: 'daily_limit_reached_api');
    UpgradeDialog.show(
      context,
      title: "Today's free uses complete",
      message: limitReachedMessage ?? e.message ?? "Today's free uses complete. Continue to go premium for unlimited AI. New free credits reset at midnight UTC.",
    );
    return null;
  }
}

/// Check if user can use AI (backend). Call [AiUsageControlService.refresh] first for fresh state.
Future<bool> canUserUseAiBackend({AiUsageControlService? service}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;
  final svc = service ?? AiUsageControlService.instance;
  final state = await svc.refresh();
  return state.allowed;
}

/// Get remaining AI credits today from backend (null = unlimited). Call refresh first.
Future<int?> getRemainingAiCreditsBackend({AiUsageControlService? service}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return 0;
  final svc = service ?? AiUsageControlService.instance;
  final state = await svc.refresh();
  return state.creditsLeftToday;
}

/// Example wrapper for running an AI tool with freemium guard.
/// Use this pattern in any screen that triggers AI generation.
///
/// 1. User taps "Generate" → call [runWithAiGuard].
/// 2. If trial/premium → [onGenerate] runs, no ads (trial/premium).
/// 3. If free and under 2/day → [onGenerate] runs, then interstitial may show.
/// 4. If free and 2/day reached → upgrade dialog shown, [onGenerate] not called.
Future<void> runWithAiGuard(
  BuildContext context, {
  required Future<void> Function() onGenerate,
  String? toolId,
  String? limitReachedMessage,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  await requirePremiumOrTrial(
    context,
    user,
    onGenerate,
    message: limitReachedMessage,
    toolId: toolId,
  );
}

/// Check if current user can use AI (without running). Useful to enable/disable UI.
Future<bool> canUserUseAi() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;
  final access = AccessControlService();
  return access.canUseAI(user.uid);
}

/// Get remaining free uses today (-1 = unlimited for trial/premium).
Future<int> getRemainingAiUsesToday() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return 0;
  final access = AccessControlService();
  return access.remainingFreeUsesToday(user.uid);
}

/// Show upgrade dialog manually (e.g. when trial expired and user has 0 uses).
void showUpgradeDialog(
  BuildContext context, {
  String title = 'Upgrade to Premium',
  String message = 'Get unlimited AI tools and no ads.',
  String? source,
}) {
  AnalyticsService.logUpgradeDialogShown(source: source ?? 'manual');
  UpgradeDialog.show(context, title: title, message: message);
}

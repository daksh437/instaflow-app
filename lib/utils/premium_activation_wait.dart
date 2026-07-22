import 'package:flutter/material.dart';
import '../services/ai_usage_control_service.dart';
import '../services/premium_guard.dart';

/// Poll Firestore/backend until premium is active after a Play purchase.
class PremiumActivationWait {
  static const Duration defaultTimeout = Duration(seconds: 18);
  static const Duration pollInterval = Duration(seconds: 2);

  /// Returns true when [PremiumGuard] reports active premium for [uid].
  static Future<bool> poll(
    String uid, {
    Duration timeout = defaultTimeout,
    Duration interval = pollInterval,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      PremiumGuard().invalidateCache();
      final active = await PremiumGuard().refresh(uid);
      if (active) {
        try {
          await AiUsageControlService.instance.refresh(force: true);
        } catch (_) {}
        return true;
      }
      await Future.delayed(interval);
    }
    return false;
  }

  /// Shown when payment likely succeeded but Firestore unlock is delayed.
  static Future<void> showPaymentReceivedDialog(
    BuildContext context, {
    required VoidCallback onRestore,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Payment received'),
        content: const Text(
          'Your payment was processed. Tap Restore Purchases to activate Premium on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Wait'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onRestore();
            },
            child: const Text('Restore Purchases'),
          ),
        ],
      ),
    );
  }
}

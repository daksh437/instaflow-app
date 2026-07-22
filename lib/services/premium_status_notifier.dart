import 'package:flutter/foundation.dart';

/// Tiny cross-cutting signal so the billing layer can tell the [SubscriptionGate]
/// that a purchase/restore just finished and it should re-ask the server.
/// Server (`/check-ai-access`) stays the single source of truth — this only
/// nudges the gate to refresh; it never decides premium itself.
class PremiumStatusNotifier extends ChangeNotifier {
  static final PremiumStatusNotifier instance = PremiumStatusNotifier._();
  PremiumStatusNotifier._();

  bool justActivated = false;

  /// Called by the billing layer after it hands a purchase token to the backend.
  void markActivated() {
    justActivated = true;
    notifyListeners();
  }

  void reset() {
    justActivated = false;
  }
}

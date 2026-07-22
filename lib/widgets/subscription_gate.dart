import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/subscription_plans_screen.dart';
import '../services/api_service.dart';
import '../services/premium_status_notifier.dart';

/// Hard subscription gate — **server-authoritative** (SpeakFrankly-style).
///
/// After login the whole app sits behind this gate. It asks the backend
/// (`/check-ai-access`) whether the user is premium; only `planType == 'premium'`
/// reaches [child]. Everyone else sees the blocking [SubscriptionPlansScreen]
/// until they subscribe. The client never decides premium locally — the backend
/// owns `premiumExpiry` (verified against Google Play), so there are no cache
/// races. On a network hiccup we fall back to the last known result so a paying
/// user is never locked out; the AI endpoints stay server-gated regardless.
class SubscriptionGate extends StatefulWidget {
  const SubscriptionGate({super.key, required this.child});

  final Widget child;

  @override
  State<SubscriptionGate> createState() => _SubscriptionGateState();
}

class _SubscriptionGateState extends State<SubscriptionGate>
    with WidgetsBindingObserver {
  static const _cacheKey = 'gate_was_premium';

  /// null while the first check is in flight.
  bool? _premium;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PremiumStatusNotifier.instance.addListener(_onPremiumSignal);
    _check();
  }

  @override
  void dispose() {
    PremiumStatusNotifier.instance.removeListener(_onPremiumSignal);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onPremiumSignal() {
    // A purchase/restore just handed its token to the backend — re-ask the server.
    if (PremiumStatusNotifier.instance.justActivated) {
      PremiumStatusNotifier.instance.reset();
      _check();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check after returning from the Play purchase / subscriptions screen.
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _premium = false);
      return;
    }
    bool allowed;
    try {
      final data = await ApiService().checkAiAccess();
      // Access to the app = active 3-day trial OR paid Premium. After the trial
      // ends the plan becomes 'free' → gate shows the paywall.
      final plan = data['planType']?.toString().toLowerCase();
      allowed = (plan == 'premium' || plan == 'trial');
      // Remember for the offline/degraded fallback below.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_cacheKey, allowed);
      } catch (_) {}
    } catch (_) {
      // Backend unreachable → don't lock out a trial/paying user. Use the last
      // known result; AI features stay server-gated anyway.
      try {
        final prefs = await SharedPreferences.getInstance();
        allowed = prefs.getBool(_cacheKey) ?? false;
      } catch (_) {
        allowed = false;
      }
    }
    if (mounted) setState(() => _premium = allowed);
  }

  @override
  Widget build(BuildContext context) {
    if (_premium == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF7B2CBF),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    if (_premium == true) return widget.child;
    return const SubscriptionPlansScreen();
  }
}

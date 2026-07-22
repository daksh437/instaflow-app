import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/plan_option.dart';
import '../services/play_billing_service.dart';
import '../services/subscription_service.dart';
import '../services/analytics_service.dart';
import '../services/analytics_event_service.dart';
import '../services/notification_service.dart';

/// Mandatory "Subscription Plans" screen shown by [SubscriptionGate] to
/// non-premium users. Clean single-plan flow: **₹10 for 7 days, then
/// ₹199/month** (whatever the Play Console intro offer on `premium_monthly`
/// says), a feature list, and one "Start Free Trial" button.
///
/// Purchasing reuses [PlayBillingService] — activation, Firestore, analytics
/// and the [PremiumGuard] refresh are handled by its global purchase listener,
/// which flips the gate open. This screen never navigates on success.
class SubscriptionPlansScreen extends StatefulWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  State<SubscriptionPlansScreen> createState() =>
      _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  static const Color _primary = Color(0xFF7B2CBF);
  static const Color _pink = Color(0xFFFF7AD9);

  final SubscriptionService _subService = SubscriptionService();
  final PlayBillingService _billing = PlayBillingService();

  static const List<String> _perks = [
    'Unlimited AI captions, hashtags & ideas',
    'Reel scripts, hooks & carousel writer',
    'Bio maker, rewrite & content engine',
    'AI calendar, strategy & niche analysis',
    'No daily limits — full access',
  ];

  PlanOption? _introOption; // monthly plan with the cheapest first phase (₹10)
  String? _basePriceLabel; // recurring price after intro (₹199/month)
  bool _loading = true;
  bool _loadFailed = false;
  bool _buying = false;

  /// Send the "subscribe" nudge at most once per app session (avoid spam).
  static bool _reminderSentThisSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AnalyticsService.logPaywallOpen();
      AnalyticsEventService().logPaywallOpen();
      _maybeSendSubscribeReminder();
      _loadPlans();
    });
  }

  Future<void> _maybeSendSubscribeReminder() async {
    if (_reminderSentThisSession) return;
    _reminderSentThisSession = true;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await NotificationService().sendSubscribeReminderNotification(uid);
    } catch (_) {}
  }

  Future<void> _loadPlans() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final map = await _subService.getProductMap();
      final product = map[SubscriptionService.subscriptionId];
      final options = _subService.getSortedPlanOptions(product);

      if (options.isEmpty) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
        return;
      }

      // The intro is the offer with the cheapest FIRST phase — e.g. the
      // "₹10 for 7 days" offer, whose first phase reports P1W (not P1M). So we
      // pick by lowest price across all offers (do NOT filter by P1M — that
      // hides the weekly intro phase). The recurring price for "then ₹x/month"
      // comes from the monthly (P1M) base plan.
      final sorted = [...options]
        ..sort((a, b) => _numeric(a.price).compareTo(_numeric(b.price)));
      final intro = sorted.first;
      final base = sorted.firstWhere(
        (o) => o.billingPeriod == 'P1M',
        orElse: () => sorted.last,
      );

      setState(() {
        _introOption = intro;
        _basePriceLabel = base.price;
        _loading = false;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[SubscriptionPlans] load error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  double _numeric(String price) {
    final digits = price.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(digits) ?? 0;
  }

  String get _introPriceLabel => _introOption?.price ?? '₹10';

  String get _monthlyPriceLabel => _basePriceLabel ?? '₹199';

  /// True when a real discounted intro exists (new customer). Existing/returning
  /// users are not eligible for the ₹10 offer, so Play returns only the ₹199
  /// base — then intro == base and we show plain monthly pricing.
  bool get _hasIntro =>
      _introOption != null &&
      _basePriceLabel != null &&
      _numeric(_introOption!.price) < _numeric(_basePriceLabel!);

  Future<void> _startTrial() async {
    final option = _introOption;
    final details = option?.productDetailsForPurchase;
    if (_buying) return;
    if (details == null) {
      _snack('Plans are still loading. Please try again.');
      _loadPlans();
      return;
    }

    setState(() => _buying = true);
    // Feed billing analytics/duration so PlayBillingService logs correctly.
    PlayBillingService.selectedDuration = option!.durationKey;
    PlayBillingService.lastPurchasePrice = option.price;
    PlayBillingService.lastPurchaseValue = _numeric(option.price);
    try {
      final launched = await _billing.buy(details);
      if (!launched && mounted) {
        setState(() => _buying = false);
        _snack('Could not start checkout. Please try again.');
        return;
      }
      // On success the global purchase listener activates premium (client +
      // server safety net) and SubscriptionGate swaps this screen out. If that
      // hasn't happened after a while, stop the spinner so the user isn't stuck
      // and can retry / restore.
      Future<void>.delayed(const Duration(seconds: 30), () {
        if (mounted && _buying) {
          setState(() => _buying = false);
          _snack('Payment received. If premium is not active yet, tap Restore.');
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _buying = false);
        _snack('Something went wrong, try again.');
      }
    }
  }

  Future<void> _restore() async {
    _snack('Checking your subscription…');
    await _billing.restore();
  }

  /// Sign out so the user can switch to another account. The auth
  /// StreamBuilder in main.dart then shows the LoginScreen.
  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      if (kDebugMode) debugPrint('[SubscriptionPlans] logout error: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _header(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _primary))
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unlock every AI tool in InstaFlow.',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[700],
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _planCard(),
                        const SizedBox(height: 24),
                        const Text(
                          'What you get',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._perks.map(_perkRow),
                        if (_loadFailed) ...[
                          const SizedBox(height: 16),
                          _retryRow(),
                        ],
                      ],
                    ),
                  ),
          ),
          _footer(),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 14,
        20,
        16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_primary, _pink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Text(
        'Subscription Plans',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _planCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        border: Border.all(color: _primary, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Premium',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _primary,
                ),
              ),
              const Spacer(),
              const Icon(Icons.check_circle_rounded, color: _primary, size: 24),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _hasIntro
                ? 'Just $_introPriceLabel for the first 7 days'
                : '$_monthlyPriceLabel / month',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF16A34A),
              height: 1.15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _hasIntro
                ? 'Then $_monthlyPriceLabel / month'
                : 'Full access • cancel anytime',
            style: TextStyle(fontSize: 15, color: Colors.grey[700]),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded,
                  size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pay securely via Google Play (UPI / card)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _perkRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: _primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _retryRow() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Could not load plans. Check your connection.',
            style: TextStyle(fontSize: 12.5, color: Colors.red[700]),
          ),
        ),
        TextButton(onPressed: _loadPlans, child: const Text('Retry')),
      ],
    );
  }

  Widget _footer() {
    final busy = _buying;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy ? null : _startTrial,
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _hasIntro
                            ? 'Start — $_introPriceLabel for 7 days'
                            : 'Subscribe • $_monthlyPriceLabel/mo',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: busy ? null : _restore,
                  child: const Text('Restore'),
                ),
                Text('·', style: TextStyle(color: Colors.grey[400])),
                TextButton(
                  onPressed: busy ? null : _logout,
                  child: Text(
                    'Log out',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
            Text(
              _hasIntro
                  ? '$_introPriceLabel for the first 7 days, then '
                      '$_monthlyPriceLabel/month. Auto-renews via Google Play '
                      'unless canceled. Cancel anytime in Play Store → '
                      'Payments & subscriptions.'
                  : '$_monthlyPriceLabel/month. Auto-renews via Google Play '
                      'unless canceled. Cancel anytime in Play Store → '
                      'Payments & subscriptions.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.4,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

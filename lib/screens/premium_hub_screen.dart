import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../config/monetization_config.dart';
import '../models/plan_option.dart';
import '../services/play_billing_service.dart';
import '../services/subscription_service.dart';
import '../utils/connectivity_guard.dart';
import '../utils/premium_activation_wait.dart';
import '../widgets/main_navigation_wrapper.dart';

class PremiumHubScreen extends StatefulWidget {
  const PremiumHubScreen({super.key});

  @override
  State<PremiumHubScreen> createState() => _PremiumHubScreenState();
}

class _PremiumHubScreenState extends State<PremiumHubScreen> {
  static const _friendlyError = 'Something went wrong, try again';

  final PlayBillingService _billing = PlayBillingService();
  final SubscriptionService _subscriptionService = SubscriptionService();

  bool _loadingProducts = true;
  bool _processing = false;
  ProductDetails? _product;
  PlanOption? _selectedPlan;
  List<PlanOption> _plans = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadProducts();
    });
  }

  Future<void> _loadProducts() async {
    if (!mounted) return;
    setState(() => _loadingProducts = true);
    try {
      await _billing.initialize();
      final map = await _subscriptionService.getProductMap();
      final p = map[SubscriptionService.subscriptionId];
      final plans = _subscriptionService.getSortedPlanOptions(p);
      if (!mounted) return;
      setState(() {
        _product = p;
        _plans = plans;
        _selectedPlan = plans.isNotEmpty ? plans.first : null;
        _loadingProducts = false;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[PremiumHub] loadProducts error: $e');
      if (!mounted) return;
      setState(() => _loadingProducts = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(_friendlyError), backgroundColor: Color(0xFFB00020)),
      );
    }
  }

  Future<void> _buyPremium() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }
    if (!await ConnectivityGuard.ensureConnected(context)) return;
    final product = _product;
    final plan = _selectedPlan;
    if (product == null || plan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Products not loaded, please retry'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _processing = true);
    try {
      await _billing.initialize();
      PlayBillingService.selectedDuration = plan.durationKey;
      if (kDebugMode) {
        debugPrint('[PremiumHub] purchase requested product=${product.id} duration=${plan.durationKey}');
      }
      final purchaseProduct = plan.productDetailsForPurchase ?? product;
      final ok = await _billing.purchaseSubscription(purchaseProduct);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase cancelled or failed'), backgroundColor: Colors.orange),
        );
        return;
      }
      final activated = await PremiumActivationWait.poll(uid);
      if (!mounted) return;
      if (activated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Premium activated'), backgroundColor: Color(0xFF7B2CBF)),
        );
        return;
      }
      await PremiumActivationWait.showPaymentReceivedDialog(
        context,
        onRestore: _restorePurchases,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[PremiumHub] buy error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(_friendlyError), backgroundColor: Color(0xFFB00020)),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _restorePurchases() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }
    if (!await ConnectivityGuard.ensureConnected(context)) return;
    if (!mounted) return;
    setState(() => _processing = true);
    try {
      if (kDebugMode) debugPrint('[PremiumHub] restore triggered');
      final ok = await _billing.restore();
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Store is not available. Try again later.'), backgroundColor: Colors.orange),
        );
        return;
      }
      await Future.delayed(const Duration(seconds: 2));
      final activated = await PremiumActivationWait.poll(uid);
      if (kDebugMode) debugPrint('[PremiumHub] restore completed -> premium=$activated');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(activated ? 'Purchases restored successfully' : 'No active purchases found'),
          backgroundColor: activated ? const Color(0xFF7B2CBF) : Colors.orange,
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[PremiumHub] restore error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(_friendlyError), backgroundColor: Color(0xFFB00020)),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Please sign in')));
    }

    return MainNavigationWrapper(
      currentIndex: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Premium'),
          backgroundColor: const Color(0xFF7B2CBF),
          foregroundColor: Colors.white,
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Something went wrong, try again'),
                ),
              );
            }
            final data = snapshot.data?.data() ?? <String, dynamic>{};
            final now = DateTime.now();
            final isPremium = data['isPremium'] == true;
            final premiumExpiry = (data['premiumExpiry'] as Timestamp?)?.toDate();
            final trialEnd = (data['trialEnd'] as Timestamp?)?.toDate() ?? (data['trialEndDate'] as Timestamp?)?.toDate();
            final used = (data['dailyUsedCount'] ?? data['dailyAiUsed'] ?? 0) is num
                ? (data['dailyUsedCount'] ?? data['dailyAiUsed'] ?? 0).toInt()
                : 0;
            final freeLeft = (MonetizationConfig.dailyFreeUsesLimit - used).clamp(0, MonetizationConfig.dailyFreeUsesLimit);

            // Freemium status: Trial (unlimited, N days) → Free (X/2 daily) → Premium.
            String status = 'Free';
            String subtitle = '$freeLeft / ${MonetizationConfig.dailyFreeUsesLimit} daily uses left';
            final premiumActive = isPremium && premiumExpiry != null && premiumExpiry.isAfter(now);
            if (!premiumActive && trialEnd != null && trialEnd.isAfter(now)) {
              final days = trialEnd.difference(now).inDays + 1;
              status = 'Trial';
              subtitle = 'Unlimited AI • $days day${days == 1 ? '' : 's'} left';
            }
            if (premiumActive) {
              final days = premiumExpiry.difference(now).inDays + 1;
              status = 'Premium';
              subtitle = 'Unlimited AI • Active • $days day${days == 1 ? '' : 's'} left';
            }

            final price = _selectedPlan?.price ?? _product?.price ?? '';
            final plansReady = _product != null && _plans.isNotEmpty && _selectedPlan != null;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Current Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 8),
                      Text(status, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 24, color: Color(0xFF7B2CBF))),
                      const SizedBox(height: 4),
                      Text(subtitle),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('What you get', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 8),
                      const Text('• Unlimited AI captions, hashtags, ideas & scripts'),
                      const Text('• Bio maker, rewrite, content engine & AI calendar'),
                      const Text('• No daily limits, no ads — full access to all tools'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7B2CBF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Recommended: Premium', style: TextStyle(color: Color(0xFF7B2CBF), fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Billing Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 8),
                      if (_loadingProducts)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(),
                        ),
                      if (!_loadingProducts && _plans.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _plans
                              .map((p) => ChoiceChip(
                                    label: Text('${p.title} • ${p.price}'),
                                    selected: _selectedPlan?.offerToken == p.offerToken,
                                    onSelected: _processing ? null : (_) => setState(() => _selectedPlan = p),
                                  ))
                              .toList(),
                        ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_processing || !plansReady) ? null : _buyPremium,
                          child: Text(_processing ? 'Please wait...' : (price.isNotEmpty ? 'Buy Premium • $price' : 'Buy Premium')),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _processing ? null : _restorePurchases,
                          child: const Text('Restore Purchases'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Billing FAQ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      SizedBox(height: 8),
                      Text('• Subscription renews automatically unless cancelled in Play Store.'),
                      Text('• You can restore purchases anytime on this screen.'),
                      Text('• Premium unlock syncs from purchase events and app restart restore.'),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}


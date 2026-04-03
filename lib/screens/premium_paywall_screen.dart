import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shimmer/shimmer.dart';

import '../models/plan_option.dart';
import '../models/user_model.dart';
import '../services/play_billing_service.dart';
import '../services/premium_service.dart';
import '../services/subscription_service.dart';
import '../services/premium_guard.dart';
import '../services/ad_service.dart';
import '../services/analytics_service.dart';
import '../services/analytics_event_service.dart';
import '../utils/connectivity_guard.dart';
import '../utils/global_error_handler.dart';

class PremiumPaywallScreen extends StatefulWidget {
  const PremiumPaywallScreen({super.key});

  @override
  State<PremiumPaywallScreen> createState() => _PremiumPaywallScreenState();
}

class _PremiumPaywallScreenState extends State<PremiumPaywallScreen> {
  bool _isProcessing = false;
  UserModel? _userModel;
  bool _isLoadingUser = false;
  bool _hasUsedTrial = false;
  ProductDetails? _selectedProduct;
  PlanOption? _selectedPlan;

  final PlayBillingService _billingService = PlayBillingService();
  final SubscriptionService _subscriptionService = SubscriptionService();

  Map<String, ProductDetails> _productMap = {};
  List<PlanOption> _planOptions = [];
  bool _isLoadingProducts = true;
  bool _productsLoadFailed = false;
  static const Duration _autoRetryDelay = Duration(seconds: 3);

  /// Single subscription product (premium_monthly).
  ProductDetails? get _subscriptionProduct =>
      _productMap[SubscriptionService.subscriptionId];

  /// Sorted plan options (base plans) from subscription offers. Used for duration cards.
  List<PlanOption> get _sortedPlanOptions => _planOptions;

  /// Selected plan price from selected PlanOption.
  String get _selectedPrice => _selectedPlan?.price ?? '';

  @override
  void initState() {
    super.initState();
    if (kDebugMode) debugPrint('[Paywall] initState');
    AdService().setPaymentFlowActive(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AnalyticsService.logPaywallOpen();
      AnalyticsEventService().logPaywallOpen();
      _loadUserData();
      _loadProducts();
    });
  }

  @override
  void dispose() {
    AdService().setPaymentFlowActive(false);
    super.dispose();
  }

  Future<void> _loadProducts() async {
    if (kDebugMode) debugPrint('[Paywall] _loadProducts start');
    if (!mounted) return;
    setState(() {
      _isLoadingProducts = true;
      _productsLoadFailed = false;
    });
    try {
      final map = await _subscriptionService.getProductMap().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          if (kDebugMode) debugPrint('[Paywall] Product map timeout');
          return <String, ProductDetails>{};
        },
      );
      if (kDebugMode) debugPrint('[Paywall] _loadProducts done: ${map.length} products');
      if (!mounted) return;
      final product = map[SubscriptionService.subscriptionId];
      final plans = _subscriptionService.getSortedPlanOptions(product);
      setState(() {
        _productMap = map;
        _planOptions = plans;
        _isLoadingProducts = false;
        _productsLoadFailed = map.isEmpty || plans.isEmpty;
        _selectedProduct = product;
        if (plans.isNotEmpty) {
          _selectedPlan = (_selectedPlan != null && plans.any((p) => p.offerToken == _selectedPlan!.offerToken))
              ? _selectedPlan
              : plans.first;
        } else {
          _selectedPlan = null;
        }
      });
      if (map.isEmpty && mounted) _scheduleAutoRetry();
    } catch (e) {
      if (kDebugMode) debugPrint('[Paywall] _loadProducts error: $e');
      if (!mounted) return;
      setState(() {
        _productMap = {};
        _isLoadingProducts = false;
        _productsLoadFailed = true;
      });
      GlobalErrorHandler.showSnackBar(context, e);
      _scheduleAutoRetry();
    }
  }

  void _scheduleAutoRetry() {
    Future.delayed(_autoRetryDelay, () {
      if (!mounted) return;
      if (_productMap.isNotEmpty) return;
      if (kDebugMode) debugPrint('[Paywall] auto-retry loading products');
      _loadProducts();
    });
  }

  Future<void> _loadUserData() async {
    if (kDebugMode) debugPrint('[Paywall] _loadUserData start');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (kDebugMode) debugPrint('[Paywall] _loadUserData: no user');
      if (mounted) setState(() => _isLoadingUser = false);
      return;
    }
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 5));
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null && mounted) {
          final userModel = UserModel.fromFirestore(data, user.uid);
          setState(() {
            _userModel = userModel;
            _hasUsedTrial = userModel.trialStart != null;
          });
        }
      }
      if (kDebugMode) debugPrint('[Paywall] _loadUserData done');
    } catch (e) {
      if (kDebugMode) debugPrint('[Paywall] _loadUserData error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingUser = false);
    }
  }

  Future<void> _startTrial() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _isProcessing = true);
    try {
      final premiumService = PremiumService();
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null) {
          final userModel = UserModel.fromFirestore(data, user.uid);
          if (PremiumService.isTrialOngoing(userModel)) {
          if (mounted) setState(() => _isProcessing = false);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You already have an active trial!'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
          }
        }
      }
      await premiumService.initializeTrial(user.uid);
      if (mounted) setState(() => _isProcessing = false);
      _hasUsedTrial = true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 7-day free trial activated!'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadUserData();
    } catch (e) {
      if (mounted) setState(() => _isProcessing = false);
      if (mounted) {
        GlobalErrorHandler.log('PaywallLoad', e);
        GlobalErrorHandler.showSnackBar(context, e);
      }
    }
  }

  Future<void> _startPayment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }
    if (!await ConnectivityGuard.ensureConnected(context)) return;

    if (_productMap.isEmpty || _planOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Products not loaded — install app from Play Store testing track'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final product = _selectedProduct;
    final plan = _selectedPlan;
    if (product == null || plan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subscription not available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    AnalyticsService.logPurchaseStarted(productId: product.id, price: plan.price);
    AnalyticsEventService().logPurchaseStarted(
      productId: product.id,
      price: plan.price,
    );
    final durationKey = plan.durationKey;
    AnalyticsEventService().logAnalyticsEventPurchaseStart(user.uid, durationKey);

    PlayBillingService.selectedDuration = durationKey;

    setState(() => _isProcessing = true);
    try {
      final productToPurchase = plan.productDetailsForPurchase ?? product;
      final success = await _billingService.purchaseSubscription(productToPurchase);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Processing purchase...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
        await Future.delayed(const Duration(seconds: 2));
        await PremiumGuard().refresh(user.uid);
        if (!mounted) return;
        final isPremium = await PremiumGuard().isPremium(user.uid);
        if (isPremium) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🎉 Premium activated successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          Navigator.pop(context);
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase is being processed. Please wait...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase cancelled or failed. Please try again.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Purchase error: $e');
      if (!mounted) return;
      GlobalErrorHandler.log('PaywallPurchase', e);
      GlobalErrorHandler.showSnackBar(context, e);
      final msg = e.toString().toLowerCase();
      if (msg.contains('not available') || msg.contains('billing is not available')) {
        _showBillingUnavailableDialog();
      } else {
        _showPurchaseFailedDialog();
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showBillingErrorDialog({
    required String title,
    required String message,
    VoidCallback? onRetry,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                onRetry();
              },
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  void _showPurchaseFailedDialog() {
    _showBillingErrorDialog(
      title: 'Purchase failed',
      message:
          'The purchase could not be completed. Please check your connection and try again.',
      onRetry: () {
        if (!_isProcessing && _productMap.isNotEmpty) _startPayment();
      },
    );
  }

  void _showRestoreFailedDialog() {
    _showBillingErrorDialog(
      title: 'Restore failed',
      message: 'We couldn\'t restore your purchases. Please try again.',
      onRetry: () => _restorePurchases(),
    );
  }

  void _showBillingUnavailableDialog() {
    _showBillingErrorDialog(
      title: 'Billing unavailable',
      message:
          'In-app billing is not available. Install the app from the Play Store and try again.',
      onRetry: () => _loadProducts(),
    );
  }

  Future<void> _restorePurchases() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }
    if (!await ConnectivityGuard.ensureConnected(context)) return;

    AnalyticsService.logRestoreClicked();
    AnalyticsEventService().logRestoreClicked();

    if (!mounted) return;
    setState(() => _isProcessing = true);
    try {
      final ok = await _billingService.restore();
      if (!ok && mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Store is not available. Try again later.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      await Future.delayed(const Duration(seconds: 2));
      await PremiumGuard().refresh(user.uid);
      await _loadProducts();
      if (!mounted) return;
      final isPremium = await PremiumGuard().isPremium(user.uid);
      if (kDebugMode) debugPrint('[Paywall] restore result: isPremium=$isPremium');
      if (isPremium) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase restored successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active purchases found to restore.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Restore error: $e');
      if (!mounted) return;
      GlobalErrorHandler.log('PaywallRestore', e);
      GlobalErrorHandler.showSnackBar(context, e);
      final msg = e.toString().toLowerCase();
      if (msg.contains('not available') || msg.contains('billing is not available')) {
        _showBillingUnavailableDialog();
      } else {
        _showRestoreFailedDialog();
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) debugPrint('[Paywall] build: loadingUser=$_isLoadingUser loadingProducts=$_isLoadingProducts products=${_productMap.length} plans=${_planOptions.length}');
    final loading = _isLoadingUser || _isLoadingProducts;
    final productsEmpty = _productMap.isEmpty || _planOptions.isEmpty;

    Widget body;
    try {
      if (loading) {
        body = _buildLoaderUi();
      } else if (productsEmpty) {
        body = _buildProductsNotLoaded();
      } else {
        body = _buildPaywallContent();
      }
    } catch (e, st) {
      if (kDebugMode) debugPrint('[Paywall] build body error: $e $st');
      body = _buildEmergencyFallback();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Go Premium'),
        backgroundColor: const Color(0xFF7B2CBF),
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        actions: [
          TextButton(
            onPressed: (_isProcessing || loading || _sortedPlanOptions.isEmpty) ? null : _restorePurchases,
            child: const Text('Restore', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Material(
        color: Colors.white,
        child: body,
      ),
    );
  }

  /// Loader UI — never empty.
  Widget _buildLoaderUi() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF7B2CBF)),
          const SizedBox(height: 20),
          Text(
            'Loading...',
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  /// Emergency fallback if body builder throws.
  Widget _buildEmergencyFallback() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[600]),
            const SizedBox(height: 16),
            const Text(
              'Paywall failed to load — tap retry',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Color(0xFF1A1A1A)),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                if (!mounted) return;
                setState(() {
                  _isLoadingProducts = true;
                  _isLoadingUser = true;
                });
                _loadUserData();
                _loadProducts();
              },
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7B2CBF)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[400] ?? Colors.grey,
      highlightColor: Colors.grey[200] ?? Colors.grey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 140,
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(child: _shimmerBox(180)),
                  const SizedBox(width: 12),
                  Expanded(child: _shimmerBox(180)),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _shimmerBox(20, width: 140),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: List.generate(
                  4,
                  (_) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _shimmerBox(90),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: _shimmerBox(70)),
            const SizedBox(height: 24),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: _shimmerBox(56)),
          ],
        ),
      ),
    );
  }

  Widget _shimmerBox(double height, {double? width}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  /// When productDetails list is empty: show fallback message, retry button, loading state if retrying.
  Widget _buildProductsNotLoaded() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.storefront_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 24),
              Text(
                _productsLoadFailed
                    ? 'Products could not be loaded. Please check your connection and try again.'
                    : 'Loading products from store...',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[700], height: 1.4),
              ),
              const SizedBox(height: 8),
              const Text(
                'Install the app from the Play Store if you haven\'t already.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.3),
              ),
              const SizedBox(height: 24),
              if (_isLoadingProducts)
                const SizedBox(
                  height: 40,
                  width: 40,
                  child: CircularProgressIndicator(color: Color(0xFF7B2CBF)),
                )
              else
                FilledButton(
                  onPressed: _loadProducts,
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7B2CBF)),
                  child: const Text('Retry'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaywallContent() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        _buildHeader(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFreeVsPremium(),
              const SizedBox(height: 20),
              _buildTrustBadges(),
              const SizedBox(height: 24),
              const Text(
                'Select Duration',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Cancel anytime — no commitment.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              _buildDurationCards(),
              const SizedBox(height: 24),
              _buildTotalBox(),
              const SizedBox(height: 24),
              _buildSubscriptionDisclosures(),
              const SizedBox(height: 24),
              _buildContinueButton(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 160),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6A1B9A), Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF7B2CBF),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.workspace_premium_rounded, size: 22, color: Colors.white.withOpacity(0.95)),
                const SizedBox(width: 8),
                const Text(
                  'Go Premium',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Unlimited AI tools • No ads • Cancel anytime',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.92),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 6,
              children: [
                _headerChip(Icons.lock_rounded, 'Secure'),
                _headerChip(Icons.verified_user_rounded, 'Trusted'),
                _headerChip(Icons.cancel_outlined, 'Cancel anytime'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withOpacity(0.95)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.95)),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildFreeVsPremium() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey[300] ?? Colors.grey),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Free',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 10),
                _featureRow('2 AI uses/day'),
                _featureRow('Ads shown'),
                _featureRow('Basic tools'),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF7B2CBF).withOpacity(0.12),
                  const Color(0xFF9D4EDD).withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF7B2CBF), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7B2CBF).withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.star_rounded, size: 18, color: const Color(0xFF7B2CBF)),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        'Premium',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7B2CBF),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _featureRow('Unlimited AI', isPremium: true),
                _featureRow('No Ads', isPremium: true),
                _featureRow('Faster results', isPremium: true),
              ],
            ),
          ),
        ),
      ],
    ),
    );
  }

  Widget _featureRow(String text, {bool isPremium = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 18,
            color: isPremium ? const Color(0xFF7B2CBF) : Colors.grey[700],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: isPremium ? Colors.grey[900] : Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Trust badges: wrap so no overflow on small screens.
  Widget _buildTrustBadges() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF7B2CBF).withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF7B2CBF).withOpacity(0.2)),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 10,
        children: [
          _trustChip(Icons.lock_rounded, 'Secure'),
          _trustChip(Icons.cancel_outlined, 'Cancel anytime'),
          _trustChip(Icons.bolt_rounded, 'Instant'),
        ],
      ),
    );
  }

  Widget _trustChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF7B2CBF)),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF5A189A),
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }

  /// Duration cards: built dynamically from plan options (base plans). Selectable cards per plan.
  Widget _buildDurationCards() {
    final plans = _sortedPlanOptions;
    if (plans.isEmpty) return const SizedBox.shrink();
    return Row(
      children: plans.map((PlanOption plan) {
        final isSelected = _selectedPlan?.offerToken == plan.offerToken;
        final badge = plan.billingPeriod == 'P1Y' ? 'Popular' : null;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _DurationCard(
              label: plan.title,
              price: plan.price,
              isSelected: isSelected,
              badge: badge,
              onTap: () {
                setState(() => _selectedPlan = plan);
                AnalyticsService.logPlanSelected(
                  productId: SubscriptionService.subscriptionId,
                  price: plan.price,
                  duration: plan.durationKey,
                );
                AnalyticsEventService().logPlanSelected(
                  planId: plan.basePlanId,
                  price: plan.price,
                  duration: plan.durationKey,
                );
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTotalBox() {
    final price = _selectedPrice;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200] ?? Colors.grey),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Total',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Flexible(
            child: Text(
              price,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: price.isEmpty ? (Colors.grey[600] ?? Colors.grey) : const Color(0xFF7B2CBF),
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionDisclosures() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200] ?? Colors.blue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Subscription Information',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your payment is secure with Google Play. Charged to your Play account. Renews automatically unless cancelled 24h before period end. Manage in Play Store settings.',
            style: TextStyle(fontSize: 11, color: Colors.grey[800], height: 1.4),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    final price = _selectedPrice;
    final productsReady = _productMap.isNotEmpty && _selectedProduct != null && _selectedPlan != null;
    final disabled = _isProcessing;
    final buttonLabel = _isLoadingProducts && _productMap.isEmpty
        ? 'Loading...'
        : !productsReady
            ? 'Retry'
            : _hasUsedTrial
                ? (price.isNotEmpty ? 'Subscribe · $price' : 'Continue')
                : 'Start 7-Day Free Trial';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton(
            onPressed: disabled
                ? null
                : (!productsReady ? _loadProducts : (_hasUsedTrial ? _startPayment : _startTrial)),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7B2CBF),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[300],
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: _isProcessing
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      buttonLabel,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, size: 12, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                'Secure · Google Play',
                style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DurationCard extends StatelessWidget {
  const _DurationCard({
    required this.label,
    required this.price,
    required this.isSelected,
    this.badge,
    required this.onTap,
  });

  final String label;
  final String price;
  final bool isSelected;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF7B2CBF).withOpacity(0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF7B2CBF) : (Colors.grey[300] ?? Colors.grey),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badge?.isNotEmpty == true)
              Text(
                badge!,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? const Color(0xFF7B2CBF) : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (badge != null) const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isSelected ? const Color(0xFF7B2CBF) : Colors.grey[700],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              price,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF7B2CBF) : Colors.grey[900],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

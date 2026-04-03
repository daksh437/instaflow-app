import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';
import '../services/access_control_service.dart';
import '../services/premium_service.dart';
import '../utils/app_error_handler.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final AccessControlService _accessControl = AccessControlService();
  final PremiumService _premiumService = PremiumService();
  bool _isLoading = true;
  bool _isProcessing = false;
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _loadSubscription();
  }

  Future<void> _loadSubscription() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    await _premiumService.checkAndUpdateTrialExpiry(user.uid);
    final model = await _accessControl.getUser(user.uid);

    if (mounted) {
      setState(() {
        _user = model;
        _isLoading = false;
      });
    }
  }

  Future<void> _startCheckout(SubscriptionPlan plan) async {
    if (!mounted) return;
    setState(() => _isProcessing = true);
    try {
      await Navigator.of(context).pushNamed('/premium');
      if (mounted) await _loadSubscription();
    } catch (e) {
      if (mounted) {
        AppErrorHandler.log('SubscriptionCheckout', e);
        AppErrorHandler.show(context, e);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  String _trialCountdown(DateTime end) {
    final now = DateTime.now();
    if (now.isAfter(end)) return 'Trial expired';
    final remaining = end.difference(now);
    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    if (days > 0) {
      return '$days day${days > 1 ? 's' : ''} left';
    }
    return '$hours hour${hours > 1 ? 's' : ''} left';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = _user?.subscriptionPlan ?? SubscriptionPlan.free;
    final isTrialActive = _user?.isTrialActive ?? false;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Subscriptions'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSubscription,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (isTrialActive) ...[
                    _TrialBanner(
                      countdown: _trialCountdown(_user!.trialEndsAt!),
                    ),
                    const SizedBox(height: 20),
                  ] else if (plan == SubscriptionPlan.trial) ...[
                    _TrialExpiredBanner(onTap: () => _startCheckout(SubscriptionPlan.pro)),
                    const SizedBox(height: 20),
                  ],
                  _PlanCard(
                    title: 'Pro',
                    priceLabel: 'US\$10 / month',
                    highlight: plan == SubscriptionPlan.pro,
                    accentColor: const Color(0xFF6C5CE7),
                    badge: plan == SubscriptionPlan.pro
                        ? 'Active'
                        : (plan == SubscriptionPlan.trial && isTrialActive)
                            ? 'Included in trial'
                            : null,
                    features: const [
                      'Unlimited AI captions',
                      'Advanced hashtag analyzer',
                      'Full analytics dashboard',
                      'Automated scheduling reminders',
                      'Priority creator support',
                    ],
                    action: plan == SubscriptionPlan.pro
                        ? null
                        : () => _startCheckout(SubscriptionPlan.pro),
                    actionLabel: 'Upgrade to Pro',
                    busy: _isProcessing,
                  ),
                  const SizedBox(height: 18),
                  _PlanCard(
                    title: 'Ultra Pro',
                    priceLabel: 'US\$20 / month',
                    highlight: plan == SubscriptionPlan.ultra,
                    accentColor: const Color(0xFF8A3FFC),
                    badge: plan == SubscriptionPlan.ultra ? 'Active' : 'Best Value',
                    features: const [
                      'Everything in Pro',
                      'AI-powered campaign drafting',
                      'Automatic multi-account scheduling',
                      'Collaborator workspaces',
                      'Dedicated success manager',
                    ],
                    action: plan == SubscriptionPlan.ultra
                        ? null
                        : () => _startCheckout(SubscriptionPlan.ultra),
                    actionLabel: 'Go Ultra Pro',
                    busy: _isProcessing,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    "After you complete checkout, your plan updates automatically. Billing is handled securely by Google Play, and subscriptions renew automatically unless cancelled through Google Play Store settings.",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _TrialBanner extends StatelessWidget {
  const _TrialBanner({required this.countdown});

  final String countdown;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C5CE7), Color(0xFFA06BFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.auto_awesome, color: Colors.white),
              SizedBox(width: 10),
              Text(
                'You are on the 7-day free trial',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Access all Pro features while your trial lasts.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              countdown,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrialExpiredBanner extends StatelessWidget {
  const _TrialExpiredBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline, color: Colors.deepOrange),
              SizedBox(width: 10),
              Text(
                'Your trial has ended',
                style: TextStyle(
                  color: Colors.deepOrange,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Upgrade now to keep unlimited captions, analytics, and automation running.',
            style: TextStyle(color: Colors.black87, fontSize: 13),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onTap,
            child: const Text('Upgrade to Pro'),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.priceLabel,
    required this.features,
    required this.accentColor,
    this.highlight = false,
    this.badge,
    this.action,
    this.actionLabel,
    this.busy = false,
  });

  final String title;
  final String priceLabel;
  final List<String> features;
  final Color accentColor;
  final bool highlight;
  final String? badge;
  final VoidCallback? action;
  final String? actionLabel;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: highlight ? accentColor.withOpacity(0.12) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accentColor.withOpacity(highlight ? 0.4 : 0.2),
          width: highlight ? 2 : 1,
        ),
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: accentColor.withOpacity(0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 12),
              if (badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            priceLabel,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: accentColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          for (final feature in features)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: accentColor, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      feature,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          if (action != null && actionLabel != null) ...[
            const SizedBox(height: 18),
            FilledButton(
              onPressed: busy ? null : action,
              style: FilledButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}


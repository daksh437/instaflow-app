import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/monetization_config.dart';
import '../services/monetization_service.dart';

/// Home usage: plan, trial, or free daily limit with midnight reset.
/// [style] `glassOnGradient` = legacy frosted chip on purple header.
/// [style] `elevatedLight` = single white SaaS card (no duplicate lines).
enum MonetizationCardStyle {
  glassOnGradient,
  elevatedLight,
}

class MonetizationStatusCard extends StatefulWidget {
  const MonetizationStatusCard({
    super.key,
    this.onGoToPremium,
    this.style = MonetizationCardStyle.glassOnGradient,
    this.primaryColor = const Color(0xFF7B61FF),
  });

  final VoidCallback? onGoToPremium;
  final MonetizationCardStyle style;
  final Color primaryColor;

  @override
  State<MonetizationStatusCard> createState() => _MonetizationStatusCardState();
}

class _MonetizationStatusCardState extends State<MonetizationStatusCard> {
  Timer? _countdownTimer;
  Duration _countdown = Duration.zero;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startMidnightCountdown() {
    _countdownTimer?.cancel();
    void tick() {
      if (!mounted) return;
      final d = MonetizationService.getTimeUntilMidnight();
      setState(() => _countdown = d);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      tick();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    });
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  static bool _isSameCalendarDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatCountdown(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  bool get _light => widget.style == MonetizationCardStyle.elevatedLight;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return _wrap(
        child: Text(
          'Sign in to see your plan',
          style: TextStyle(
            color: _light ? const Color(0xFF424242) : Colors.white,
            fontSize: 14,
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        final doc = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting && doc == null) {
          return _wrap(
            child: SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _light ? widget.primaryColor : Colors.white,
              ),
            ),
          );
        }
        if (doc == null || !doc.exists) {
          return _wrap(
            child: SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _light ? widget.primaryColor : Colors.white,
              ),
            ),
          );
        }

        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return _wrap(child: const SizedBox.shrink());

        final now = DateTime.now();
        final planType = (data['planType'] ?? 'free').toString();
        final trialEndDate = _toDate(data['trialEndDate']);
        final premiumExpiry = _toDate(data['premiumExpiry']);

        final isPremium = planType == 'premium' && premiumExpiry != null && now.isBefore(premiumExpiry);
        final isTrial = planType == 'trial' && trialEndDate != null && now.isBefore(trialEndDate);

        if (isPremium) {
          _stopCountdown();
          final expStr =
              '${premiumExpiry.day} ${_months[premiumExpiry.month - 1]} ${premiumExpiry.year}';
          return _wrap(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Premium — unlimited AI',
                  style: _titleStyle(),
                ),
                if (expStr.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Renews / valid until $expStr',
                    style: _subStyle(),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  'Daily streak window resets in ${_formatCountdown(MonetizationService.getTimeUntilMidnight())}',
                  style: _hintStyle(),
                ),
              ],
            ),
          );
        }

        if (isTrial) {
          _stopCountdown();
          final daysLeft = trialEndDate.difference(now).inDays.clamp(0, MonetizationConfig.trialDaysCount);
          return _wrap(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Trial — unlimited AI', style: _titleStyle()),
                const SizedBox(height: 4),
                Text('$daysLeft days left in trial', style: _subStyle()),
                const SizedBox(height: 10),
                Text(
                  'Resets in ${_formatCountdown(MonetizationService.getTimeUntilMidnight())}',
                  style: _hintStyle(),
                ),
              ],
            ),
          );
        }

        final resetDate = _toDate(data['dailyResetDate']);
        int count = (data['dailyUsedCount'] is int) ? data['dailyUsedCount'] as int : 0;
        if (!_isSameCalendarDay(resetDate, now)) count = 0;
        count = count.clamp(0, MonetizationConfig.dailyFreeUsesLimit);
        final remaining =
            (MonetizationConfig.dailyFreeUsesLimit - count).clamp(0, MonetizationConfig.dailyFreeUsesLimit);
        final limit = MonetizationConfig.dailyFreeUsesLimit;
        _startMidnightCountdown();
        final displayCountdown = _countdown.inSeconds > 0 ? _countdown : MonetizationService.getTimeUntilMidnight();

        final usedFraction = limit > 0 ? (count / limit).clamp(0.0, 1.0) : 0.0;

        return _wrap(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$remaining / $limit uses left today',
                style: _titleStyle(),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: usedFraction,
                  minHeight: 8,
                  backgroundColor: _light ? const Color(0xFFF0EDFF) : Colors.white.withValues(alpha: 0.25),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _light ? widget.primaryColor : Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Next reset in ${_formatCountdown(displayCountdown)}',
                style: _subStyle(),
              ),
              if (remaining == 0) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: widget.onGoToPremium ?? () => Navigator.pushNamed(context, '/premium'),
                    icon: const Icon(Icons.workspace_premium, size: 18),
                    label: const Text('Go premium'),
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  TextStyle _titleStyle() {
    return TextStyle(
      color: _light ? const Color(0xFF1A1A1A) : Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    );
  }

  TextStyle _subStyle() {
    return TextStyle(
      color: _light ? const Color(0xFF616161) : Colors.white.withValues(alpha: 0.92),
      fontSize: 13,
      fontWeight: FontWeight.w500,
    );
  }

  TextStyle _hintStyle() {
    return TextStyle(
      color: _light ? const Color(0xFF757575) : Colors.white.withValues(alpha: 0.85),
      fontSize: 12,
    );
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  Widget _wrap({required Widget child}) {
    if (widget.style == MonetizationCardStyle.elevatedLight) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: widget.primaryColor.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: child,
    );
  }
}

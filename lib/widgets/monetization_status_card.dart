import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/monetization_config.dart';
import '../services/monetization_service.dart';

/// Home usage card: planType, trialEndDate, premiumExpiry, dailyUsedCount, dailyResetDate.
/// Countdown = time until midnight (00:00). Timer.periodic(1s).
class MonetizationStatusCard extends StatefulWidget {
  const MonetizationStatusCard({super.key, this.onGoToPremium});

  final VoidCallback? onGoToPremium;

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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return _buildCard(child: const Text('Sign in to see your plan', style: TextStyle(color: Colors.white, fontSize: 14)));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildCard(
            child: const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) return _buildCard(child: const SizedBox.shrink());

        final now = DateTime.now();
        final planType = (data['planType'] ?? 'free').toString();
        final trialEndDate = _toDate(data['trialEndDate']);
        final premiumExpiry = _toDate(data['premiumExpiry']);

        final isPremium = planType == 'premium' && premiumExpiry != null && now.isBefore(premiumExpiry);
        final isTrial = planType == 'trial' && trialEndDate != null && now.isBefore(trialEndDate);

        if (isPremium) {
          _stopCountdown();
          final expStr = premiumExpiry != null ? '${premiumExpiry.day} ${_months[premiumExpiry.month - 1]} ${premiumExpiry.year}' : '';
          return _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Unlimited', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                if (expStr.isNotEmpty) Text('Premium until $expStr', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
                const SizedBox(height: 6),
                Text('Resets at midnight — ${_formatCountdown(MonetizationService.getTimeUntilMidnight())}', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11)),
              ],
            ),
          );
        }

        if (isTrial) {
          _stopCountdown();
          final daysLeft = trialEndDate!.difference(now).inDays.clamp(0, MonetizationConfig.trialDaysCount);
          return _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Trial Unlimited', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                Text('$daysLeft days left', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
                const SizedBox(height: 6),
                Text('Resets at midnight — ${_formatCountdown(MonetizationService.getTimeUntilMidnight())}', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11)),
              ],
            ),
          );
        }

        final resetDate = _toDate(data['dailyResetDate']);
        int count = (data['dailyUsedCount'] is int) ? data['dailyUsedCount'] as int : 0;
        if (!_isSameCalendarDay(resetDate, now)) count = 0;
        count = count.clamp(0, MonetizationConfig.dailyFreeUsesLimit);
        final remaining = (MonetizationConfig.dailyFreeUsesLimit - count).clamp(0, MonetizationConfig.dailyFreeUsesLimit);
        _startMidnightCountdown();
        final displayCountdown = _countdown.inSeconds > 0 ? _countdown : MonetizationService.getTimeUntilMidnight();

        return _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$remaining / ${MonetizationConfig.dailyFreeUsesLimit} uses left today', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('Next reset at midnight — ${_formatCountdown(displayCountdown)}', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
              if (remaining == 0) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: widget.onGoToPremium ?? () => Navigator.pushNamed(context, '/premium'),
                  icon: const Icon(Icons.workspace_premium, color: Colors.white, size: 18),
                  label: const Text('Go To Premium', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.2), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: child,
    );
  }
}

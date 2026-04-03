import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/premium_service.dart';

/// Subscription badge widget - Shows Premium or Trial status
class SubscriptionBadge extends StatelessWidget {
  final UserModel user;
  final double? fontSize;
  final EdgeInsets? padding;

  const SubscriptionBadge({
    super.key,
    required this.user,
    this.fontSize,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    // Premium user badge
    if (PremiumService.isPremium(user)) {
      return Container(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7B2CBF).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.workspace_premium,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              'Premium',
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize ?? 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }
    
    // Trial user badge
    if (PremiumService.isTrial(user) && user.trialEnd != null) {
      final now = DateTime.now();
      final daysLeft = user.trialEnd!.difference(now).inDays;
      
      if (daysLeft >= 0) {
        return Container(
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.orange.shade300,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer_outlined,
                size: 16,
                color: Colors.orange.shade700,
              ),
              const SizedBox(width: 6),
              Text(
                daysLeft == 0 
                    ? 'Trial ends today'
                    : daysLeft == 1
                        ? 'Trial - 1 day left'
                        : 'Trial - $daysLeft days left',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontSize: fontSize ?? 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        );
      }
    }
    
    // Free user (trial expired) - no badge
    return const SizedBox.shrink();
  }
}


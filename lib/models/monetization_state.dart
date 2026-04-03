/// Real-time monetization state derived from Firestore users/{uid}.
class MonetizationState {
  const MonetizationState({
    required this.isTrialActive,
    required this.trialDaysLeft,
    required this.isPremiumActive,
    required this.freeUsesLeftToday,
    required this.dailyLimit,
    required this.nextResetAt,
    required this.canUseAi,
    required this.statusMessage,
    this.trialEndDate,
    this.premiumExpiry,
  });

  final bool isTrialActive;
  final int trialDaysLeft;
  final bool isPremiumActive;
  final int freeUsesLeftToday;
  final int dailyLimit;
  final DateTime? nextResetAt;
  final bool canUseAi;
  final String statusMessage;
  final DateTime? trialEndDate;
  final DateTime? premiumExpiry;

  /// Duration until next reset (for countdown). Null if no reset (trial/premium active).
  Duration? get timeUntilReset {
    if (nextResetAt == null) return null;
    final now = DateTime.now();
    if (now.isAfter(nextResetAt!)) return Duration.zero;
    return nextResetAt!.difference(now);
  }

  bool get isFreeUser => !isTrialActive && !isPremiumActive;
  bool get showCountdown => isFreeUser && nextResetAt != null;
  bool get showGoToPremium => isFreeUser && !canUseAi;
}

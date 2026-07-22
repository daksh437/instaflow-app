import 'package:flutter/material.dart';
import '../services/ai_usage_control_service.dart';

// ─── Reusable plan badges (use anywhere with raw values or [AiAccessState]) ───

/// Trial: "X days left". Use when [planType] == trial and [daysLeft] > 0.
class TrialBadge extends StatelessWidget {
  const TrialBadge({super.key, required this.daysLeft, this.style, this.padding});
  final int daysLeft;
  final TextStyle? style;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveStyle = style ?? theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.tertiary,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('Free Trial — $daysLeft days left', style: effectiveStyle),
      ),
    );
  }
}

/// Free plan: "X credits left today".
class CreditsLeftBadge extends StatelessWidget {
  const CreditsLeftBadge({super.key, required this.creditsLeft, this.dailyLimit, this.style, this.padding});
  final int creditsLeft;
  final int? dailyLimit;
  final TextStyle? style;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveStyle = style ?? theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('Credits left today: $creditsLeft${dailyLimit != null ? ' / $dailyLimit' : ''}', style: effectiveStyle),
      ),
    );
  }
}

/// Premium: "Premium — unlimited" label.
class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key, this.style, this.padding});
  final TextStyle? style;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveStyle = style ?? theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.secondary,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('Premium — unlimited', style: effectiveStyle),
      ),
    );
  }
}

/// Picks [TrialBadge], [CreditsLeftBadge], or [PremiumBadge] from [AiAccessState].
class PlanBadgeFromState extends StatelessWidget {
  const PlanBadgeFromState({super.key, required this.state, this.style, this.padding});
  final AiAccessState? state;
  final TextStyle? style;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final s = state;
    if (s == null) return const SizedBox.shrink();
    if (s.isPremium) return PremiumBadge(style: style, padding: padding);
    if (s.isTrial) {
      return TrialBadge(
        daysLeft: s.trialDaysLeft > 0 ? s.trialDaysLeft : 0,
        style: style,
        padding: padding,
      );
    }
    // Free only: show badgeLabel ("Free Plan — X / 2 used today"). Trial/premium never see this.
    final theme = Theme.of(context);
    final effectiveStyle = style ?? theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(s.badgeLabel, style: effectiveStyle),
      ),
    );
  }
}

/// Shows trial days left or credits left today. Use with [AiUsageControlService].
class AiCreditBadge extends StatelessWidget {
  const AiCreditBadge({
    super.key,
    required this.state,
    this.style,
    this.padding,
  });

  final AiAccessState? state;
  final TextStyle? style;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final s = state;
    if (s == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final effectiveStyle = style ?? theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w500,
    );
    final isBlocked = s.showLimitBanner;
    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isBlocked
              ? theme.colorScheme.errorContainer.withValues(alpha: 0.5)
              : theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          s.badgeLabel,
          style: effectiveStyle?.copyWith(
            color: isBlocked ? theme.colorScheme.onErrorContainer : theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}

/// Banner for free limit: hidden. Upgrade dialog only when user taps Generate (runWithBackendAiGuard).
/// No visible "limit reached" or "Today's free uses complete" banner in UI.
class AiFreeLimitBanner extends StatelessWidget {
  const AiFreeLimitBanner({super.key, required this.state, this.onUpgrade});

  final AiAccessState? state;
  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context) {
    // Do not show limit banner — only upgrade dialog when free user hits limit and taps Generate
    return const SizedBox.shrink();
  }
}

/// [ValueListenableBuilder] that refreshes [AiUsageControlService] and shows [AiCreditBadge].
class AiCreditBadgeLive extends StatefulWidget {
  const AiCreditBadgeLive({
    super.key,
    this.service,
    this.style,
    this.padding,
  });

  final AiUsageControlService? service;
  final TextStyle? style;
  final EdgeInsetsGeometry? padding;

  @override
  State<AiCreditBadgeLive> createState() => _AiCreditBadgeLiveState();
}

class _AiCreditBadgeLiveState extends State<AiCreditBadgeLive> {
  late final AiUsageControlService _service;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AiUsageControlService.instance;
    _service.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AiAccessState?>(
      valueListenable: _service.state,
      builder: (context, state, _) {
        return AiCreditBadge(
          state: state,
          style: widget.style,
          padding: widget.padding,
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import '../services/ai_usage_control_service.dart';

/// Single card for home screen: Trial / Free / Premium. Uses ONLY [AiUsageControlService.instance.currentState].
/// Trial: only "Free Trial — X days left". No daily credits, no "Free Plan", no countdown, no limit reached.
/// Free: show daily credits UI and countdown when limit reached. Premium: unlimited only.
class HomePlanCard extends StatelessWidget {
  const HomePlanCard({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AiAccessState?>(
      valueListenable: AiUsageControlService.instance.state,
      builder: (context, state, _) {
        if (state == null) return const SizedBox.shrink();
        return _buildCard(context, state);
      },
    );
  }

  Widget _buildCard(BuildContext context, AiAccessState state) {
    final containerDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.4),
        width: 1,
      ),
    );

    if (state.planType == 'trial') {
      return GestureDetector(
        onTap: onTap ?? () => Navigator.pushNamed(context, '/premium'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: containerDecoration.copyWith(
            color: Colors.white.withValues(alpha: 0.25),
          ),
          child: Text(
            'Free Trial — ${state.trialDaysLeft} days left',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    if (state.planType == 'premium') {
      return GestureDetector(
        onTap: onTap ?? () => Navigator.pushNamed(context, '/premium'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: containerDecoration.copyWith(
            color: const Color(0xFF7B2CBF).withValues(alpha: 0.2),
          ),
          child: const Text(
            'Premium — Unlimited',
            style: TextStyle(
              color: Color(0xFF7B2CBF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    if (state.planType == 'free') {
      final limit = state.dailyLimit;
      return GestureDetector(
        onTap: onTap ?? () => Navigator.pushNamed(context, '/premium'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: containerDecoration.copyWith(
            color: Colors.white.withValues(alpha: 0.2),
          ),
          child: Text(
            limit != null ? '${state.remainingCredits} / $limit' : 'Free Plan',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

/// Refreshes [AiUsageControlService.instance] and shows [HomePlanCard] (which uses instance.currentState).
class HomePlanCardLive extends StatefulWidget {
  const HomePlanCardLive({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  State<HomePlanCardLive> createState() => _HomePlanCardLiveState();
}

class _HomePlanCardLiveState extends State<HomePlanCardLive> {
  @override
  void initState() {
    super.initState();
    AiUsageControlService.instance.refresh(force: true);
  }

  @override
  Widget build(BuildContext context) {
    return HomePlanCard(onTap: widget.onTap);
  }
}

import 'package:flutter/material.dart';

class StepProgress extends StatelessWidget {
  const StepProgress({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF25D366);
    final safeTotal = totalSteps <= 0 ? 1 : totalSteps;
    final safeCurrent = currentStep.clamp(1, safeTotal);

    return Row(
      children: List.generate(safeTotal, (i) {
        final idx = i + 1;
        final isDone = idx < safeCurrent;
        final isActive = idx == safeCurrent;

        return Expanded(
          child: Container(
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: isActive
                  ? accent.withOpacity(0.95)
                  : isDone
                      ? accent.withOpacity(0.45)
                      : Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }),
    );
  }
}


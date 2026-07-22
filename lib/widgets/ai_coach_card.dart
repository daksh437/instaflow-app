import 'package:flutter/material.dart';
import '../models/ai_advice_model.dart';

class AiCoachCard extends StatelessWidget {
  const AiCoachCard({
    super.key,
    required this.advice,
    this.onApply,
  });

  final AiAdviceModel advice;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F4FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD6C7F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_alt_rounded, color: Color(0xFF7B2CBF)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'AI Coach Suggestion',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3C1361),
                  ),
                ),
              ),
              if (onApply != null)
                TextButton(
                  onPressed: onApply,
                  child: const Text('Apply this'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _line('Why this matters', advice.whyItMatters),
          const SizedBox(height: 6),
          _line('Diagnosis', advice.diagnosis),
          const SizedBox(height: 8),
          const Text(
            'Do this now',
            style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF3C1361)),
          ),
          const SizedBox(height: 4),
          ...advice.actionSteps.take(5).map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text('• $s', style: const TextStyle(fontSize: 13)),
                ),
              ),
          const SizedBox(height: 8),
          _line('Expected result', advice.expectedOutcome),
          const SizedBox(height: 6),
          _line('Avoid this', advice.avoidThis),
          const SizedBox(height: 6),
          _line('Confidence', advice.confidenceNote),
          if (advice.quickWin.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE3D8FA)),
              ),
              child: Text(
                'Quick win: ${advice.quickWin}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(String title, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$title: ',
            style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF3C1361)),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(color: Color(0xFF2A2A2A)),
          ),
        ],
      ),
    );
  }
}

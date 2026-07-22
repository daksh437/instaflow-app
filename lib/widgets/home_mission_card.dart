import 'package:flutter/material.dart';
import '../models/daily_mission_model.dart';

/// Streak / mission card. Optional circular progress when [showProgressRing] is true.
class HomeMissionCard extends StatelessWidget {
  const HomeMissionCard({
    super.key,
    required this.mission,
    required this.onCompleteTask,
    this.showProgressRing = false,
    this.primaryColor = const Color(0xFF7B61FF),
  });

  final DailyMissionModel mission;
  final Future<void> Function(String taskType) onCompleteTask;
  final bool showProgressRing;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    final total = mission.tasks.length;
    final progress =
        total > 0 ? (mission.completedCount / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 10),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryColor,
                        primaryColor.withValues(alpha: 0.75),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.flag_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'This week\'s mission',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          letterSpacing: -0.35,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${mission.completedCount} of $total tasks done',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showProgressRing && total > 0)
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 4,
                            backgroundColor: const Color(0xFFF0EDFF),
                            color: primaryColor,
                          ),
                        ),
                        Text(
                          '${(progress * 100).round()}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (total > 0) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  Text(
                    '${mission.completedCount}/$total',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 9,
                  backgroundColor: const Color(0xFFF0EDFF),
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              ),
            ],
            const SizedBox(height: 14),
            ...mission.tasks.map((t) {
              return CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: t.completed,
                onChanged: t.completed ? null : (_) => onCompleteTask(t.type),
                title: Text(_labelFor(t.type),
                    style: const TextStyle(fontSize: 14)),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: primaryColor,
              );
            }),
            if (mission.isCompleted)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.celebration_rounded,
                        color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mission complete — streak reward granted.',
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _labelFor(String type) {
    switch (type) {
      case 'caption_generate':
        return 'Generate 1 caption';
      case 'hashtag_generate':
        return 'Generate hashtags';
      case 'calendar_generate':
        return 'Create 1 calendar day';
      default:
        return type;
    }
  }
}

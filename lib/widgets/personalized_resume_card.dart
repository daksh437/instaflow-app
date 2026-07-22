import 'package:flutter/material.dart';

/// "Continue where you left off" — retention recommendations.
class PersonalizedResumeCard extends StatelessWidget {
  const PersonalizedResumeCard({
    super.key,
    required this.data,
    required this.onOpen,
    this.primaryColor = const Color(0xFF7B61FF),
    this.accentPink = const Color(0xFFFF7AD9),
  });

  final Map<String, dynamic> data;
  final VoidCallback onOpen;
  final Color primaryColor;
  final Color accentPink;

  static const double _radius = 20.0;

  String _prettyTool(String raw) {
    switch (raw) {
      case 'ai_captions':
        return 'AI Captions';
      case 'ai_calendar':
        return 'AI Calendar';
      case 'hashtags':
        return 'Hashtags';
      case 'ai_strategy':
        return 'Growth Strategy';
      case 'niche_analysis':
        return 'Niche Analysis';
      default:
        return raw.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cwl = (data['continueWhereLeft'] as Map<String, dynamic>? ?? {});
    final tool = (cwl['tool'] ?? 'ai_captions').toString();
    final snippet = (cwl['inputSnippet'] ?? '').toString();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(_radius),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor.withValues(alpha: 0.55),
                accentPink.withValues(alpha: 0.45),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 12),
                spreadRadius: -4,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(1.5),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_radius - 1.5),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(17),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          primaryColor.withValues(alpha: 0.16),
                          accentPink.withValues(alpha: 0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.18),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(Icons.play_circle_fill_rounded,
                        color: primaryColor, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Continue where you left off',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600,
                            letterSpacing: 0.35,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _prettyTool(tool),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A1A),
                            letterSpacing: -0.35,
                          ),
                        ),
                        if (snippet.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            snippet,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          primaryColor.withValues(alpha: 0.12),
                          accentPink.withValues(alpha: 0.1),
                        ],
                      ),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: primaryColor,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

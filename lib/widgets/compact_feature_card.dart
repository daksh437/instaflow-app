import 'package:flutter/material.dart';

/// Reusable compact feature card widget
/// All home screen boxes use this unified design style
class CompactFeatureCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final Gradient gradient;
  final VoidCallback? onTap;
  final AnimationController? animationController;
  final bool isComingSoon;

  const CompactFeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.gradient,
    this.onTap,
    this.animationController,
    this.isComingSoon = false,
  });

  @override
  State<CompactFeatureCard> createState() => _CompactFeatureCardState();
}

class _CompactFeatureCardState extends State<CompactFeatureCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _localController;

  @override
  void initState() {
    super.initState();
    _localController = widget.animationController ??
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 150),
        );
  }

  @override
  void dispose() {
    if (widget.animationController == null) {
      _localController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => _localController.forward() : null,
      onTapUp: widget.onTap != null
          ? (_) {
              _localController.reverse();
              widget.onTap?.call();
            }
          : null,
      onTapCancel: widget.onTap != null ? () => _localController.reverse() : null,
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.96).animate(
          CurvedAnimation(
            parent: _localController,
            curve: Curves.easeInOut,
          ),
        ),
        child: Container(
          height: 110,
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFCC99FF).withOpacity(0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7B2CBF).withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon centered at top
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.icon,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 10),
                // Title centered below icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.isComingSoon) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Soon',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


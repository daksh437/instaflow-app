import 'dart:async';
import 'package:flutter/material.dart';

/// Live countdown to [resetAtUtc] (ISO string, e.g. next midnight UTC).
/// Updates every second. Use on home and AI screens when free plan limit is reached.
class AiPlanCountdown extends StatefulWidget {
  const AiPlanCountdown({
    super.key,
    required this.resetAtUtc,
    this.style,
    this.prefix = 'Resets in ',
  });

  final String? resetAtUtc;
  final TextStyle? style;
  final String prefix;

  @override
  State<AiPlanCountdown> createState() => _AiPlanCountdownState();
}

class _AiPlanCountdownState extends State<AiPlanCountdown> {
  Timer? _timer;
  String _text = '';

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  @override
  void didUpdateWidget(AiPlanCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetAtUtc != widget.resetAtUtc) _update();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _update() {
    final resetAt = widget.resetAtUtc;
    if (resetAt == null || resetAt.isEmpty) {
      if (_text.isNotEmpty) setState(() => _text = '');
      return;
    }
    DateTime? target;
    try {
      target = DateTime.parse(resetAt);
    } catch (_) {
      if (_text != '—') setState(() => _text = '—');
      return;
    }
    final now = DateTime.now().toUtc();
    final diff = target.difference(now);
    if (diff.isNegative) {
      if (_text != 'Soon') setState(() => _text = 'Soon');
      return;
    }
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    final s = diff.inSeconds % 60;
    final next = '${widget.prefix}${h}h ${m}m ${s}s';
    if (next != _text) setState(() => _text = next);
  }

  @override
  Widget build(BuildContext context) {
    if (_text.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final effectiveStyle = widget.style ??
        theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        );
    return Text(_text, style: effectiveStyle);
  }
}

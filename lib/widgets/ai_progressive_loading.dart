import 'dart:async';
import 'package:flutter/material.dart';

/// Progressive loading content: cycles messages + progress bar.
/// Use with min display of 1.5s at call site for perceived speed boost.
class AiProgressiveLoading extends StatefulWidget {
  final List<String> messages;
  final bool showProgressBar;
  final Color? accentColor;

  const AiProgressiveLoading({
    super.key,
    List<String>? messages,
    this.showProgressBar = true,
    this.accentColor,
  }) : messages = messages ?? const ['Analyzing…', 'Generating…', 'Optimizing output…'];

  @override
  State<AiProgressiveLoading> createState() => _AiProgressiveLoadingState();
}

class _AiProgressiveLoadingState extends State<AiProgressiveLoading> {
  Timer? _messageTimer;
  int _messageIndex = 0;

  @override
  void initState() {
    super.initState();
    _messageTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (mounted && widget.messages.isNotEmpty) {
        setState(() {
          _messageIndex = (_messageIndex + 1) % widget.messages.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.accentColor ?? const Color(0xFF7B2CBF);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showProgressBar) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: null,
              backgroundColor: color.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 16),
        ],
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            widget.messages[_messageIndex],
            key: ValueKey(_messageIndex),
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

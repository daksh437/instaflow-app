import 'package:flutter/material.dart';
import 'ai_progressive_loading.dart';
import 'skeleton_loader.dart';

class AiSuggestionChip {
  const AiSuggestionChip({required this.label, required this.text});
  final String label;
  final String text;
}

class AiInputCard extends StatelessWidget {
  const AiInputCard({
    super.key,
    required this.controller,
    required this.hintText,
    this.quickIdeas = const [],
    this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final List<AiSuggestionChip> quickIdeas;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B2CBF).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: hintText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF7B2CBF), width: 2),
              ),
              filled: true,
              fillColor: const Color(0xFFF8F6FF),
              contentPadding: const EdgeInsets.all(16),
            ),
            onChanged: onChanged,
          ),
          if (quickIdeas.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Suggestion chips',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: quickIdeas.map((idea) {
                return ActionChip(
                  label: Text(idea.label),
                  backgroundColor: const Color(0xFFF2ECFF),
                  side: BorderSide(color: Colors.grey.shade300),
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4A148C),
                    fontWeight: FontWeight.w600,
                  ),
                  onPressed: () {
                    controller.text = idea.text;
                    onChanged?.call(idea.text);
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class AiTapScale extends StatefulWidget {
  const AiTapScale({super.key, required this.child});
  final Widget child;

  @override
  State<AiTapScale> createState() => _AiTapScaleState();
}

class _AiTapScaleState extends State<AiTapScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class AiLoadingState extends StatelessWidget {
  const AiLoadingState({
    super.key,
    this.messages = const [
      'Analyzing your input...',
      'Generating high-quality output...',
      'Optimizing for engagement...',
    ],
  });

  final List<String> messages;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF7B2CBF).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const CardSkeleton(),
          const SizedBox(height: 16),
          AiProgressiveLoading(
            messages: messages,
            accentColor: const Color(0xFF7B2CBF),
          ),
        ],
      ),
    );
  }
}

class AiActionBar extends StatelessWidget {
  const AiActionBar({
    super.key,
    required this.onCopy,
    this.onSave,
    this.onRegenerate,
    this.onSchedule,
    this.onShare,
  });

  final VoidCallback onCopy;
  final VoidCallback? onSave;
  final VoidCallback? onRegenerate;
  final VoidCallback? onSchedule;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    Widget buildBtn(IconData icon, String label, VoidCallback? onPressed) {
      if (onPressed == null) return const SizedBox.shrink();
      return Expanded(
        child: AiTapScale(
          child: OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 16),
            label: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF7B2CBF),
              side: BorderSide(color: const Color(0xFF7B2CBF).withValues(alpha: 0.35)),
            ),
          ),
        ),
      );
    }

    final buttons = <Widget>[
      buildBtn(Icons.copy, 'Copy', onCopy),
      buildBtn(Icons.bookmark_add_outlined, 'Save', onSave),
      buildBtn(Icons.refresh, 'Regenerate', onRegenerate),
      buildBtn(Icons.schedule, 'Schedule', onSchedule),
      buildBtn(Icons.share, 'Share', onShare),
    ].where((w) => w is! SizedBox).toList();

    return Row(
      children: [
        for (int i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          buttons[i],
        ]
      ],
    );
  }
}

class AiEmptyState extends StatelessWidget {
  const AiEmptyState({
    super.key,
    this.title = 'Ready to generate',
    this.subtitle = 'Enter your input and run AI to see premium results here.',
    this.icon = Icons.auto_awesome_rounded,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF7B2CBF).withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF7B2CBF), size: 30),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

class AiResultCard extends StatelessWidget {
  const AiResultCard({
    super.key,
    required this.title,
    required this.mainResult,
    this.supporting = const [],
    this.actions,
  });

  final String title;
  final String mainResult;
  final List<String> supporting;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF7B2CBF).withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            mainResult,
            style: const TextStyle(
              fontSize: 15,
              height: 1.55,
              color: Color(0xFF1A1A1A),
            ),
          ),
          if (supporting.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...supporting.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $line', style: const TextStyle(fontSize: 13)),
              ),
            ),
          ],
          if (actions != null) ...[
            const SizedBox(height: 12),
            actions!,
          ],
        ],
      ),
    );
  }
}

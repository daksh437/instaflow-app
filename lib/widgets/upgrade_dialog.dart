import 'package:flutter/material.dart';

/// Full-screen upgrade popup / dialog. Use for "daily limit reached" or "trial expired".
/// Optional "Watch ad for +1 use" when [showWatchAdButton] is true and [onWatchAd] is set.
class UpgradeDialog extends StatelessWidget {
  const UpgradeDialog({
    super.key,
    required this.title,
    required this.message,
    this.primaryActionLabel = 'Upgrade',
    this.onUpgrade,
    this.onDismiss,
    this.showWatchAdButton = false,
    this.onWatchAd,
  });

  final String title;
  final String message;
  final String primaryActionLabel;
  final VoidCallback? onUpgrade;
  final VoidCallback? onDismiss;
  final bool showWatchAdButton;
  final Future<void> Function(BuildContext context)? onWatchAd;

  /// Show as a dialog (modal).
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    String primaryActionLabel = 'Upgrade',
    VoidCallback? onUpgrade,
    VoidCallback? onDismiss,
    bool showWatchAdButton = false,
    Future<void> Function(BuildContext context)? onWatchAd,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpgradeDialog(
        title: title,
        message: message,
        primaryActionLabel: primaryActionLabel,
        onUpgrade: onUpgrade,
        onDismiss: onDismiss,
        showWatchAdButton: showWatchAdButton,
        onWatchAd: onWatchAd,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.workspace_premium, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (showWatchAdButton && onWatchAd != null) ...[
              OutlinedButton.icon(
                onPressed: () async {
                  await onWatchAd!(context);
                },
                icon: const Icon(Icons.play_circle_outline, size: 20),
                label: const Text('Watch ad for +1 use today'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7B2CBF),
                  side: const BorderSide(color: Color(0xFF7B2CBF)),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (onDismiss != null)
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onDismiss?.call();
                    },
                    child: const Text('Not now'),
                  ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onUpgrade?.call();
                    Navigator.of(context).pushNamed('/premium');
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7B2CBF),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(primaryActionLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

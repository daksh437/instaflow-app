import 'package:flutter/material.dart';

// TODO: Enable after OAuth + verification complete — wire to /auth/google + Firestore tokens.

/// Placeholder for `/google-calendar` — feature gated until backend verification.
class GoogleCalendarComingSoonScreen extends StatelessWidget {
  const GoogleCalendarComingSoonScreen({super.key});

  static void showComingSoonDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Coming Soon'),
        content: const Text(
          "We're working on Google Calendar auto scheduling. Stay tuned!",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static void showComingSoonSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Google Calendar integration is coming soon 🚀'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Google Calendar')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded,
                  size: 56, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Coming Soon',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                "We're working on Google Calendar auto scheduling. Stay tuned!",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

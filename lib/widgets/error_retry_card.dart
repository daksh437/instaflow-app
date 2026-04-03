import 'package:flutter/material.dart';
import '../utils/app_error_handler.dart';

/// Production-safe error UI for FutureBuilder/StreamBuilder: friendly message + retry.
/// Never shows raw error text to user.
class ErrorRetryCard extends StatelessWidget {
  const ErrorRetryCard({
    super.key,
    required this.onRetry,
    this.error,
    this.message,
  });

  final VoidCallback onRetry;
  final dynamic error;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final friendly = message ?? AppErrorHandler.getFriendlyMessage(error);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[700]),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              friendly,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

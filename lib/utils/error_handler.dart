import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'app_error_handler.dart';

/// Centralized error handling — delegates to AppErrorHandler for production-safe errors.
class ErrorHandler {
  /// Get user-friendly error message (never raw/backend). Delegates to AppErrorHandler.
  static String getUserFriendlyMessage(dynamic error) {
    return AppErrorHandler.getFriendlyMessage(error);
  }

  /// Show error snackbar (friendly message only). Delegates to AppErrorHandler.
  static void showError(BuildContext context, dynamic error, {Duration? duration}) {
    if (!context.mounted) return;
    AppErrorHandler.show(context, error, duration: duration);
  }

  /// Show success snackbar
  static void showSuccess(BuildContext context, String message, {Duration? duration}) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }

  /// Show info snackbar
  static void showInfo(BuildContext context, String message, {Duration? duration}) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue[700],
        behavior: SnackBarBehavior.floating,
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }

  /// Log error (Crashlytics + debug). Delegates to AppErrorHandler.
  static void logError(String context, dynamic error, [StackTrace? stackTrace]) {
    AppErrorHandler.log(context, error, stackTrace);
  }
}


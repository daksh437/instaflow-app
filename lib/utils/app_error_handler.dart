import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Production-safe error handling: Crashlytics log, friendly user messages, guard wrapper.
/// Never show raw backend or Firestore permission errors to users.
class AppErrorHandler {
  AppErrorHandler._();

  /// User-visible message only. Firestore permission-denied and raw errors never exposed.
  static String getFriendlyMessage(dynamic error) {
    if (error == null) return 'Something went wrong. Please try again.';
    final s = error.toString().toLowerCase();

    // Firestore / permission — never show "permission-denied" or backend text
    if (s.contains('permission-denied') ||
        s.contains('permission_denied') ||
        s.contains('firestore') && s.contains('permission')) {
      return 'Unable to complete. Please try again or sign in again.';
    }

    // Network
    if (s.contains('network') ||
        s.contains('socket') ||
        s.contains('connection') ||
        s.contains('timeout')) {
      return 'No internet connection. Please check your network and try again.';
    }

    // AI / API
    if (s.contains('unavailable') ||
        s.contains('server error') ||
        s.contains('api') ||
        s.contains('failed to fetch')) {
      return 'Service temporarily unavailable. Please try again in a moment.';
    }

    // Auth
    if (s.contains('auth') || s.contains('unauthorized') || s.contains('sign-in')) {
      return 'Please sign in again to continue.';
    }

    // Billing / purchase
    if (s.contains('billing') || s.contains('purchase') || s.contains('payment')) {
      if (s.contains('cancel')) return 'Purchase was cancelled.';
      if (s.contains('not available')) return 'Store is not available. Try again later.';
      return 'Purchase failed. Please try again or contact support.';
    }

    // Image / photo
    if (s.contains('image') || s.contains('photo')) {
      return 'Image error. Please try a different image.';
    }

    return 'Something went wrong. Please try again.';
  }

  /// Log to Crashlytics (and debug in debug mode only). Never exposes to UI.
  static Future<void> log(String context, dynamic error, [StackTrace? stackTrace]) async {
    if (kDebugMode) {
      debugPrint('[$context] $error');
      if (stackTrace != null) debugPrint(stackTrace.toString());
    }
    try {
      await FirebaseCrashlytics.instance.recordError(
        error is Exception ? error : Exception(error.toString()),
        stackTrace,
        reason: context,
        fatal: false,
      );
    } catch (_) {}
  }

  /// Safe snackbar: shows only getFriendlyMessage. Use when BuildContext is available.
  static void show(BuildContext context, dynamic error, {Duration? duration}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                getFriendlyMessage(error),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        duration: duration ?? const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            if (context.mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Run [fn]; on exception: log to Crashlytics, optionally show snackbar if [context] provided.
  /// Returns result or null on error.
  static Future<T?> guard<T>(
    Future<T> Function() fn, {
    BuildContext? context,
    String logContext = 'guard',
  }) async {
    try {
      return await fn();
    } catch (e, st) {
      await log(logContext, e, st);
      if (context != null && context.mounted) show(context, e);
      return null;
    }
  }
}

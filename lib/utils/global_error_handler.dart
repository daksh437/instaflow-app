import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Production-safe: never show raw backend errors to users.
/// Maps: cloud_firestore, permission-denied, billing errors → friendly messages.
/// Logs real error in debugPrint only (and Crashlytics).
class GlobalErrorHandler {
  GlobalErrorHandler._();

  /// User-visible message only. Never expose Firestore/billing/backend text.
  static String getUserMessage(dynamic error) {
    if (error == null) return 'Something went wrong. Please try again.';
    final s = error.toString().toLowerCase();

    if (s.contains('permission-denied') ||
        s.contains('permission_denied') ||
        (s.contains('firestore') && s.contains('permission'))) {
      return 'Unable to complete. Please try again or sign in again.';
    }
    if (s.contains('network') || s.contains('socket') || s.contains('connection') || s.contains('timeout')) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (s.contains('unavailable') || s.contains('server error') || s.contains('failed to fetch')) {
      return 'Server busy. Please try again later.';
    }
    if (s.contains('auth') || s.contains('unauthorized') || s.contains('sign-in')) {
      return 'Please sign in again to continue.';
    }
    if (s.contains('billing') || s.contains('purchase') || s.contains('payment')) {
      if (s.contains('cancel')) return 'Purchase was cancelled.';
      if (s.contains('not available')) return 'Store is not available. Try again later.';
      return 'Purchase failed. Please try again or contact support.';
    }
    return 'Something went wrong. Please try again.';
  }

  /// Log to Crashlytics + debugPrint. Never show to user.
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

  /// Show SnackBar with getUserMessage only.
  static void showSnackBar(BuildContext context, dynamic error, {Duration? duration}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(getUserMessage(error)),
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

  /// Run [fn]; on exception: log, show snackbar if context provided, return null.
  static Future<T?> guard<T>(Future<T> Function() fn, {BuildContext? context, String logContext = 'guard'}) async {
    try {
      return await fn();
    } catch (e, st) {
      await log(logContext, e, st);
      if (context != null && context.mounted) showSnackBar(context, e);
      return null;
    }
  }
}

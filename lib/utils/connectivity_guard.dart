import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Global internet connectivity guard.
/// Call before AI calls, purchase, or restore; shows "Internet connection required" dialog if offline.
class ConnectivityGuard {
  static final Connectivity _connectivity = Connectivity();

  /// Returns true if device has a network connection (wifi, mobile, etc.); false if none.
  static Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// If offline: shows dialog "Internet connection required" and returns false.
  /// If online: returns true. Use before AI call, purchase, or restore.
  static Future<bool> ensureConnected(BuildContext context) async {
    if (await isConnected) return true;
    if (!context.mounted) return false;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Internet connection required'),
        content: const Text(
          'Please check your connection and try again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return false;
  }
}

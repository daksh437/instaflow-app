import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:insta_flow/config/admin_config.dart';

/// Admin check: user.email in admin list AND users/{uid}.isAdmin == true. Cached per session.
/// Only show admin panel if both pass; else hide route.
class AdminGuard {
  AdminGuard._();

  static final AdminGuard _instance = AdminGuard._();

  factory AdminGuard() => _instance;

  static bool? _cachedIsAdmin;
  static String? _cachedUid;

  /// Returns true if Firestore users/{uid}.isAdmin == true AND
  /// (admin list is empty OR user email is in admin list).
  /// Empty admin list = only Firestore isAdmin matters (set isAdmin: true in Firestore for your uid).
  Future<bool> isAdminUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _cachedIsAdmin = false;
      _cachedUid = null;
      return false;
    }
    if (_cachedUid == user.uid && _cachedIsAdmin != null) {
      return _cachedIsAdmin ?? false;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      final firestoreAdmin = data != null && (data['isAdmin'] == true);
      final emailAllowed = AdminConfig.adminEmails.isEmpty || AdminConfig.isAdminEmail(user.email);
      final isAdmin = firestoreAdmin && emailAllowed;
      _cachedIsAdmin = isAdmin;
      _cachedUid = user.uid;
      if (kDebugMode) {
        debugPrint('[AdminGuard] isAdminUser: $isAdmin (uid=${user.uid}, firestoreAdmin=$firestoreAdmin, emailAllowed=$emailAllowed)');
      }
      return isAdmin;
    } catch (e) {
      if (kDebugMode) debugPrint('[AdminGuard] isAdminUser error: $e');
      _cachedIsAdmin = false;
      _cachedUid = user.uid;
      return false;
    }
  }

  /// Clears the cached admin result (e.g. after logout or when testing).
  void clearCache() {
    _cachedIsAdmin = null;
    _cachedUid = null;
  }
}

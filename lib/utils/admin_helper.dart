import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Sets the current user's document to isAdmin = true.
/// Run once manually (e.g. from a debug screen or one-off script) to grant admin.
/// Requires the user to be signed in.
Future<void> makeCurrentUserAdmin() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    if (kDebugMode) debugPrint('[AdminHelper] makeCurrentUserAdmin: no user signed in');
    throw StateError('No user signed in');
  }
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({'isAdmin': true}, SetOptions(merge: true));
    if (kDebugMode) debugPrint('[AdminHelper] makeCurrentUserAdmin: set isAdmin=true for ${user.uid}');
  } catch (e) {
    if (kDebugMode) debugPrint('[AdminHelper] makeCurrentUserAdmin: $e');
    rethrow;
  }
}

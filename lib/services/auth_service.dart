import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/notification_service.dart';
import '../utils/admin_guard.dart';
import 'premium_service.dart';
import 'device_service.dart';
import 'monetization_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        await _ensureUserDocOnLogin(credential.user!);
        await DeviceService().bindDeviceAfterLogin(credential.user!.uid);
      }
      return credential;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential?> signUpWithEmailAndPassword(
    String email,
    String password,
    String? displayName,
  ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        if (displayName != null) {
          await credential.user!.updateDisplayName(displayName);
        }
        await _ensureUserDocOnLogin(credential.user!);
        await DeviceService().bindDeviceAfterLogin(credential.user!.uid);
      }

      return credential;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Configure GoogleSignIn with proper scopes
      // Use Web client ID from google-services.json (client_type: 3)
      // This is the OAuth 2.0 client ID for server-side authentication
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: [
          'email',
          'profile',
        ],
        serverClientId: '412053319604-4eerf9lfm4mjg3ijfp74tf5q0g0itbi6.apps.googleusercontent.com',
      );

      // Sign out first to clear any cached accounts
      await googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null; // User cancelled

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.idToken == null) {
        throw Exception('Failed to get ID token from Google. Please check Firebase Console configuration.');
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user != null) {
        await _ensureUserDocOnLogin(user);
        await DeviceService().bindDeviceAfterLogin(user.uid);
      }

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  static DateTime _midnightToday(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Called on every login. Creates user doc on first login with 7-day trial.
  /// Uses monetization fields: planType, trialEndDate, dailyUsedCount, dailyResetDate.
  Future<void> _ensureUserDocOnLogin(User user) async {
    final userDoc = _firestore.collection('users').doc(user.uid);
    final docSnapshot = await userDoc.get();

    final now = DateTime.now();
    final trialEndDate = now.add(const Duration(days: 7));
    final todayMidnight = _midnightToday(now);

    if (!docSnapshot.exists) {
      await userDoc.set({
        'email': user.email ?? '',
        'displayName': user.displayName,
        'photoURL': user.photoURL,
        'createdAt': Timestamp.fromDate(now),
        'preferences': {},
        'planType': 'trial',
        'trialStartDate': Timestamp.fromDate(now),
        'trialEndDate': Timestamp.fromDate(trialEndDate),
        'dailyUsedCount': 0,
        'dailyResetDate': Timestamp.fromDate(todayMidnight),
        'premiumExpiry': null,
      }, SetOptions(merge: true));

      final notificationService = NotificationService();
      try {
        await notificationService.initialize();
        await notificationService.sendWelcomeLocalNotification();
        await notificationService.sendWelcomeNotification(user.uid);
        await notificationService.sendTrialStartedNotification(user.uid, trialEndDate);
        await notificationService.scheduleTrialExpiryWarning(trialEndDate);
      } catch (_) {}
      return;
    }

    final data = docSnapshot.data();
    if (data == null) return;

    final trialEnd = (data['trialEnd'] as Timestamp?)?.toDate() ?? (data['trialEndDate'] as Timestamp?)?.toDate();
    if (trialEnd != null && now.isAfter(trialEnd) && (data['planType'] ?? '') == 'trial') {
      await userDoc.update({
        'planType': 'free',
        'dailyUsedCount': 0,
        'dailyResetDate': Timestamp.fromDate(todayMidnight),
        'trialExpired': true,
      });
    }

    await PremiumService().checkAndUpdateTrialExpiry(user.uid);
    await PremiumService().checkPremiumExpiry(user.uid);
    await MonetizationService.instance.ensureUserMonetizationFields(user.uid);
  }

  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data();
      if (doc.exists && data != null) {
        return UserModel.fromFirestore(data, uid);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).update(data);
  }

  Future<void> signOut() async {
    AdminGuard().clearCache();
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}


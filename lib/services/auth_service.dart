import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/notification_service.dart';
import '../utils/admin_guard.dart';
import 'analytics_service.dart';
import 'premium_service.dart';
import 'device_service.dart';
import 'monetization_service.dart';
import 'play_billing_service.dart';

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
        await _finalizeLogin(credential.user!);
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
        await _finalizeLogin(credential.user!);
      }

      return credential;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: [
          'email',
          'profile',
        ],
        serverClientId: '412053319604-4eerf9lfm4mjg3ijfp74tf5q0g0itbi6.apps.googleusercontent.com',
      );

      await googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null;

      var googleAuth = await googleUser.authentication;

      if (googleAuth.idToken == null) {
        await googleUser.clearAuthCache();
        googleAuth = await googleUser.authentication;
        if (googleAuth.idToken == null) {
          throw PlatformException(
            code: 'id_token_missing',
            message: 'ID token not available. This usually means:\n'
                '1. Release keystore SHA-1 not added in Firebase Console\n'
                '2. OAuth client not properly configured in Google Cloud Console\n'
                '3. App needs to be reinstalled after Firebase changes',
          );
        }
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user != null) {
        await _finalizeLogin(user);
      }

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  static DateTime _midnightToday(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _authMethodForUser(User user) {
    for (final info in user.providerData) {
      if (info.providerId == 'google.com') return 'google';
    }
    return 'email';
  }

  Future<void> _finalizeLogin(User user) async {
    final isNewUser = await _ensureUserDocOnLogin(user);
    await DeviceService().bindDeviceAfterLogin(user.uid);
    await AnalyticsService.setUserIdentity(user);
    if (!isNewUser) {
      AnalyticsService.logLogin(method: _authMethodForUser(user));
    }
    unawaited(PlayBillingService().processPendingPurchasesIfAny());
    unawaited(PlayBillingService().silentRestoreAfterLoginIfNeeded());
  }

  /// Called on every login. Creates user doc on first login with 7-day trial.
  /// Returns true when a new Firestore user doc was created.
  Future<bool> _ensureUserDocOnLogin(User user) async {
    final userDoc = _firestore.collection('users').doc(user.uid);
    final docSnapshot = await userDoc.get();

    final now = DateTime.now();
    final todayMidnight = _midnightToday(now);

    if (!docSnapshot.exists) {
      await userDoc.set({
        'email': user.email ?? '',
        'displayName': user.displayName,
        'photoURL': user.photoURL,
        'createdAt': Timestamp.fromDate(now),
        'preferences': {},
        // No free trial — the app is premium-only behind a hard paywall.
        'planType': 'free',
        'dailyUsedCount': 0,
        'dailyResetDate': Timestamp.fromDate(todayMidnight),
        'premiumExpiry': null,
      }, SetOptions(merge: true));

      final method = _authMethodForUser(user);
      AnalyticsService.logSignUp(method: method);

      final notificationService = NotificationService();
      try {
        await notificationService.initialize();
        // Persist the FCM token now that a user is signed in — initialize()'s
        // `_initialized` guard would otherwise skip token setup on this call.
        await notificationService.syncFcmToken();
        await notificationService.sendWelcomeLocalNotification();
        await notificationService.sendWelcomeNotification(user.uid);
        // New users get a 3-day trial (backend sets the exact end on first AI
        // call; now + 3 days is a close-enough anchor for the reminders).
        final trialEnd = now.add(const Duration(days: 3));
        await notificationService.sendTrialStartedNotification(user.uid, trialEnd);
        await notificationService.scheduleTrialLifecycle(trialEnd);
        await notificationService.scheduleOnboardingTips();
      } catch (_) {}
      return true;
    }

    final data = docSnapshot.data();
    if (data == null) return false;

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
    // Existing user just logged in — make sure their FCM token is on file so
    // admin push campaigns can reach them.
    try {
      final notificationService = NotificationService();
      await notificationService.initialize();
      await notificationService.syncFcmToken();
    } catch (_) {}
    return false;
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

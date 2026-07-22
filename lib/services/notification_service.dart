import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _initialized = false;

  // ─── In-app notifications (Firestore: users/{uid}/notifications/{id}) ───

  Future<void> addNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).collection('notifications').add({
        'title': title,
        'body': body,
        'type': type,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[NotificationService] addNotification error: $e');
    }
  }

  Future<void> markRead(String userId, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      if (kDebugMode) debugPrint('[NotificationService] markRead error: $e');
    }
  }

  Future<void> markAllRead(String userId) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .get();
      for (final doc in snap.docs) {
        await doc.reference.update({'read': true});
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[NotificationService] markAllRead error: $e');
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> notificationsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  Stream<int> unreadCountStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Future<void> sendWelcomeNotification(String userId) async {
    await addNotification(
      userId: userId,
      title: 'Welcome to InstaFlow! 🎉',
      body: 'Your 3-day free trial is on — unlimited AI captions, hooks, reels & more.',
      type: 'welcome',
    );
  }

  /// Nudge non-premium users toward subscribing (no free trial anymore).
  Future<void> sendSubscribeReminderNotification(String userId) async {
    await addNotification(
      userId: userId,
      title: 'Unlock InstaFlow Premium',
      body: 'Get unlimited AI captions, hooks, reels & more. Subscribe to continue.',
      type: 'subscribe_reminder',
    );
  }

  Future<void> sendTrialStartedNotification(String userId, DateTime trialEndDate) async {
    await addNotification(
      userId: userId,
      title: 'Trial started',
      body: 'Your free trial ends on ${_formatDate(trialEndDate)}. Enjoy unlimited AI!',
      type: 'trial_start',
    );
  }

  Future<void> sendTrialEndingSoonNotification(String userId) async {
    await addNotification(
      userId: userId,
      title: 'Trial ending soon',
      body: 'Your free trial ends in 1 day. Subscribe to keep all features!',
      type: 'trial_ending',
    );
  }

  Future<void> sendTrialExpiredNotification(String userId) async {
    await addNotification(
      userId: userId,
      title: 'Trial expired',
      body: 'Your trial has ended. Upgrade to Premium for unlimited AI (2 free uses per day until then).',
      type: 'trial_expired',
    );
  }

  Future<void> sendPremiumActivatedNotification(String userId, DateTime expiryDate) async {
    await addNotification(
      userId: userId,
      title: 'Premium activated',
      body: 'Welcome to Premium! Active until ${_formatDate(expiryDate)}.',
      type: 'premium_active',
    );
  }

  Future<void> sendPremiumExpiringSoonNotification(String userId) async {
    await addNotification(
      userId: userId,
      title: 'Premium expiring soon',
      body: 'Your Premium subscription ends in 1 day. Renew to keep unlimited access!',
      type: 'premium_expiring',
    );
  }

  Future<void> sendPremiumExpiredNotification(String userId) async {
    await addNotification(
      userId: userId,
      title: 'Premium expired',
      body: 'Your Premium subscription has ended. Resubscribe to get unlimited AI back.',
      type: 'premium_expired',
    );
  }

  static String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions
    await _requestPermissions();

    // Configure Firebase Messaging
    await _setupFirebaseMessaging();

    _initialized = true;
  }

  Future<void> _requestPermissions() async {
    // Android 13+ requires notification permission
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // iOS permissions
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _setupFirebaseMessaging() async {
    // Get FCM token
    final token = await _firebaseMessaging.getToken();
    if (kDebugMode) debugPrint('FCM Token: $token');
    await _persistToken(token);

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      if (kDebugMode) debugPrint('FCM token refreshed');
      await _persistToken(newToken);
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages (requires top-level function)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpened);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    showNotification(
      title: message.notification?.title ?? 'New Notification',
      body: message.notification?.body ?? '',
    );
  }

  void _handleMessageOpened(RemoteMessage message) {
    if (kDebugMode) debugPrint('Message opened: ${message.messageId}');
  }

  /// Fetch and persist the FCM token for the current user. Safe to call after
  /// login even when [initialize] already ran (its `_initialized` guard skips
  /// re-setup, so a user who logged in *after* startup would otherwise never
  /// get their token saved — which silently breaks admin push campaigns).
  Future<void> syncFcmToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      await _persistToken(token);
    } catch (e) {
      if (kDebugMode) debugPrint('syncFcmToken failed: $e');
    }
  }

  Future<void> _persistToken(String? token) async {
    if (token == null || token.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    await userRef.set(
      {
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastNotificationTokenAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) debugPrint('Notification tapped: ${response.id}');
  }

  // Schedule a local notification
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'scheduled_posts',
          'Scheduled Posts',
          channelDescription: 'Notifications for scheduled posts',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // Show immediate notification
  Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    // Ensure service is initialized
    if (!_initialized) {
      await initialize();
    }
    
    try {
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch % 100000,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'general',
            'General Notifications',
            channelDescription: 'General app notifications',
            importance: Importance.high,
            priority: Priority.high,
            enableVibration: true,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
      if (kDebugMode) debugPrint('[NotificationService] Notification shown: $title');
    } catch (e) {
      if (kDebugMode) debugPrint('[NotificationService] Error showing notification: $e');
    }
  }

  // Cancel a scheduled notification
  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  // ─── Retention / engagement notifications (local, scheduled) ───────────────
  // These bring users back and build a daily habit — the biggest retention
  // lever. All local + scheduled (no server needed). ID ranges: daily 1000-1013,
  // re-engagement 2000, onboarding tips 3000+.

  static const List<String> _dailyValueMsgs = [
    'Aaj ka viral hook ready hai 🔥 Tap karke apna next post banao',
    'Aaj ke trending hashtags le lo — ek tap me ✨',
    'New post idea ready! AI se caption + hashtags banao 📈',
    'Aaj kya post karein? AI ke paas ready ideas hain 💡',
    'Ek viral caption banao — 30 second me 🚀',
    'Aaj ka content plan ready hai — kholo aur post karo ✍️',
    'Trending reel hook aa gaya 🎬 Apne style me banao',
  ];

  static const List<String> _bestTimeMsgs = [
    'Abhi best time hai post karne ka ⏰ Content ready karo!',
    'Tumhare followers abhi active hain — post kar do 📲',
    'Prime time! Ek reel/post daalo aur engagement badhao 🔥',
  ];

  static const List<List<String>> _onboardingTips = [
    ['✨ Try this', 'Ek tap me scroll-stopping caption banao — AI Tools kholo'],
    ['🎬 Did you know?', 'Poori Reel script ek tap me ban jaati hai — try karo!'],
  ];

  /// Schedule the next 7 days of daily-value (10 AM) + best-time (7 PM)
  /// notifications with rotating copy. Call on app start/resume to keep it
  /// topped up so the habit-forming reminders never run out.
  Future<void> scheduleEngagementNotifications() async {
    if (!_initialized) await initialize();
    for (var i = 1000; i <= 1013; i++) {
      await cancelNotification(i);
    }
    final now = DateTime.now();
    for (var day = 0; day < 7; day++) {
      final base = DateTime(now.year, now.month, now.day + day);
      final morning = DateTime(base.year, base.month, base.day, 10, 0);
      if (morning.isAfter(now)) {
        await scheduleNotification(
          id: 1000 + day,
          title: '🔥 Content of the day',
          body: _dailyValueMsgs[day % _dailyValueMsgs.length],
          scheduledDate: morning,
        );
      }
      final evening = DateTime(base.year, base.month, base.day, 19, 0);
      if (evening.isAfter(now)) {
        await scheduleNotification(
          id: 1007 + day,
          title: '⏰ Best time to post',
          body: _bestTimeMsgs[day % _bestTimeMsgs.length],
          scheduledDate: evening,
        );
      }
    }
    if (kDebugMode) debugPrint('[NotificationService] engagement notifications scheduled');
  }

  /// A "we miss you" nudge ~2 days out. Re-armed on every app open, so it only
  /// actually fires when the user has been inactive for ~2 days.
  Future<void> scheduleReEngagementNotification() async {
    if (!_initialized) await initialize();
    await cancelNotification(2000);
    final t = DateTime.now().add(const Duration(days: 2));
    final when = DateTime(t.year, t.month, t.day, 11, 0);
    await scheduleNotification(
      id: 2000,
      title: 'We miss you 👋',
      body: 'Tumhare followers wait kar rahe hain — aaj ka viral content 1 tap me banao ✨',
      scheduledDate: when,
    );
  }

  /// One-time feature-discovery tips on day 1 & day 2 after signup.
  Future<void> scheduleOnboardingTips() async {
    if (!_initialized) await initialize();
    final now = DateTime.now();
    for (var i = 0; i < _onboardingTips.length; i++) {
      final when = DateTime(now.year, now.month, now.day + i + 1, 11, 30);
      await scheduleNotification(
        id: 3000 + i,
        title: _onboardingTips[i][0],
        body: _onboardingTips[i][1],
        scheduledDate: when,
      );
    }
  }

  // Send welcome notification to new user (local/push only; for in-app use sendWelcomeNotification(userId))
  Future<void> sendWelcomeLocalNotification() async {
    // Ensure service is initialized
    if (!_initialized) {
      await initialize();
    }
    
    // Add a small delay to ensure permissions are granted
    await Future.delayed(const Duration(milliseconds: 500));
    
    await showNotification(
      title: '🎉 Welcome to InstaFlow!',
      body: '3 days of unlimited AI unlocked 🎁 Banao apna pehla viral caption abhi!',
    );
    if (kDebugMode) debugPrint('[NotificationService] Welcome notification sent');
  }

  // Trial / premium lifecycle notification IDs. Kept in the 4000+ range so they
  // never collide with the daily engagement block (1000-1013), which cancels &
  // re-schedules its whole range on every app open.
  static const int trialEndingWarningId = 4001;
  static const int trialExpiredId = 4003;

  /// New user just started a 3-day trial: greet them now and schedule the
  /// "ending soon" (1 day before) + "expired" (at end) local notifications.
  Future<void> scheduleTrialLifecycle(DateTime trialEndDate) async {
    if (!_initialized) await initialize();
    await showNotification(
      title: '🎁 Your 3-day free trial is live!',
      body: 'Unlimited AI captions, hooks & reels until ${_formatDate(trialEndDate)}. Enjoy!',
    );
    await scheduleTrialExpiryWarning(trialEndDate);
    if (trialEndDate.isAfter(DateTime.now())) {
      await scheduleNotification(
        id: trialExpiredId,
        title: 'Your free trial has ended',
        body: 'You still get 2 free AI uses daily. Go Premium for unlimited ✨',
        scheduledDate: trialEndDate,
      );
    }
  }

  // Schedule trial expiry warning (1 day before)
  Future<void> scheduleTrialExpiryWarning(DateTime trialEndDate) async {
    if (!_initialized) await initialize();
    final warningDate = trialEndDate.subtract(const Duration(days: 1));

    // Only schedule if warning date is in the future
    if (warningDate.isAfter(DateTime.now())) {
      await scheduleNotification(
        id: trialEndingWarningId,
        title: '⏰ Trial Ending Soon!',
        body: 'Your free trial ends tomorrow. Go Premium to keep unlimited AI!',
        scheduledDate: warningDate,
      );
      if (kDebugMode) debugPrint('[NotificationService] Scheduled trial expiry warning for: $warningDate');
    }
  }

  // Send subscription success notification
  Future<void> sendSubscriptionSuccessNotification(String plan) async {
    final planName = plan == 'basic' ? 'BASIC' : 'PRO';
    await showNotification(
      title: '✨ Premium Activated!',
      body: 'Welcome to InstaFlow $planName! Enjoy unlimited access to all AI tools.',
    );
  }

  // Send payment success notification
  Future<void> sendPaymentSuccessNotification() async {
    await showNotification(
      title: '💳 Payment Successful!',
      body: 'Your subscription is now active. Thank you for choosing InstaFlow!',
    );
  }

  // Cancel trial expiry warning (if user upgrades before trial ends)
  Future<void> cancelTrialExpiryWarning() async {
    await cancelNotification(trialEndingWarningId);
    await cancelNotification(trialExpiredId);
    if (kDebugMode) debugPrint('[NotificationService] Cancelled trial expiry warning');
  }

  /// Schedule "Premium Ending Soon" 1 day before premiumExpiry.
  static const int premiumExpiryWarningId = 4002;

  Future<void> schedulePremiumExpiryWarning(DateTime premiumExpiry) async {
    if (!_initialized) await initialize();
    final scheduleAt = premiumExpiry.subtract(const Duration(days: 1));
    if (!scheduleAt.isAfter(DateTime.now())) {
      if (kDebugMode) debugPrint('[NotificationService] Premium expiry warning not scheduled (expiry too soon): $premiumExpiry');
      return;
    }
    await scheduleNotification(
      id: premiumExpiryWarningId,
      title: 'Premium Ending Soon',
      body: 'Your InstaFlow Premium expires tomorrow.',
      scheduledDate: scheduleAt,
    );
    if (kDebugMode) debugPrint('[NotificationService] Premium expiry warning scheduled at: $scheduleAt (expiry: $premiumExpiry)');
  }

  Future<void> cancelPremiumExpiryWarning() async {
    await cancelNotification(premiumExpiryWarningId);
  }
}


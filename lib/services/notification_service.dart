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
      title: 'Welcome to InstaFlow!',
      body: 'Your 7-day free trial has started. Explore all AI tools now!',
      type: 'welcome',
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
      body: 'Your 7-day free trial has started. Explore all AI tools now!',
    );
    if (kDebugMode) debugPrint('[NotificationService] Welcome notification sent');
  }

  // Schedule trial expiry warning (1 day before)
  Future<void> scheduleTrialExpiryWarning(DateTime trialEndDate) async {
    final warningDate = trialEndDate.subtract(const Duration(days: 1));
    
    // Only schedule if warning date is in the future
    if (warningDate.isAfter(DateTime.now())) {
      await scheduleNotification(
        id: 1001, // Fixed ID for trial expiry warning
        title: '⏰ Trial Ending Soon!',
        body: 'Your free trial ends tomorrow. Subscribe now to keep all features!',
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
    await cancelNotification(1001);
    if (kDebugMode) debugPrint('[NotificationService] Cancelled trial expiry warning');
  }

  /// Schedule "Premium Ending Soon" 1 day before premiumExpiry.
  static const int premiumExpiryWarningId = 1002;

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


import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:insta_flow/screens/login_screen.dart';
import 'package:insta_flow/screens/signup_screen.dart';
import 'package:insta_flow/screens/forgot_password_screen.dart';
import 'package:insta_flow/screens/home_screen.dart';
import 'package:insta_flow/screens/profile_screen.dart';
import 'package:insta_flow/screens/hashtag_analyzer_screen.dart';
import 'package:insta_flow/screens/best_time_screen.dart';
import 'package:insta_flow/screens/schedule_screen.dart';
import 'package:insta_flow/screens/analytics_screen.dart';
import 'package:insta_flow/screens/stats_screen.dart';
import 'package:insta_flow/screens/ai_tools_screen.dart';
import 'package:insta_flow/screens/hashtag_generator_screen.dart';
import 'package:insta_flow/screens/bio_maker_screen.dart';
import 'package:insta_flow/screens/ideas_screen.dart';
import 'package:insta_flow/screens/reel_script_screen.dart';
import 'package:insta_flow/screens/viral_hook_screen.dart';
import 'package:insta_flow/screens/reels_script_screen.dart';
import 'package:insta_flow/screens/comment_reply_screen.dart';
import 'package:insta_flow/screens/story_ideas_screen.dart';
import 'package:insta_flow/screens/dm_auto_reply_screen.dart';
import 'package:insta_flow/screens/carousel_writer_screen.dart';
import 'package:insta_flow/screens/rewrite_tool_screen.dart';
import 'package:insta_flow/screens/product_brief_screen.dart';
import 'package:insta_flow/screens/trending_hashtags_screen.dart';
import 'package:insta_flow/screens/instagram_stats_screen.dart';
import 'package:insta_flow/screens/ai_captions_screen.dart';
import 'package:insta_flow/screens/ai_calendar_screen.dart';
import 'package:insta_flow/screens/ai_strategy_screen.dart';
import 'package:insta_flow/screens/ai_content_engine_screen.dart';
import 'package:insta_flow/screens/niche_analysis_screen.dart';
import 'package:insta_flow/screens/google_connect_screen.dart';
import 'package:insta_flow/screens/google_calendar_coming_soon_screen.dart';
import 'package:insta_flow/screens/coming_soon_screen.dart';
import 'package:insta_flow/screens/subscription_screen.dart';
import 'package:insta_flow/screens/premium_paywall_screen.dart';
import 'package:insta_flow/screens/premium_hub_screen.dart';
import 'package:insta_flow/screens/admin_dashboard_screen.dart';
import 'package:insta_flow/screens/feedback_screen.dart';
import 'package:insta_flow/screens/my_feedback_screen.dart';
import 'package:insta_flow/screens/admin_feedback_screen.dart';
import 'package:insta_flow/screens/admin/admin_notifications_screen.dart';
import 'package:insta_flow/screens/scheduled_posts_screen.dart';
import 'package:insta_flow/screens/edit_profile_screen.dart';
import 'package:insta_flow/screens/notification_settings_screen.dart';
import 'package:insta_flow/screens/notification_screen.dart';
import 'package:insta_flow/screens/legal/privacy_policy_screen.dart';
import 'package:insta_flow/screens/legal/terms_conditions_screen.dart';
import 'package:insta_flow/screens/legal/refund_policy_screen.dart';
import 'package:insta_flow/screens/legal/contact_support_screen.dart';
import 'package:insta_flow/screens/your_stats_screen.dart';
// Schedule Post gated as "Coming Soon" — re-enable this import with the route below.
// import 'package:insta_flow/screens/schedule_post_screen.dart';
import 'package:insta_flow/screens/queue_slots_screen.dart';
import 'package:insta_flow/screens/scheduler_calendar_screen.dart';
import 'package:insta_flow/screens/instagram_automation/reel_publish_screen.dart';
import 'package:insta_flow/providers/theme_provider.dart';
import 'package:insta_flow/providers/instagram_provider.dart';
import 'package:insta_flow/providers/schedule_provider.dart';
import 'package:insta_flow/services/notification_service.dart';
import 'package:insta_flow/widgets/force_update_dialog.dart';
import 'package:insta_flow/widgets/onboarding_gate.dart';
import 'package:insta_flow/services/premium_service.dart';
import 'package:insta_flow/services/play_billing_service.dart';
import 'package:insta_flow/services/ad_service.dart';
import 'package:insta_flow/services/session_guard.dart';
import 'package:insta_flow/services/remote_config_service.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    if (kDebugMode) debugPrint('STARTUP: binding');

    ErrorWidget.builder = (FlutterErrorDetails details) {
      if (kDebugMode) return ErrorWidget(details.exception);
      return Material(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.grey[600]),
                const SizedBox(height: 16),
                Text(
                  'Something went wrong. Please restart the app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                ),
              ],
            ),
          ),
        ),
      );
    };

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    // Firebase MUST be initialized before FirebaseCrashlytics — otherwise Android can crash on startup.
    var firebaseOk = false;
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIzaSyDJf_BcX9j2s-elirtIYVAjldUCe9DjYXo',
          appId: '1:412053319604:android:eccc9045ef3fd714d24ce1',
          messagingSenderId: '412053319604',
          projectId: 'instaflow-f65a0',
          storageBucket: 'instaflow-f65a0.firebasestorage.app',
        ),
      ).timeout(const Duration(seconds: 20));
      firebaseOk = true;
      if (kDebugMode) debugPrint('STARTUP: Firebase OK');
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('STARTUP: Firebase init failed: $e');
        debugPrint('$st');
      }
      // Do not call Crashlytics here — Firebase app is not ready.
    }

    if (firebaseOk) {
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(!kDebugMode);
      FlutterError.onError = (FlutterErrorDetails details) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        if (kDebugMode) FlutterError.presentError(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    } else {
      FlutterError.onError = (FlutterErrorDetails details) {
        if (kDebugMode) FlutterError.presentError(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        if (kDebugMode) debugPrint('Uncaught (no Crashlytics): $error');
        return true;
      };
    }

    if (kDebugMode) debugPrint('STARTUP: runApp');
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => InstagramProvider()),
          ChangeNotifierProvider(create: (_) => ScheduleProvider()),
        ],
        child: firebaseOk
            ? const InstaFlowApp()
            : const _FirebaseInitFailedApp(),
      ),
    );
    if (kDebugMode) debugPrint('STARTUP: runApp done');
  }, (error, stack) {
    if (kDebugMode) debugPrint('STARTUP: zone error $error $stack');
    try {
      FirebaseCrashlytics.instance.recordError(
        error,
        stack ?? StackTrace.current,
        fatal: false,
      );
    } catch (_) {
      /* Firebase not ready */
    }
  });
}

/// Shown only if [Firebase.initializeApp] fails (network / config).
class _FirebaseInitFailedApp extends StatelessWidget {
  const _FirebaseInitFailedApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF7B2CBF),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off, size: 56, color: Colors.white),
                  const SizedBox(height: 20),
                  Text(
                    'Could not connect to services.\nCheck internet and reopen the app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Background init — do NOT await. Billing is lazy (paywall only). Splash/route not blocked.
Future<void> initServicesInBackground() async {
  if (kDebugMode) debugPrint('STARTUP: background init start');
  const timeout = Duration(seconds: 8);
  try {
    unawaited(
      AdService.initialize().timeout(timeout).catchError((e) {
        if (kDebugMode) debugPrint('STARTUP: background init error (ads): $e');
      }),
    );
    unawaited(
      RemoteConfigService().initialize().timeout(timeout).catchError((e) {
        if (kDebugMode) debugPrint('STARTUP: background init error (remote config): $e');
      }),
    );
    unawaited(
      NotificationService().initialize().timeout(timeout).catchError((e) {
        if (kDebugMode) debugPrint('STARTUP: background init error (notifications): $e');
      }).then((_) async {
        // Retention: schedule daily value + best-time reminders, and re-arm the
        // "we miss you" nudge (fires only if the user stays away ~2 days).
        try {
          await NotificationService().scheduleEngagementNotifications();
          await NotificationService().scheduleReEngagementNotification();
        } catch (e) {
          if (kDebugMode) debugPrint('STARTUP: engagement schedule error: $e');
        }
      }),
    );
    unawaited(
      PlayBillingService().initialize().timeout(timeout).catchError((e) {
        if (kDebugMode) debugPrint('STARTUP: Play billing init: $e');
        return false;
      }),
    );
    unawaited(
      Future(() async {
        try {
          AdService().resetSession();
          AdService().loadInterstitialAd();
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            try {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .update({'lastActiveAt': FieldValue.serverTimestamp()})
                  .timeout(timeout);
            } catch (_) {}
            final premiumService = PremiumService();
            await premiumService.checkAndUpdateTrialExpiry(user.uid).timeout(timeout);
            await premiumService.checkPremiumExpiry(user.uid).timeout(timeout);
            unawaited(
              PlayBillingService()
                  .silentRestoreAfterLoginIfNeeded()
                  .timeout(const Duration(seconds: 15))
                  .catchError((e) {
                if (kDebugMode) debugPrint('STARTUP: silent restore: $e');
              }),
            );
          }
        } catch (e) {
          if (kDebugMode) debugPrint('STARTUP: background init error (post-init): $e');
        }
      }),
    );
  } catch (e) {
    if (kDebugMode) debugPrint('STARTUP: background init error: $e');
  }
  if (kDebugMode) debugPrint('STARTUP: background init scheduled (non-blocking)');
}

/// Splash gate: shows splash for one frame then app. Firebase is initialized in main (same zone).
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      initServicesInBackground();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const _SplashScreen();
    }
    return OnboardingGate(
      child: ForceUpdateGate(
        child: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            // Wait for first auth resolution so we don't flash Login before restored session.
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _SplashScreen();
            }
            final user = snapshot.data;
            // Freemium: every logged-in user enters the app. AI tools enforce the
            // 3-day trial (unlimited) → free (2/day) → premium (unlimited) limits
            // per-generation, and show the upgrade prompt when a free user runs
            // out of daily credits. No hard paywall on entry.
            final child = user != null
                ? const HomeScreen()
                : const LoginScreen();
            return SessionGuardGate(isLoggedIn: user != null, child: child);
          },
        ),
      ),
    );
  }
}

/// Runs SessionGuard on start and on resume; signs out and shows dialog if device mismatch.
class SessionGuardGate extends StatefulWidget {
  const SessionGuardGate({super.key, required this.child, required this.isLoggedIn});

  final Widget child;
  final bool isLoggedIn;

  @override
  State<SessionGuardGate> createState() => _SessionGuardGateState();
}

class _SessionGuardGateState extends State<SessionGuardGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.isLoggedIn) _runSessionCheck();
  }

  @override
  void didUpdateWidget(SessionGuardGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoggedIn && !oldWidget.isLoggedIn) _runSessionCheck();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isLoggedIn) {
      _runSessionCheck();
      // Re-arm the "we miss you" nudge each time the app opens, so it only fires
      // when the user has actually been away ~2 days.
      unawaited(NotificationService().scheduleReEngagementNotification());
    }
  }

  Future<void> _runSessionCheck() async {
    final invalidated = await SessionGuard().checkAndInvalidateIfMismatch();
    if (!mounted) return;
    if (invalidated) {
      await SessionGuard.showAnotherDeviceDialog(context);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF7B2CBF),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome, size: 64, color: Colors.white),
              const SizedBox(height: 24),
              const Text(
                'Insta Flow',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 48),
              const CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class InstaFlowApp extends StatelessWidget {
  const InstaFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    const premiumPrimary = Color(0xFF7B2CBF);
    const premiumPink = Color(0xFFFF7AD9);
    // Android is the shipping platform; use the zoom transition everywhere.
    // (CupertinoPageTransitionsBuilder isn't resolvable in this SDK and the
    // whole block was uncommitted/never-built — keep it simple and valid.)
    const transitions = PageTransitionsTheme(
      builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
        TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
        TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        TargetPlatform.linux: ZoomPageTransitionsBuilder(),
      },
    );

    return MaterialApp(
      title: 'InstaFlow',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        final q = MediaQuery.of(context);
        final scale = (q.textScaler.scale(1.0)).clamp(0.8, 1.2);
        return MediaQuery(
          data: q.copyWith(textScaler: TextScaler.linear(scale)),
          child: child,
        );
      },

      // 🌞 Light Theme - Purple Gradient with White Background
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF7F4FF),
        colorScheme: ColorScheme.fromSeed(
          seedColor: premiumPrimary,
          brightness: Brightness.light,
        ),
        pageTransitionsTheme: transitions,
        visualDensity: VisualDensity.standard,
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.4),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          bodyLarge: TextStyle(fontSize: 16, height: 1.45),
          bodyMedium: TextStyle(fontSize: 14, height: 1.4),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: premiumPrimary,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
          iconTheme: IconThemeData(color: Colors.white),
          toolbarHeight: 56,
        ),
        cardColor: Colors.white,
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 3,
          shadowColor: const Color(0x14000000),
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: premiumPrimary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: premiumPrimary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: premiumPrimary,
            side: BorderSide(color: premiumPrimary.withValues(alpha: 0.38)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8F6FF),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: (Colors.grey[300] ?? Colors.grey)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: premiumPrimary, width: 1.8),
          ),
        ),
      ),

      // 🌙 Dark Theme (Optional)
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121018),
        colorScheme: ColorScheme.fromSeed(
          seedColor: premiumPrimary,
          brightness: Brightness.dark,
        ),
        pageTransitionsTheme: transitions,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1A2B),
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
          bodyMedium: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          bodyLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1A2B),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: premiumPink,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF241F33),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.white24),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: premiumPink),
          ),
          hintStyle: const TextStyle(color: Colors.white54),
        ),
      ),

      home: const SplashGate(),

      // 🧭 App Routes
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/forgot_password': (context) => const ForgotPasswordScreen(),
        // Gated: login/signup navigate here directly, so the subscription gate
        // must wrap it too (not only the auth StreamBuilder path).
        '/home': (context) => const HomeScreen(),
        '/profile': (context) => const ProfileScreen(),
        // Stats: primary entry from Home is /stats only. /stats-full and /instagram-stats are secondary (e.g. Your Stats menu).
        '/stats': (context) => const YourStatsScreen(),
        '/stats-full': (context) => const StatsScreen(),
        '/instagram-stats': (context) => const InstagramStatsScreen(),
        '/ai-tools': (context) => const AIToolsScreen(),
        // Captions: canonical screen is /ai-captions. /captions and /ai_caption are legacy deep links → same widget.
        '/ai-captions': (context) => const AICaptionsScreen(),
        '/captions': (context) => const AICaptionsScreen(),
        '/ai_caption': (context) => const AICaptionsScreen(),
        '/hashtags': (context) => const HashtagGeneratorScreen(),
        '/bio-maker': (context) => const BioMakerScreen(),
        '/ideas': (context) => const IdeasScreen(),
        '/reels-script': (context) => const ReelScriptScreen(),
        '/reels-script-writer': (context) => const ReelsScriptScreen(),
        '/viral-hook': (context) => const ViralHookScreen(),
        '/comment-reply': (context) => const CommentReplyScreen(),
        '/story-ideas': (context) => const StoryIdeasScreen(),
        '/dm-auto-reply': (context) => const DMAutoReplyScreen(),
        '/carousel-writer': (context) => const CarouselWriterScreen(),
        '/rewrite-tool': (context) => const RewriteToolScreen(),
        '/product-brief': (context) => const ProductBriefScreen(),
        '/trending-hashtags': (context) => const TrendingHashtagsScreen(),
        // Not linked from Home / AI Tools tab; kept for old bookmarks / deep links only.
        '/daily-viral-drop': (context) => const ComingSoonScreen(title: 'Viral Drop'),
        '/premium': (context) => const PremiumPaywallScreen(),
        '/premium-hub': (context) => const PremiumHubScreen(),
        '/hashtag': (context) => const HashtagAnalyzerScreen(),
        '/best_time': (context) => const BestTimeScreen(),
        '/schedule': (context) => const ScheduleScreen(),
        '/analytics': (context) => const AnalyticsScreen(),
        '/subscription': (context) => const SubscriptionScreen(),
        '/scheduled_posts': (context) => const ScheduledPostsScreen(),
        '/queue-slots': (context) => const QueueSlotsScreen(),
        '/scheduler-calendar': (context) => const SchedulerCalendarScreen(),
        '/edit_profile': (context) => const EditProfileScreen(),
        '/notification_settings': (context) => const NotificationSettingsScreen(),
        '/notifications': (context) => const NotificationScreen(),
        '/privacy-policy': (context) => const PrivacyPolicyScreen(),
        '/terms-conditions': (context) => const TermsConditionsScreen(),
        '/refund-policy': (context) => const RefundPolicyScreen(),
        '/contact-support': (context) => const ContactSupportScreen(),
        '/ai-calendar': (context) => const AICalendarScreen(),
        '/ai-strategy': (context) => const AIStrategyScreen(),
        '/ai-content-engine': (context) => const AIContentEngineScreen(),
        '/niche-analysis': (context) => const NicheAnalysisScreen(),
        '/google-connect': (context) => const GoogleConnectScreen(),
        // TODO: Enable after OAuth + verification complete — swap for live Google Calendar screen.
        '/google-calendar': (context) => const GoogleCalendarComingSoonScreen(),
        '/admin-dashboard': (context) => const AdminDashboardScreen(),
        '/feedback': (context) => const FeedbackScreen(),
        '/my-feedback': (context) => const MyFeedbackScreen(),
        '/admin-feedback': (context) => const AdminFeedbackScreen(),
        '/admin-notifications': (context) => const AdminNotificationsScreen(),
        // Schedule Post gated as "Coming Soon" while the Instagram-style editor is
        // still being built. Re-enable by swapping back to `const SchedulePostScreen()`.
        '/schedule-post': (context) => const ComingSoonScreen(
              title: 'Schedule Posts',
              subtitle: 'Coming Soon 🚀',
              message:
                  "We're building a powerful Instagram-style post scheduler — edit photos, add music, and let your Reels & posts publish automatically at the perfect time.\n\n"
                  "It's almost ready and landing in an upcoming update. Meanwhile, keep creating captions, hashtags, and content with AI! 💜",
              icon: Icons.schedule_send_rounded,
            ),
        '/reel-publish': (context) => const ReelPublishScreen(),
      },
    );
  }
}

// Splash screen removed - app goes directly to login/home

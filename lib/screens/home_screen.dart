import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/main_navigation_wrapper.dart';
import '../widgets/notification_bell_icon.dart';
import '../widgets/home_mission_card.dart';
import '../widgets/personalized_resume_card.dart';
import '../services/ad_service.dart';
import '../services/api_service.dart';
import '../services/retention_service.dart';
import '../utils/admin_guard.dart';
import '../models/daily_mission_model.dart';

/// Premium InstaFlow home — light purple/pink gradient, SaaS-style hierarchy.
const Color _kPrimary = Color(0xFF7B61FF);
const Color _kAccentPink = Color(0xFFFF7AD9);
const Color _kTextPrimary = Color(0xFF1A1A1A);
const double _kCardRadius = 20;
/// Home dashboard: section gaps & card corners (SaaS-style).
const double _kSectionGap = 20;
const double _kHomeCardRadius = 16;

/// Soft card shadow (SaaS-style elevation).
List<BoxShadow> _kCardShadow(Color accent, {double blur = 20}) => [
      BoxShadow(
        color: accent.withValues(alpha: 0.12),
        blurRadius: blur,
        offset: const Offset(0, 10),
        spreadRadius: -4,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AdService _adService = AdService();
  final ApiService _api = ApiService();
  Widget? _bannerAdWidget;
  bool _isBannerAdLoaded = false;
  bool _isAdmin = false;
  bool _didScheduleAdminRefreshFromUserDoc = false;
  DailyMissionModel? _mission;
  Map<String, dynamic>? _recommendations;
  bool _retentionBackendUnavailable = false;
  Map<String, dynamic>? _growthCoachData;
  Map<String, dynamic>? _todaySuggestion;

  /// Cached once so rebuilds don't recreate the Firestore subscription
  /// (which would flip the StreamBuilder back to `waiting` and flicker the
  /// whole screen with a spinner on every setState).
  Stream<DocumentSnapshot>? _userDocStream;

  Stream<DocumentSnapshot>? _userStreamFor(String uid) {
    return _userDocStream ??= FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBannerAd();
      _loadUserData();
      _loadRetentionCards();
      _loadAiAssistant();
      _maybeShowFirstWow();
    });
  }

  /// First "wow" moment: right after a new user finishes onboarding, guide them
  /// into creating their very first viral caption in one tap. Shown once.
  Future<void> _maybeShowFirstWow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('first_wow_pending') != true) return;
      await prefs.setBool('first_wow_pending', false);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🚀', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              const Text(
                'Banao apna pehla viral caption!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Bas apna topic likho — AI 10 second me scroll-stopping caption + hashtags bana dega. Try karo, free hai 🎁',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B2CBF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, '/ai-captions');
                  },
                  child: const Text('Create my first caption ✨',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Baad me', style: TextStyle(color: Colors.black45)),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[HomeScreen] first-wow: $e');
    }
  }

  Future<void> _loadAiAssistant() async {
    try {
      final growth = await _api.getGrowthCoach(
        followers: 0,
        posts: 0,
        activity: 'medium',
      );
      final suggestion = await _api.generateContentEngine(
        niche: 'Instagram creators',
        goal: 'engagement',
      );
      if (!mounted) return;
      setState(() {
        _growthCoachData = growth;
        _todaySuggestion = suggestion;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[HomeScreen] _loadAiAssistant: $e');
      if (!mounted) return;
      setState(() {
        _growthCoachData = {
          'daily_plan': [
            'Post one short-value reel',
            'Reply to top comments',
            'Publish 2 stories with CTA',
          ],
        };
        _todaySuggestion = {
          'idea': 'Teach one simple framework in your niche.',
          'caption': 'Quick practical tip your audience can apply today.',
          'best_time': '7:30 PM',
        };
      });
    }
  }

  Future<void> _loadUserData() async {
    try {
      final isAdmin = await AdminGuard().isAdminUser();
      if (mounted) setState(() => _isAdmin = isAdmin);
    } catch (e) {
      if (kDebugMode) debugPrint('[HomeScreen] _loadUserData: $e');
    }
  }

  Future<void> _loadBannerAd() async {
    await _adService.loadBannerAd();
    Future.delayed(const Duration(seconds: 1), () async {
      if (!mounted) return;
      final widget = await _adService.getBannerAdWidget();
      if (mounted && widget != null) {
        setState(() {
          _bannerAdWidget = widget;
          _isBannerAdLoaded = true;
        });
      } else if (mounted) {
        Future.delayed(const Duration(seconds: 2), () async {
          if (!mounted) return;
          final retryWidget = await _adService.getBannerAdWidget();
          if (mounted && retryWidget != null) {
            setState(() {
              _bannerAdWidget = retryWidget;
              _isBannerAdLoaded = true;
            });
          }
        });
      }
    });
  }

  Future<void> _loadRetentionCards() async {
    final ok = await RetentionService.instance.isRetentionBackendAvailable();
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _retentionBackendUnavailable = true;
        _mission = null;
        _recommendations = null;
      });
      return;
    }
    setState(() => _retentionBackendUnavailable = false);
    final mission = await RetentionService.instance.fetchTodayMission();
    final recs = await RetentionService.instance.fetchRecommendations();
    final hasAny = mission != null || recs != null;
    if (!hasAny) {
      if (!mounted) return;
      setState(() {
        _retentionBackendUnavailable = true;
        _mission = null;
        _recommendations = null;
      });
      return;
    }
    await RetentionService.instance.runSmartNotificationHints();
    if (!mounted) return;
    setState(() {
      _retentionBackendUnavailable = false;
      _mission = mission;
      _recommendations = recs;
    });
  }

  Future<void> _onRefresh() async {
    await _loadRetentionCards();
  }

  Future<void> _completeMissionTask(String taskType) async {
    final updated =
        await RetentionService.instance.completeMissionTask(taskType);
    if (!mounted || updated == null) return;
    setState(() => _mission = updated);
    if (updated.isCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Mission complete! Streak reward granted.')),
      );
    }
  }

  void _openResume() {
    final cwl =
        _recommendations?['continueWhereLeft'] as Map<String, dynamic>? ?? {};
    final tool = (cwl['tool'] ?? '').toString();
    final routeMap = <String, String>{
      'ai_captions': '/ai-captions',
      'ai_calendar': '/ai-calendar',
      'hashtags': '/hashtags',
      'ai_strategy': '/ai-strategy',
      'niche_analysis': '/niche-analysis',
    };
    Navigator.pushNamed(context, routeMap[tool] ?? '/ai-captions');
  }

  static const Color _kScaffoldBg = Color(0xFFF7F4FF);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    // Home is only shown when SplashGate has a signed-in user; avoid login redirect / flicker here.
    if (user == null) {
      return const Scaffold(
        backgroundColor: _kScaffoldBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return MainNavigationWrapper(
      currentIndex: 0,
      floatingActionButton: Material(
        elevation: 10,
        shadowColor: _kPrimary.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(28),
        child: FloatingActionButton.extended(
          onPressed: () => Navigator.pushNamed(context, '/feedback'),
          elevation: 0,
          highlightElevation: 4,
          backgroundColor: _kPrimary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 22),
          label: const Text(
            'Feedback',
            style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: _kScaffoldBg,
        body: StreamBuilder<DocumentSnapshot>(
          stream: _userStreamFor(user.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(24),
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: Colors.red.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load profile: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _kTextPrimary),
                    ),
                  ],
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data == null) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No data found', textAlign: TextAlign.center),
                ),
              );
            }

            final userDoc = snapshot.data!;
            if (userDoc.exists && !_didScheduleAdminRefreshFromUserDoc) {
              _didScheduleAdminRefreshFromUserDoc = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                AdminGuard().clearCache();
                AdminGuard().isAdminUser().then((isAdmin) {
                  if (mounted && _isAdmin != isAdmin) {
                    setState(() => _isAdmin = isAdmin);
                  }
                });
              });
            }

            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF7F4FF),
                    Color(0xFFFFF8FC),
                    Color(0xFFFDFCFF),
                  ],
                ),
              ),
              child: RefreshIndicator(
                color: _kPrimary,
                onRefresh: _onRefresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics()),
                  slivers: [
                    SliverToBoxAdapter(
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeaderRow(context),
                              const SizedBox(height: 24),
                              _buildGreeting(),
                              const SizedBox(height: 24),
                              // 1. Quick actions
                              _sectionHeader(
                                'Quick actions',
                                caption: 'Stats & scheduling',
                                icon: Icons.bolt_rounded,
                              ),
                              const SizedBox(height: 14),
                              _buildQuickActions(context),
                              const SizedBox(height: _kSectionGap),
                              _sectionHeader(
                                "Today's AI Plan",
                                caption: 'Growth coach suggestions',
                                icon: Icons.psychology_alt_outlined,
                              ),
                              const SizedBox(height: 12),
                              _buildGrowthCoachCard(context),
                              const SizedBox(height: _kSectionGap),
                              _sectionHeader(
                                'Try this today',
                                caption: 'AI generated daily suggestion',
                                icon: Icons.auto_awesome_outlined,
                              ),
                              const SizedBox(height: 12),
                              _buildTryTodayCard(context),
                              const SizedBox(height: _kSectionGap),
                              // 2. Best time insight
                              _sectionHeader(
                                'Best time to post',
                                caption: 'Higher reach window for your audience',
                                icon: Icons.insights_outlined,
                              ),
                              const SizedBox(height: 12),
                              _buildAiSuggestionCard(context),
                              const SizedBox(height: _kSectionGap),
                              // Google Calendar — coming soon (no OAuth/API until verification)
                              const _HomeGoogleCalendarCard(),
                              const SizedBox(height: _kSectionGap),
                              // 4. Continue / AI & missions
                              if (_retentionBackendUnavailable) ...[
                                _retentionUnavailableCard(),
                                const SizedBox(height: 16),
                              ],
                              if (_recommendations
                                  case final Map<String, dynamic> recs) ...[
                                _sectionHeader(
                                  'Continue',
                                  caption: 'Pick up where you left off',
                                  icon: Icons.auto_awesome_outlined,
                                ),
                                const SizedBox(height: 12),
                                PersonalizedResumeCard(
                                  data: recs,
                                  onOpen: _openResume,
                                  primaryColor: _kPrimary,
                                  accentPink: _kAccentPink,
                                ),
                                const SizedBox(height: 16),
                              ],
                              if (_mission case final DailyMissionModel m) ...[
                                _sectionHeader(
                                  "Today's mission",
                                  caption: 'Complete tasks to grow your streak',
                                  icon: Icons.flag_outlined,
                                ),
                                const SizedBox(height: 12),
                                HomeMissionCard(
                                  mission: m,
                                  onCompleteTask: _completeMissionTask,
                                  showProgressRing: true,
                                  primaryColor: _kPrimary,
                                ),
                                const SizedBox(height: 20),
                              ],
                              SizedBox(
                                height: 108 +
                                    MediaQuery.paddingOf(context).bottom,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_isBannerAdLoaded && _bannerAdWidget != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          child: Container(
                            alignment: Alignment.center,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(_kCardRadius),
                              boxShadow: _kCardShadow(_kPrimary, blur: 14),
                            ),
                            child: _bannerAdWidget,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, {String? caption, IconData? icon}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  _kPrimary.withValues(alpha: 0.14),
                  _kAccentPink.withValues(alpha: 0.1),
                ],
              ),
            ),
            child: Icon(icon, color: _kPrimary, size: 20),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _kTextPrimary,
                  letterSpacing: -0.5,
                  height: 1.15,
                ),
              ),
              if (caption != null) ...[
                const SizedBox(height: 4),
                Text(
                  caption,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                    height: 1.25,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderRow(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _kPrimary.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              'assets/icon/app_icon.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: _kPrimary.withValues(alpha: 0.12),
                child:
                    const Icon(Icons.auto_awesome, color: _kPrimary, size: 26),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'InstaFlow',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _kTextPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const Spacer(),
        if (_isAdmin)
          IconButton(
            icon: const Icon(Icons.dashboard_rounded, color: _kTextPrimary),
            onPressed: () => Navigator.pushNamed(context, '/admin-dashboard'),
            tooltip: 'Admin',
          ),
        const NotificationBellIcon(lightBackground: true),
      ],
    );
  }

  Widget _buildGreeting() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Text(
        'Hey there 👋',
        style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: _kTextPrimary,
            height: 1.2),
      );
    }
    return StreamBuilder<DocumentSnapshot>(
      stream: _userStreamFor(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 56,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox(
            height: 56,
            child: Center(child: Text('No Data Found')),
          );
        }
        var first = 'Creator';
        final greetDoc = snapshot.data;
        if (greetDoc != null && greetDoc.exists) {
          final data = greetDoc.data() as Map<String, dynamic>?;
          final email = (data?['email'] ?? '').toString();
          var name = email.split('@').first;
          if (name.isNotEmpty) {
            first =
                '${name[0].toUpperCase()}${name.length > 1 ? name.substring(1).toLowerCase() : ''}';
          }
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hey $first 👋',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: _kTextPrimary,
                height: 1.15,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Let\'s grow your Instagram 🚀',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
                height: 1.3,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return SizedBox(
      height: 148,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _QuickActionCard(
              icon: Icons.analytics_rounded,
              title: 'Your Stats',
              subtitle: 'Track performance',
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFDDD4FF),
                  Color(0xFFF2ECFF),
                  Color(0xFFFFFAFE)
                ],
              ),
              onTap: () => Navigator.pushNamed(context, '/stats'),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: _QuickActionCard(
              icon: Icons.schedule_send_rounded,
              title: 'Schedule Post',
              subtitle: 'Plan content',
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFD8E8FF),
                  Color(0xFFE8E4FF),
                  Color(0xFFF8FAFF)
                ],
              ),
              onTap: () => Navigator.pushNamed(context, '/schedule-post'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthCoachCard(BuildContext context) {
    final plan = List<String>.from(_growthCoachData?['daily_plan'] as List? ?? const []);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kHomeCardRadius),
        boxShadow: _kCardShadow(_kPrimary, blur: 14),
        border: Border.all(color: _kPrimary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.psychology_alt_outlined, color: _kPrimary),
              SizedBox(width: 8),
              Text(
                'Growth Coach',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (plan.isEmpty)
            Text('Preparing your plan...', style: TextStyle(color: Colors.grey.shade700))
          else
            ...plan.take(3).map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• $p', style: const TextStyle(fontSize: 13)),
                )),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/ai-content-engine'),
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('Open AI Engine'),
              style: FilledButton.styleFrom(backgroundColor: _kPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTryTodayCard(BuildContext context) {
    final idea = (_todaySuggestion?['idea'] ?? 'Loading today suggestion...').toString();
    final caption = (_todaySuggestion?['caption'] ?? 'Crafting caption...').toString();
    final bestTime = (_todaySuggestion?['best_time'] ?? '7:30 PM').toString();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _kPrimary.withValues(alpha: 0.12),
            _kAccentPink.withValues(alpha: 0.08),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(_kHomeCardRadius),
        border: Border.all(color: _kPrimary.withValues(alpha: 0.14)),
        boxShadow: _kCardShadow(_kPrimary, blur: 12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reel idea: $idea', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Caption: $caption', style: TextStyle(color: Colors.grey.shade800)),
          const SizedBox(height: 8),
          Text('Best time: $bestTime', style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildAiSuggestionCard(BuildContext context) {
    final window =
        (_recommendations?['bestPostingWindow'] ?? '7:00 PM – 9:00 PM')
            .toString();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kHomeCardRadius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4F3FD4),
            Color(0xFF6B52E8),
            Color(0xFF7B61FF),
            Color(0xFFA78BFA),
            Color(0xFFFF7AD9),
          ],
          stops: [0.0, 0.22, 0.45, 0.72, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_kHomeCardRadius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded,
                        color: Colors.amber.shade200, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Insight',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.schedule_send_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Best time to post',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.65,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        window,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          letterSpacing: -0.45,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Higher reach in this window',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Material(
                  color: Colors.white,
                  elevation: 6,
                  shadowColor: _kPrimary.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(_kHomeCardRadius),
                  child: InkWell(
                    onTap: () => Navigator.pushNamed(context, '/schedule-post'),
                    borderRadius: BorderRadius.circular(_kHomeCardRadius),
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Apply',
                            style: TextStyle(
                              color: _kPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              letterSpacing: 0.2,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: _kPrimary,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _retentionUnavailableCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.shade50,
            Colors.orange.shade50.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(_kHomeCardRadius),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_outlined, color: Colors.orange.shade800),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Missions & streaks need backend',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.orange.shade900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Deploy the latest `backend` to Render, then pull to refresh.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _loadRetentionCards,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ),
        ],
      ),
    );
  }
}

/// AI Content Calendar — generates a full posting plan (captions, hashtags,
/// best times) with AI. Fully functional, no Google OAuth needed.
class _HomeGoogleCalendarCard extends StatelessWidget {
  const _HomeGoogleCalendarCard();

  void _onTap(BuildContext context) {
    Navigator.pushNamed(context, '/ai-calendar');
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onTap(context),
        borderRadius: BorderRadius.circular(_kHomeCardRadius),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_kHomeCardRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _kPrimary.withValues(alpha: 0.24),
                _kAccentPink.withValues(alpha: 0.2),
                Colors.white,
              ],
            ),
            boxShadow: _kCardShadow(_kPrimary, blur: 16),
            border: Border.all(color: _kPrimary.withValues(alpha: 0.14)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(_kHomeCardRadius),
                        color: Colors.white.withValues(alpha: 0.88),
                        boxShadow: [
                          BoxShadow(
                            color: _kPrimary.withValues(alpha: 0.14),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.calendar_month_rounded,
                          color: _kPrimary, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AI Content Calendar',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: _kTextPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Plan a week of posts — captions, hashtags & best times',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _kPrimary.withValues(alpha: 0.95),
                          _kAccentPink.withValues(alpha: 0.9),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      child: Center(
                        child: Text(
                          'Generate my calendar ✨',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatefulWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: Material(
          color: Colors.transparent,
          elevation: _pressed ? 1 : 4,
          shadowColor: _kPrimary.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(_kHomeCardRadius),
          child: InkWell(
            onTap: widget.onTap,
            splashColor: _kPrimary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(_kHomeCardRadius),
            child: Ink(
              decoration: BoxDecoration(
                gradient: widget.gradient,
                borderRadius: BorderRadius.circular(_kHomeCardRadius),
                border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
                boxShadow: [
                  BoxShadow(
                    color: _kPrimary.withValues(alpha: 0.14),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                    spreadRadius: -2,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.96),
                            Colors.white.withValues(alpha: 0.78),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _kPrimary.withValues(alpha: 0.22),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(widget.icon, color: _kPrimary, size: 22),
                    ),
                    const Spacer(),
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: -0.2,
                        color: _kTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                        letterSpacing: 0.05,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

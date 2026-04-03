import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/main_navigation_wrapper.dart';
import '../widgets/notification_bell_icon.dart';
import '../widgets/monetization_status_card.dart';
import '../services/ad_service.dart';
import '../services/monetization_service.dart';
import '../models/user_model.dart';
import '../utils/admin_guard.dart';
import '../modules/whatsapp_bot/models/whatsapp_bot_storage.dart';
import '../modules/whatsapp_bot/screens/dashboard_screen.dart' show DashboardScreen;
import '../modules/whatsapp_bot/screens/intro_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AdService _adService = AdService();
  Widget? _bannerAdWidget;
  bool _isBannerAdLoaded = false;
  UserModel? _userModel;
  bool _isAdmin = false;
  StreamSubscription<DocumentSnapshot>? _userDocSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBannerAd();
      _loadUserData();
      _listenToUserDoc();
    });
  }

  @override
  void dispose() {
    _userDocSubscription?.cancel();
    super.dispose();
  }

  /// Listen to user doc so when backend revokes premium (e.g. refund) we downgrade UI without showing any error.
  void _listenToUserDoc() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _userDocSubscription?.cancel();
    _userDocSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>?;
        if (data != null) {
          setState(() {
            _userModel = UserModel.fromFirestore(data, user.uid);
          });
        }
      }
      AdminGuard().clearCache();
      AdminGuard().isAdminUser().then((isAdmin) {
        if (mounted) setState(() => _isAdmin = isAdmin);
      });
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (doc.exists && mounted) {
        final data = doc.data();
        if (data != null) {
          setState(() {
            _userModel = UserModel.fromFirestore(data, user.uid);
          });
        }
      }
      final isAdmin = await AdminGuard().isAdminUser();
      if (mounted) setState(() {
        _isAdmin = isAdmin;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[HomeScreen] _loadUserData: $e');
    }
  }

  Future<void> _loadBannerAd() async {
    // Pre-load banner ad (non-blocking)
    await _adService.loadBannerAd();
    
    // Poll for banner ad to load (check periodically)
    Future.delayed(const Duration(seconds: 1), () async {
      if (!mounted) return;
      
      final widget = await _adService.getBannerAdWidget();
      if (mounted && widget != null) {
        setState(() {
          _bannerAdWidget = widget;
          _isBannerAdLoaded = true;
        });
      } else if (mounted) {
        // Retry after 2 more seconds if not loaded yet
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

  /// Home top: greeting only. Single usage card is MonetizationStatusCard below.
  Widget _buildHomeTopCard() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Text('Hey!', style: _homeCardTitleStyle());
    }
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return Text('Hey!', style: _homeCardTitleStyle());
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final email = (data?['email'] ?? '').toString();
        String firstName = email.split('@').first;
        firstName = firstName.isNotEmpty ? '${firstName[0].toUpperCase()}${firstName.substring(1).toLowerCase()}' : 'Creator';
        return Text('Hey $firstName!', style: _homeCardTitleStyle());
      },
    );
  }

  TextStyle _homeCardTitleStyle() {
    return const TextStyle(
      color: Colors.white,
      fontSize: 26,
      fontWeight: FontWeight.bold,
      letterSpacing: -0.5,
      shadows: [
        Shadow(color: Colors.black12, offset: Offset(0, 2), blurRadius: 4),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainNavigationWrapper(
      currentIndex: 0,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/feedback'),
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('Feedback'),
        backgroundColor: const Color(0xFF7B2CBF),
        foregroundColor: Colors.white,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Purple Gradient Header
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(
                    24,
                    MediaQuery.of(context).padding.top + 24,
                    24,
                    36,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.topRight,
                      colors: [
                        Color(0xFF7B2CBF),
                        Color(0xFF9D4EDD),
                        Color(0xFFC77DFF),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7B2CBF).withOpacity(0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Bar with Logo and Notification
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              // App Logo
                              Container(
                                height: 48,
                                width: 48,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.asset(
                                    'assets/icon/app_icon.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.25),
                                          borderRadius: BorderRadius.circular(14),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.white.withOpacity(0.3),
                                              blurRadius: 10,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.auto_awesome,
                                          color: Colors.white,
                                          size: 26,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Text(
                                'InstaFlow',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 23,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black12,
                                      offset: Offset(0, 1),
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isAdmin)
                                IconButton(
                                  icon: const Icon(Icons.dashboard_rounded, color: Colors.white),
                                  onPressed: () =>
                                      Navigator.pushNamed(context, '/admin-dashboard'),
                                  tooltip: 'Admin Dashboard',
                                ),
                              const NotificationBellIcon(),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      // Greeting + Plan badge from real Firebase (UserPlanService)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildHomeTopCard(),
                                const SizedBox(height: 12),
                                const MonetizationStatusCard(),
                                const SizedBox(height: 14),
                                Text(
                                  'Ready to boost your Instagram presence?',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.95),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.2,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.1),
                                        offset: const Offset(0, 1),
                                        blurRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Main Content
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Featured Cards Row
                    Row(
                      children: [
                        Expanded(
                          child: _PurpleGradientCard(
                            icon: Icons.analytics_rounded,
                            title: 'Your Stats',
                            subtitle: 'Track engagement',
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                            ),
                            onTap: () => Navigator.pushNamed(context, '/stats'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PurpleGradientCard(
                            icon: Icons.auto_fix_high_rounded,
                            title: 'AI Tools',
                            subtitle: 'Create content',
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF9D4EDD), Color(0xFFC77DFF)],
                            ),
                            onTap: () => Navigator.pushNamed(context, '/ai-tools'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // WhatsApp Bot feature card
                    _PurpleGradientCard(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'WhatsApp Bot',
                      subtitle: 'Automate your business',
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF25D366),
                          Color(0xFF1EBE63),
                        ],
                      ),
                      onTap: () async {
                        final setup = await WhatsAppBotStorage.load();
                        if (!context.mounted) return;
                        if (setup.onboardingCompleted) {
                          await Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const DashboardScreen(),
                            ),
                          );
                          return;
                        }
                        await Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const WhatsAppBotIntroScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Section Title
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 26,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                            ),
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7B2CBF).withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Text(
                          'AI Tools Menu',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // AI Tools Grid
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.25,
                      children: [
                        _WhiteToolCard(
                          icon: Icons.tag_rounded,
                          title: 'Hashtag\nGenerator',
                          route: '/hashtags',
                        ),
                        _WhiteToolCard(
                          icon: Icons.person_outline_rounded,
                          title: 'Bio Maker',
                          route: '/bio-maker',
                        ),
                        _WhiteToolCard(
                          icon: Icons.lightbulb_outline_rounded,
                          title: 'Post Ideas',
                          route: '/ideas',
                        ),
                        _WhiteToolCard(
                          icon: Icons.trending_up_rounded,
                          title: 'Trending\nHashtags',
                          route: '/trending-hashtags',
                        ),
                        _WhiteToolCard(
                          icon: Icons.wb_sunny_rounded,
                          title: 'Daily Viral\nDrop',
                          route: '/daily-viral-drop',
                          requiresAiCheck: false,
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // AI Marketing Tools Section
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 26,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                            ),
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7B2CBF).withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Text(
                          'AI Marketing Tools',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // AI Marketing Tools Grid
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.15,
                      children: [
                        _WhiteToolCard(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: 'AI Captions',
                          route: '/ai-captions',
                        ),
                        _WhiteToolCard(
                          icon: Icons.calendar_month_rounded,
                          title: 'AI Calendar\nGenerator',
                          route: '/ai-calendar',
                        ),
                        _WhiteToolCard(
                          icon: Icons.trending_up_rounded,
                          title: 'AI Growth\nStrategy',
                          route: '/ai-strategy',
                        ),
                        _WhiteToolCard(
                          icon: Icons.analytics_rounded,
                          title: 'Niche\nAnalysis',
                          route: '/niche-analysis',
                        ),
                        _WhiteToolCard(
                          icon: Icons.link_rounded,
                          title: 'Connect Google\nCalendar',
                          route: '/google-connect',
                        ),
                        _WhiteToolCard(
                          icon: Icons.video_library_rounded,
                          title: 'Reels Script\nWriter',
                          route: '/reels-script-writer',
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),
                  ]),
                ),
              ),
              
              // Banner Ad at bottom of scroll (for free/trial users only)
              if (_isBannerAdLoaded && _bannerAdWidget != null)
                SliverToBoxAdapter(
                  child: Container(
                    alignment: Alignment.center,
                    width: double.infinity,
                    height: 50,
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (Colors.grey[200] ?? Colors.grey),
                        width: 1,
                      ),
                    ),
                    child: _bannerAdWidget,
                  ),
                ),
            ],
          ),
        ),
    );
  }
}

// Purple Gradient Card (Your Stats / AI Tools)
class _PurpleGradientCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final VoidCallback onTap;

  const _PurpleGradientCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7B2CBF).withOpacity(0.22),
              blurRadius: 14,
              offset: const Offset(0, 5),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.26),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.90),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// White Tool Card
class _WhiteToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String route;
  final bool requiresAiCheck;

  const _WhiteToolCard({
    required this.icon,
    required this.title,
    required this.route,
    this.requiresAiCheck = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        if (requiresAiCheck) {
          final allowed = await MonetizationService.checkAndConsumeAIUsage(context);
          if (!context.mounted) return;
          if (!allowed) return;
        }
        Navigator.pushNamed(context, route);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (Colors.grey[200] ?? Colors.grey),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 3),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 1),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7B2CBF).withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                    height: 1.2,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

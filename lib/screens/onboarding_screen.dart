import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';

const String _kSeenOnboarding = 'seen_onboarding';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onDone,
  });

  final VoidCallback onDone;

  /// Returns true if user has already seen onboarding.
  static Future<bool> hasSeenOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kSeenOnboarding) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Mark onboarding as seen. Call after user completes or skips.
  static Future<void> markSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kSeenOnboarding, true);
    } catch (_) {}
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<Map<String, String>> _pages = [
    {
      'title': 'AI Tools Overview',
      'body': 'Use AI to generate hashtags, captions, bios, post ideas, and more. All tools are designed to boost your Instagram presence.',
      'icon': '🤖',
    },
    {
      'title': '3 Days Free',
      'body': 'Get full access to every AI tool — captions, hashtags, reel scripts, bio maker & more — FREE for 3 days. No card needed to start.',
      'icon': '🎁',
    },
    {
      'title': 'Free Forever + Premium',
      'body': 'After your 3-day trial you still get 2 free AI uses every day. Want unlimited? Go Premium — ₹199/month (₹10 for the first week). Cancel anytime.',
      'icon': '👑',
    },
  ];

  Future<void> _finish() async {
    await OnboardingScreen.markSeen();
    // New user just finished onboarding → schedule day-1/day-2 feature tips and
    // arm the first-"wow" prompt shown on the next Home open.
    try {
      await NotificationService().scheduleOnboardingTips();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('first_wow_pending', true);
    } catch (_) {}
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Skip'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (context, i) {
                  final p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          p['icon'] ?? '',
                          style: const TextStyle(fontSize: 64),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          p['title'] ?? '',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF7B2CBF),
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          p['body'] ?? '',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Colors.grey[700],
                                height: 1.5,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == i ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == i
                          ? const Color(0xFF7B2CBF)
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (_currentPage < _pages.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      _finish();
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7B2CBF),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _currentPage < _pages.length - 1 ? 'Next' : 'Get started',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

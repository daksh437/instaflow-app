import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/main_navigation_wrapper.dart';
import '../services/monetization_service.dart';
import '../models/monetization_state.dart';

class AIToolsScreen extends StatelessWidget {
  const AIToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MainNavigationWrapper(
      currentIndex: 1,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
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
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 14),
                        const Text(
                          'AI Tools',
                          style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Create amazing content with AI',
                      style: TextStyle(color: Colors.white.withOpacity(0.95), fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  StreamBuilder<MonetizationState>(
                    stream: MonetizationService.instance.stateStream,
                    builder: (context, snapshot) {
                      final state = snapshot.data;
                      final isLocked = state != null && state.isFreeUser && state.freeUsesLeftToday == 0;

                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.3,
                            children: [
                              _WhiteToolCard(icon: Icons.tag_rounded, title: 'Hashtag\nGenerator', route: '/hashtags'),
                              _WhiteToolCard(icon: Icons.person_outline_rounded, title: 'Bio\nGenerator', route: '/bio-maker'),
                              _WhiteToolCard(icon: Icons.flash_on_rounded, title: 'Viral Hook\nCreator', route: '/viral-hook'),
                              _WhiteToolCard(icon: Icons.comment_outlined, title: 'Comment AI\nReply', route: '/comment-reply'),
                              _WhiteToolCard(icon: Icons.trending_up_rounded, title: 'Trend\nFinder', route: '/trending-hashtags'),
                              _WhiteToolCard(icon: Icons.wb_sunny_rounded, title: 'Daily Viral\nDrop', route: '/daily-viral-drop'),
                              _WhiteToolCard(icon: Icons.view_carousel_rounded, title: 'Carousel Post\nGenerator', route: '/carousel-writer'),
                            ],
                          ),
                          if (isLocked)
                            Positioned.fill(
                              child: GestureDetector(
                                onTap: () => Navigator.pushNamed(context, '/premium'),
                                child: ClipRRect(
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                                    child: Container(
                                      color: Colors.black26,
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(20),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.2),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(Icons.lock_rounded, color: Colors.white, size: 48),
                                            ),
                                            const SizedBox(height: 16),
                                            const Text(
                                              'Daily limit reached',
                                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Tap to go premium',
                                              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhiteToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String route;
  final bool requiresAiCheck;

  const _WhiteToolCard({required this.icon, required this.title, required this.route, this.requiresAiCheck = true});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        if (requiresAiCheck) {
          final allowed = await MonetizationService.checkAndConsumeAIUsage(context);
          if (!context.mounted) return;
          if (!allowed) return;
        }
        if (!context.mounted) return;
        Navigator.pushNamed(context, route);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[200] ?? Colors.grey, width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 3), spreadRadius: 0),
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 1), spreadRadius: 0),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF7B2CBF).withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 3), spreadRadius: 0),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A), height: 1.2, letterSpacing: -0.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

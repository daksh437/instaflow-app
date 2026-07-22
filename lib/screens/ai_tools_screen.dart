import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/monetization_state.dart';
import '../services/monetization_service.dart';
import '../widgets/main_navigation_wrapper.dart';

/// Matches [HomeScreen] premium palette.
const Color _kPrimary = Color(0xFF7B61FF);
const Color _kAccentPink = Color(0xFFFF7AD9);
const Color _kTextPrimary = Color(0xFF1A1A1A);
const double _kRadiusLg = 20;
const double _kRadiusSm = 16;

List<BoxShadow> _cardShadow(Color accent) => [
      BoxShadow(
        color: accent.withValues(alpha: 0.12),
        blurRadius: 18,
        offset: const Offset(0, 8),
        spreadRadius: -4,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ];

/// Soft surface for grid tiles (white → lavender tint).
BoxDecoration _softTileDecoration({double radius = _kRadiusSm}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white,
        _kPrimary.withValues(alpha: 0.07),
        _kAccentPink.withValues(alpha: 0.05),
      ],
    ),
    border: Border.all(color: _kPrimary.withValues(alpha: 0.1)),
    boxShadow: _cardShadow(_kPrimary),
  );
}

/// Press-scale only — wrap [Material]/[InkWell] so one [onTap] stays on [InkWell].
class _TapScale extends StatefulWidget {
  const _TapScale({required this.child});

  final Widget child;

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class AIToolsScreen extends StatelessWidget {
  const AIToolsScreen({super.key});

  static Future<void> _openTool(BuildContext context, String route) async {
    final allowed = await MonetizationService.checkAndConsumeAIUsage(context);
    if (!context.mounted) return;
    if (!allowed) return;
    Navigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return MainNavigationWrapper(
      currentIndex: 1,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F4FF),
        body: StreamBuilder<MonetizationState>(
          stream: MonetizationService.instance.stateStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: _kPrimary),
              );
            }

            final state = snapshot.data;
            final locked = state != null && state.isFreeUser && !state.canUseAi;
            final showLimitBanner = locked;

            return Column(
              children: [
                Expanded(
                  child: Container(
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
                    child: ListView(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: EdgeInsets.fromLTRB(
                        16,
                        MediaQuery.paddingOf(context).top + 12,
                        16,
                        24 + bottomInset + 72,
                      ),
                      children: [
                        _HeaderRow(state: state),
                        const SizedBox(height: 22),
                        const _SectionHeader(
                          icon: Icons.star_rounded,
                          title: 'Core AI Tools',
                          caption: 'Most-used AI features',
                        ),
                        const SizedBox(height: 14),
                        _FeaturedToolCard(
                          icon: Icons.auto_awesome_rounded,
                          title: 'AI Captions',
                          subtitle: 'Generate engaging captions',
                          locked: locked,
                          onTap: () => _openTool(context, '/ai-captions'),
                        ),
                        const SizedBox(height: 12),
                        _FeaturedToolCard(
                          icon: Icons.tag_rounded,
                          title: 'Hashtag Generator',
                          subtitle: 'Find viral hashtags',
                          locked: locked,
                          onTap: () => _openTool(context, '/hashtags'),
                        ),
                        const SizedBox(height: 12),
                        _FeaturedToolCard(
                          icon: Icons.movie_creation_outlined,
                          title: 'Reels Script',
                          subtitle: 'Write engaging scripts',
                          locked: locked,
                          onTap: () => _openTool(context, '/reels-script'),
                        ),
                        const SizedBox(height: 12),
                        _FeaturedToolCard(
                          icon: Icons.hub_rounded,
                          title: 'AI Content Engine',
                          subtitle: 'One-shot full content strategy',
                          locked: locked,
                          onTap: () => _openTool(context, '/ai-content-engine'),
                        ),
                        const SizedBox(height: 22),
                        _RecommendedCard(
                          locked: locked,
                          onOpen: () => _openTool(context, '/viral-hook'),
                        ),
                        const SizedBox(height: 26),
                        const _SectionHeader(
                          icon: Icons.edit_note_rounded,
                          title: 'Content',
                          caption: 'Captions, tags & ideas',
                        ),
                        const SizedBox(height: 14),
                        _CategoryGrid(
                          locked: locked,
                          items: const [
                            _GridItem(
                              icon: Icons.chat_bubble_outline_rounded,
                              title: 'Captions',
                              route: '/ai-captions',
                            ),
                            _GridItem(
                              icon: Icons.tag_rounded,
                              title: 'Hashtags',
                              route: '/hashtags',
                            ),
                            _GridItem(
                              icon: Icons.person_outline_rounded,
                              title: 'Bio Generator',
                              route: '/bio-maker',
                            ),
                            _GridItem(
                              icon: Icons.lightbulb_outline_rounded,
                              title: 'Post Ideas',
                              route: '/ideas',
                            ),
                          ],
                          onOpen: _openTool,
                        ),
                        const SizedBox(height: 26),
                        const _SectionHeader(
                          icon: Icons.rocket_launch_rounded,
                          title: 'Growth',
                          caption: 'Reach & engagement',
                        ),
                        const SizedBox(height: 14),
                        _CategoryGrid(
                          locked: locked,
                          items: const [
                            _GridItem(
                              icon: Icons.flash_on_rounded,
                              title: 'Viral Hook',
                              route: '/viral-hook',
                            ),
                            _GridItem(
                              icon: Icons.trending_up_rounded,
                              title: 'Trending Hashtags',
                              route: '/trending-hashtags',
                            ),
                            _GridItem(
                              icon: Icons.comment_outlined,
                              title: 'Comment AI Reply',
                              route: '/comment-reply',
                            ),
                          ],
                          onOpen: _openTool,
                        ),
                        const SizedBox(height: 26),
                        const _SectionHeader(
                          icon: Icons.hub_rounded,
                          title: 'Strategy',
                          caption: 'Plan, analyze & sync',
                        ),
                        const SizedBox(height: 14),
                        _StrategyToolsGrid(
                          locked: locked,
                          onOpenTool: _openTool,
                        ),
                        const SizedBox(height: 26),
                        const _SectionHeader(
                          icon: Icons.apps_rounded,
                          title: 'More tools',
                          caption: 'Carousel, DMs & more',
                        ),
                        const SizedBox(height: 14),
                        _CategoryGrid(
                          locked: locked,
                          items: const [
                            _GridItem(
                              icon: Icons.view_carousel_rounded,
                              title: 'Carousel',
                              route: '/carousel-writer',
                            ),
                            _GridItem(
                              icon: Icons.mail_outline_rounded,
                              title: 'DM Auto Reply',
                              route: '/dm-auto-reply',
                            ),
                            _GridItem(
                              icon: Icons.edit_rounded,
                              title: 'Rewrite',
                              route: '/rewrite-tool',
                            ),
                            _GridItem(
                              icon: Icons.auto_stories_outlined,
                              title: 'Story Ideas',
                              route: '/story-ideas',
                            ),
                            _GridItem(
                              icon: Icons.analytics_outlined,
                              title: 'Niche Analysis',
                              route: '/niche-analysis',
                            ),
                            _GridItem(
                              icon: Icons.schedule_rounded,
                              title: 'Best time to post',
                              route: '/best_time',
                            ),
                          ],
                          onOpen: _openTool,
                        ),
                      ],
                    ),
                  ),
                ),
                if (showLimitBanner) const _DailyLimitBanner(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.caption,
  });

  final IconData icon;
  final String title;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [
                _kPrimary.withValues(alpha: 0.18),
                _kAccentPink.withValues(alpha: 0.12),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: _kPrimary.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: _kPrimary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.35,
                  color: _kTextPrimary,
                ),
              ),
              if (caption != null) ...[
                const SizedBox(height: 4),
                Text(
                  caption!,
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
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.state});

  final MonetizationState? state;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _kPrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: _kPrimary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'AI Tools',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: _kTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Create, grow & automate your Instagram',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _UsesBadge(state: state),
      ],
    );
  }
}

class _UsesBadge extends StatelessWidget {
  const _UsesBadge({required this.state});

  final MonetizationState? state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    if (s == null) {
      return const SizedBox.shrink();
    }
    if (s.isPremiumActive) {
      return _chip(
        'Pro',
        const Color(0xFFE8F5E9),
        const Color(0xFF2E7D32),
      );
    }
    if (s.isTrialActive) {
      return _chip(
        'Trial',
        _kPrimary.withValues(alpha: 0.1),
        _kPrimary,
      );
    }
    return _chip(
      'Free uses left: ${s.freeUsesLeftToday}',
      _kPrimary.withValues(alpha: 0.1),
      _kPrimary,
    );
  }

  Widget _chip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _FeaturedToolCard extends StatelessWidget {
  const _FeaturedToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.locked,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _TapScale(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_kRadiusLg),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_kRadiusLg),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF7B61FF),
                  Color(0xFF9D7DFF),
                  Color(0xFFFF7AD9),
                ],
              ),
              boxShadow: _cardShadow(_kPrimary),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white.withValues(alpha: 0.85),
                        size: 18,
                      ),
                    ],
                  ),
                ),
                if (locked) _LockOverlay(radius: _kRadiusLg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecommendedCard extends StatelessWidget {
  const _RecommendedCard({
    required this.locked,
    required this.onOpen,
  });

  final bool locked;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return _TapScale(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(_kRadiusLg),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_kRadiusLg),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _kPrimary.withValues(alpha: 0.1),
                  _kAccentPink.withValues(alpha: 0.08),
                  Colors.white,
                ],
              ),
              border: Border.all(color: _kPrimary.withValues(alpha: 0.15)),
              boxShadow: _cardShadow(_kPrimary),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _kPrimary.withValues(alpha: 0.22),
                                  _kAccentPink.withValues(alpha: 0.16),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.local_fire_department_rounded,
                              color: _kPrimary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Recommended for you',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Try Viral Hook to increase engagement',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _kTextPrimary,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: onOpen,
                        icon: const Icon(Icons.bolt_rounded, size: 20),
                        label: const Text('Open Viral Hook'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _kPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (locked) _LockOverlay(radius: _kRadiusLg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Strategy + niche tools in one 2×2 grid (Google Calendar lives only on Home).
class _StrategyToolsGrid extends StatelessWidget {
  const _StrategyToolsGrid({
    required this.locked,
    required this.onOpenTool,
  });

  final bool locked;
  final Future<void> Function(BuildContext context, String route) onOpenTool;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.28,
      children: [
        _SmallToolCard(
          icon: Icons.calendar_month_rounded,
          title: 'Content Calendar',
          locked: locked,
          onTap: () => onOpenTool(context, '/ai-calendar'),
        ),
        _SmallToolCard(
          icon: Icons.manage_search_rounded,
          title: 'Hashtag Analyzer',
          locked: locked,
          onTap: () => onOpenTool(context, '/hashtag'),
        ),
        _SmallToolCard(
          icon: Icons.insights_rounded,
          title: 'AI Strategy',
          locked: locked,
          onTap: () => onOpenTool(context, '/ai-strategy'),
        ),
        _SmallToolCard(
          icon: Icons.analytics_outlined,
          title: 'Niche Analysis',
          locked: locked,
          onTap: () => onOpenTool(context, '/niche-analysis'),
        ),
      ],
    );
  }
}

class _GridItem {
  const _GridItem({
    required this.icon,
    required this.title,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String route;
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.items,
    required this.locked,
    required this.onOpen,
  });

  final List<_GridItem> items;
  final bool locked;
  final Future<void> Function(BuildContext context, String route) onOpen;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.3,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return _SmallToolCard(
          icon: item.icon,
          title: item.title,
          locked: locked,
          onTap: () => onOpen(context, item.route),
        );
      },
    );
  }
}

class _SmallToolCard extends StatelessWidget {
  const _SmallToolCard({
    required this.icon,
    required this.title,
    required this.locked,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _TapScale(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_kRadiusSm),
          child: Ink(
            decoration: _softTileDecoration(),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _kPrimary.withValues(alpha: 0.14),
                              _kAccentPink.withValues(alpha: 0.1),
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: _kPrimary, size: 22),
                      ),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _kTextPrimary,
                          height: 1.2,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (locked) _LockOverlay(radius: _kRadiusSm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LockOverlay extends StatelessWidget {
  const _LockOverlay({required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
          child: Container(
            color: Colors.white.withValues(alpha: 0.35),
            alignment: Alignment.center,
            child: Icon(
              Icons.lock_rounded,
              size: 28,
              color: _kPrimary.withValues(alpha: 0.85),
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyLimitBanner extends StatelessWidget {
  const _DailyLimitBanner();

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Material(
      elevation: 8,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/premium'),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + pad.bottom),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _kPrimary.withValues(alpha: 0.12),
                _kAccentPink.withValues(alpha: 0.08),
              ],
            ),
            border: Border(
              top: BorderSide(color: _kPrimary.withValues(alpha: 0.2)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                const Icon(Icons.workspace_premium_outlined, color: _kPrimary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Daily limit reached – Upgrade to Pro',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _kTextPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

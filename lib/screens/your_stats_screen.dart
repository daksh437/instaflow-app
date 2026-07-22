import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/instagram_dashboard_models.dart';
import '../providers/instagram_provider.dart';
import '../widgets/main_navigation_wrapper.dart';

const Color _kPrimary = Color(0xFF7B61FF);
const Color _kAccentPink = Color(0xFFFF7AD9);
const double _kRadius = 18;

class YourStatsScreen extends StatefulWidget {
  const YourStatsScreen({super.key});

  @override
  State<YourStatsScreen> createState() => _YourStatsScreenState();
}

class _YourStatsScreenState extends State<YourStatsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<InstagramProvider>().bootstrapStats();
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// Relative label, e.g. "Last updated: 5 minutes ago".
  String _formatLastUpdated(DateTime? t) {
    if (t == null) return 'Last updated: never';
    final local = t.toLocal();
    final diff = DateTime.now().difference(local);
    if (diff.isNegative) {
      return 'Last updated: ${DateFormat('MMM d, y • h:mm a').format(local)}';
    }
    if (diff.inSeconds < 45) return 'Last updated: just now';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return 'Last updated: $m ${m == 1 ? 'minute' : 'minutes'} ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return 'Last updated: $h ${h == 1 ? 'hour' : 'hours'} ago';
    }
    if (diff.inDays < 7) {
      final d = diff.inDays;
      return 'Last updated: $d ${d == 1 ? 'day' : 'days'} ago';
    }
    return 'Last updated: ${DateFormat('MMM d, y • h:mm a').format(local)}';
  }

  @override
  Widget build(BuildContext context) {
    return MainNavigationWrapper(
      currentIndex: 0,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F4FF),
        appBar: AppBar(
          title: const Text('Your Stats'),
          backgroundColor: const Color(0xFFF7F4FF),
          foregroundColor: const Color(0xFF1A1A1A),
          elevation: 0,
        ),
        body: Container(
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
          child: Consumer<InstagramProvider>(
            builder: (context, provider, _) {
              return RefreshIndicator(
                color: _kPrimary,
                onRefresh: () => provider.bootstrapStats(forceRefresh: true),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    if (provider.isLoading || provider.isConnecting)
                      _DashboardSkeleton(pulse: _pulse)
                    else if (provider.viewState ==
                        InstagramStatsViewState.error) ...[
                      _ErrorCard(
                        message: provider.error ?? 'Failed to load stats',
                        onRetry: () =>
                            provider.bootstrapStats(forceRefresh: true),
                      ),
                    ] else if (!provider.isConnected ||
                        provider.viewState ==
                            InstagramStatsViewState.notConnected) ...[
                      _ConnectCard(
                        connecting: provider.isConnecting,
                        onConnect: () => provider.connect(),
                      ),
                    ] else ...[
                      _ScheduleCta(onSchedule: () {
                        Navigator.pushNamed(context, '/schedule-post');
                      }),
                      const SizedBox(height: 8),
                      Text(
                        _formatLastUpdated(provider.lastSync),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      ...switch (provider.lastSync) {
                        null => const <Widget>[],
                        final sync => [
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('MMM d, y • h:mm a')
                                  .format(sync.toLocal()),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                      },
                      const SizedBox(height: 6),
                      Text(
                        'Engagement % is estimated from your profile activity. Follower chart is a simple 7-day trend.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (provider.followers == 0 && provider.posts == 0)
                        _EmptyMetricsCard(
                          onRefresh: () =>
                              provider.refreshStats(forceRefresh: true),
                        )
                      else ...[
                        _TopStatsGrid(provider: provider),
                        const SizedBox(height: 20),
                        _FollowerChartCard(series: provider.followerSeries7),
                        const SizedBox(height: 20),
                        _AiInsightsCard(lines: provider.insights),
                        const SizedBox(height: 20),
                        _TopPostsSection(posts: provider.topPosts),
                      ],
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ScheduleCta extends StatelessWidget {
  const _ScheduleCta({required this.onSchedule});

  final VoidCallback onSchedule;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onSchedule,
      icon: const Icon(Icons.schedule_send_rounded),
      label: const Text('Schedule post'),
      style: FilledButton.styleFrom(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

String _accountTypeBadgeLabel(String raw) {
  final u = raw.toUpperCase().trim();
  if (u.isEmpty) return '';
  if (u.contains('CREATOR') || u == 'MEDIA_CREATOR') return 'Creator';
  if (u.contains('BUSINESS')) return 'Business';
  if (u.contains('PERSONAL')) return 'Personal';
  if (raw.length > 18) return '${raw.substring(0, 18)}…';
  return raw;
}

String _formatEngagementPercent(double rate) {
  if (rate.isNaN || rate.isInfinite) return '—';
  return '${rate.clamp(0, 999.9).toStringAsFixed(1)}%';
}

class _TopStatsGrid extends StatelessWidget {
  const _TopStatsGrid({required this.provider});

  final InstagramProvider provider;

  @override
  Widget build(BuildContext context) {
    final badge = _accountTypeBadgeLabel(provider.accountType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overview',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Followers',
                value: _fmtNum(provider.followers),
                icon: Icons.people_alt_rounded,
                gradient: const [Color(0xFF7B61FF), Color(0xFF9D7DFF)],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                label: 'Posts',
                value: _fmtNum(provider.posts),
                icon: Icons.grid_on_rounded,
                gradient: const [Color(0xFF9D7DFF), Color(0xFFFF7AD9)],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Following',
                value: _fmtNum(provider.following),
                icon: Icons.person_add_alt_1_rounded,
                gradient: const [Color(0xFF5E4AE3), Color(0xFF7B61FF)],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                label: 'Engagement',
                value: _formatEngagementPercent(provider.engagementRate),
                icon: Icons.trending_up_rounded,
                gradient: const [Color(0xFF4A3AE0), Color(0xFF7B61FF)],
              ),
            ),
          ],
        ),
        if (badge.isNotEmpty) ...[
          const SizedBox(height: 12),
          _AccountTypeBadge(label: badge),
        ],
      ],
    );
  }

  String _fmtNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
  });

  final String label;
  final String value;
  final IconData icon;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 10),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 22),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowerChartCard extends StatelessWidget {
  const _FollowerChartCard({required this.series});

  final List<double> series;

  @override
  Widget build(BuildContext context) {
    if (series.length < 2) {
      return const SizedBox.shrink();
    }
    final minV = series.reduce(math.min);
    final maxV = series.reduce(math.max);
    final pad = (maxV - minV).abs() < 1 ? 4.0 : (maxV - minV) * 0.15;
    final minY = math.max(0.0, minV - pad).toDouble();
    final maxY = (maxV + pad).toDouble();

    final spots = <FlSpot>[];
    for (var i = 0; i < series.length; i++) {
      spots.add(FlSpot(i.toDouble(), series[i]));
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kRadius),
        border: Border.all(color: _kPrimary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Follower trend',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Last 7 days (estimated curve)',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 6,
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY - minY) / 3,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: Colors.grey.shade200,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, m) => Text(
                        v >= 1000
                            ? '${(v / 1000).toStringAsFixed(1)}k'
                            : v.toInt().toString(),
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade600),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (v, m) {
                        final i = v.toInt();
                        if (i < 0 || i > 6) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'D${i + 1}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: _kPrimary,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _kPrimary.withValues(alpha: 0.25),
                          _kPrimary.withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiInsightsCard extends StatelessWidget {
  const _AiInsightsCard({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kRadius + 1),
        gradient: const LinearGradient(
          colors: [_kPrimary, _kAccentPink],
        ),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_kRadius),
          color: const Color(0xFF1A1030),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _kAccentPink.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 10),
                const Text(
                  'AI insights',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...lines.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.bolt_rounded,
                        size: 18, color: _kAccentPink.withValues(alpha: 0.95)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          height: 1.45,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountTypeBadge extends StatelessWidget {
  const _AccountTypeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kRadius),
        border: Border.all(color: _kPrimary.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.workspace_premium_outlined, color: _kPrimary, size: 22),
          const SizedBox(width: 10),
          Text(
            'Account type',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _kPrimary.withValues(alpha: 0.12),
                  _kAccentPink.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kPrimary.withValues(alpha: 0.2)),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopPostsSection extends StatelessWidget {
  const _TopPostsSection({required this.posts});

  final List<InstagramTopPostDisplay> posts;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top posts',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Placeholders for your recent content types',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),
        ...posts.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TopPostRow(post: p),
          ),
        ),
      ],
    );
  }
}

class _TopPostRow extends StatelessWidget {
  const _TopPostRow({required this.post});

  final InstagramTopPostDisplay post;

  @override
  Widget build(BuildContext context) {
    final url = post.thumbnailUrl;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kRadius),
        border: Border.all(color: _kPrimary.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 64,
              height: 64,
              child: url != null && url.startsWith('http')
                  ? Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                    )
                  : _thumbPlaceholder(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Content highlight',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      color: const Color(0xFFF0EDFF),
      child: const Icon(Icons.image_outlined, color: _kPrimary, size: 32),
    );
  }
}

class _EmptyMetricsCard extends StatelessWidget {
  const _EmptyMetricsCard({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kRadius),
        border: Border.all(color: _kPrimary.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Icon(Icons.insights_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No profile metrics yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Once Instagram returns follower and media counts, your dashboard will fill in.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton({required this.pulse});

  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final o = 0.35 + pulse.value * 0.25;
        Widget bar(double h, [double w = double.infinity]) => Opacity(
              opacity: o,
              child: Container(
                height: h,
                width: w,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bar(48),
            const SizedBox(height: 16),
            bar(14, 120),
            const SizedBox(height: 8),
            bar(12, 200),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: bar(110)),
                const SizedBox(width: 12),
                Expanded(child: bar(110)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: bar(110)),
                const SizedBox(width: 12),
                Expanded(child: bar(110)),
              ],
            ),
            const SizedBox(height: 20),
            bar(220),
          ],
        );
      },
    );
  }
}

class _ConnectCard extends StatelessWidget {
  const _ConnectCard({required this.connecting, required this.onConnect});

  final bool connecting;
  final Future<bool> Function() onConnect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kRadius),
        border: Border.all(color: _kPrimary.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.insights_rounded, size: 44, color: _kPrimary),
          const SizedBox(height: 14),
          Text(
            'Connect Instagram to unlock your analytics dashboard — followers, trends, and insights.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: connecting ? null : () => onConnect(),
            style: FilledButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(connecting ? 'Connecting…' : 'Connect Instagram'),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kRadius),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 40, color: Colors.red.shade400),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

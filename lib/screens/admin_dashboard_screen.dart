import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/admin_dashboard_service.dart';
import '../utils/admin_guard.dart';
import '../widgets/error_retry_card.dart';
import 'admin/admin_user_list_screen.dart';
import 'admin/admin_user_manage_screen.dart';
import 'admin/admin_premium_users_screen.dart';
import 'admin/admin_trial_users_screen.dart';
import 'admin/admin_active_users_screen.dart';
import 'admin/admin_ai_usage_screen.dart';
import 'admin/admin_refunded_screen.dart';
import 'admin/admin_notifications_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminDashboardService _dashboard = AdminDashboardService();
  final AdminGuard _adminGuard = AdminGuard();

  bool _adminCheckDone = false;
  bool _isAdmin = false;
  Map<String, int> _purchaseBreakdown = {};
  int _refundedCount = 0;
  int _todayAiUses = 0;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
    _loadBreakdown();
  }

  Future<void> _checkAdmin() async {
    final isAdmin = await _adminGuard.isAdminUser();
    if (!mounted) return;
    setState(() {
      _adminCheckDone = true;
      _isAdmin = isAdmin;
    });
    if (!isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showAdminRequiredDialog(context);
      });
    }
  }

  Future<void> _loadBreakdown() async {
    try {
      final breakdown = await _dashboard.getPurchaseBreakdown();
      final refunded = await _dashboard.getRefundedCount();
      final aiUses = await _dashboard.getTodayAiUsageCount();
      if (mounted) {
        setState(() {
          _purchaseBreakdown = breakdown;
          _refundedCount = refunded;
          _todayAiUses = aiUses;
        });
      }
    } catch (_) {}
  }

  void _showAdminRequiredDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Admin access required'),
        content: const Text(
          'You need admin privileges to access this screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _navigateTo(String route, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_adminCheckDone) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text('Admin'),
          backgroundColor: const Color(0xFF7B2CBF),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!_isAdmin) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text('Admin'),
          backgroundColor: const Color(0xFF7B2CBF),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text(
            'Admin only',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: const Color(0xFF7B2CBF),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _navigateTo('admin-notifications', const AdminNotificationsScreen()),
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Notifications',
          ),
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/admin-feedback'),
            icon: const Icon(Icons.feedback_outlined, color: Colors.white, size: 20),
            label: const Text('Feedback', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: StreamBuilder<AdminDashboardSnapshot>(
        stream: _dashboard.dashboardStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorRetryCard(
              error: snapshot.error,
              onRetry: () => setState(() {}),
            );
          }
          final data = snapshot.data ?? AdminDashboardSnapshot.zero();
          final loading = snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData;

          return RefreshIndicator(
            onRefresh: () async {
              await _loadBreakdown();
              setState(() {});
            },
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AdminUserManageScreen()),
                          ),
                          icon: const Icon(Icons.manage_accounts_rounded),
                          label: const Text('Manage a user (grant/revoke premium)'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF7B2CBF),
                            minimumSize: const Size.fromHeight(52),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildMetricGrid(data),
                        const SizedBox(height: 24),
                        _buildChartCard(),
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildMetricGrid(AdminDashboardSnapshot data) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: [
        _MetricCard(
          title: 'Total Users',
          value: '${data.totalUsers}',
          icon: Icons.people_rounded,
          color: const Color(0xFF7B2CBF),
          onTap: () => _navigateTo('users', const AdminUserListScreen()),
        ),
        _MetricCard(
          title: 'Premium Users',
          value: '${data.premiumUsers}',
          icon: Icons.workspace_premium_rounded,
          color: const Color(0xFF9D4EDD),
          onTap: () => _navigateTo('premium', const AdminPremiumUsersScreen()),
        ),
        _MetricCard(
          title: 'Trial Active',
          value: '${data.trialActive}',
          icon: Icons.schedule_rounded,
          color: const Color(0xFF6A1B9A),
          onTap: () => _navigateTo('trial', const AdminTrialUsersScreen()),
        ),
        _MetricCard(
          title: 'Trial → Premium %',
          value: data.totalUsers > 0
              ? '${data.conversionPct.toStringAsFixed(2)}%'
              : '0%',
          icon: Icons.trending_up_rounded,
          color: (Colors.green[700] ?? Colors.green),
          onTap: null,
        ),
        _MetricCard(
          title: 'Daily Active',
          value: '${data.dailyActiveUsers}',
          icon: Icons.today_rounded,
          color: (Colors.orange[700] ?? Colors.orange),
          onTap: () => _navigateTo('active', const AdminActiveUsersScreen()),
        ),
        _MetricCard(
          title: 'Today AI Uses',
          value: '$_todayAiUses',
          icon: Icons.smart_toy_rounded,
          color: (Colors.blue[700] ?? Colors.blue),
          onTap: () => _navigateTo('ai', const AdminAIUsageScreen()),
        ),
        _MetricCard(
          title: 'Refunded Users',
          value: '$_refundedCount',
          icon: Icons.money_off_rounded,
          color: (Colors.red[700] ?? Colors.red),
          onTap: () => _navigateTo('refunded', const AdminRefundedScreen()),
        ),
      ],
    );
  }

  Widget _buildChartCard() {
    const durations = ['1m', '3m', '6m', '12m'];
    final spots = <FlSpot>[];
    double x = 0;
    for (final d in durations) {
      spots.add(FlSpot(x, (_purchaseBreakdown[d] ?? 0).toDouble()));
      x += 1;
    }
    final maxY = spots.isEmpty
        ? 5.0
        : (spots.map((s) => s.y).reduce((a, b) => a > b ? a : b).toDouble() + 1).clamp(1.0, double.infinity);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Plan Purchases',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i >= 0 && i < durations.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                durations[i],
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                        reservedSize: 28,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: (Colors.grey[200] ?? Colors.grey),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: spots
                      .asMap()
                      .entries
                      .map((e) => BarChartGroupData(
                            x: e.key,
                            barRods: [
                              BarChartRodData(
                                toY: e.value.y,
                                color: const Color(0xFF7B2CBF),
                                width: 24,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                              ),
                            ],
                            showingTooltipIndicators: [],
                          ))
                      .toList(),
                ),
                duration: const Duration(milliseconds: 300),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: child,
      );
    }
    return child;
  }
}

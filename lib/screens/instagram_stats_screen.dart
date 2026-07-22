import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/instagram_provider.dart';
import '../services/scheduler_service.dart';

class InstagramStatsScreen extends StatefulWidget {
  const InstagramStatsScreen({super.key});

  @override
  State<InstagramStatsScreen> createState() => _InstagramStatsScreenState();
}

class _InstagramStatsScreenState extends State<InstagramStatsScreen> {
  final SchedulerService _scheduler = SchedulerService();

  int _schedPending = 0;
  int _schedFailed = 0;
  int _schedPosted = 0;
  String? _schedPeakHourLocal;
  String? _schedLoadErr;
  bool _schedLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<InstagramProvider>().bootstrapStats();
      _loadSchedulerSummary();
    });
  }

  Future<void> _loadSchedulerSummary() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() {
      _schedLoading = true;
      _schedLoadErr = null;
    });
    try {
      final posts = await _scheduler.getScheduledPosts(uid);
      var p = 0;
      var f = 0;
      var o = 0;
      final hourBuckets = <int, int>{};
      for (final x in posts) {
        final s = '${x['status'] ?? 'pending'}';
        if (s == 'failed') {
          f++;
        } else if (s == 'posted') {
          o++;
        } else {
          p++;
        }
        final dt = DateTime.tryParse('${x['scheduledAt'] ?? ''}')?.toLocal();
        if (dt != null) {
          hourBuckets[dt.hour] = (hourBuckets[dt.hour] ?? 0) + 1;
        }
      }
      String? peak;
      if (hourBuckets.isNotEmpty) {
        final best = hourBuckets.entries.reduce((a, b) => a.value >= b.value ? a : b);
        final t = DateTime(2020, 1, 1, best.key);
        peak = DateFormat.jm().format(t);
      }
      if (!mounted) return;
      setState(() {
        _schedPending = p;
        _schedFailed = f;
        _schedPosted = o;
        _schedPeakHourLocal = peak;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _schedLoadErr = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _schedLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Instagram Stats')),
      body: Consumer<InstagramProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!provider.isConnected) {
            return Center(
              child: ElevatedButton(
                onPressed: () => provider.connect(),
                child: const Text('Connect Instagram'),
              ),
            );
          }
          final err = provider.error;
          if (err != null && err.isNotEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(err, textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => provider.refreshStats(forceRefresh: true),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final lastIg = provider.lastSync;

          return RefreshIndicator(
            onRefresh: () async {
              await provider.refreshStats(forceRefresh: true);
              await _loadSchedulerSummary();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.people),
                    title: const Text('Followers'),
                    trailing: Text(provider.followers.toString()),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.grid_on),
                    title: const Text('Posts (profile)'),
                    trailing: Text(provider.posts.toString()),
                  ),
                ),
                if (lastIg != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.sync),
                      title: const Text('Profile stats last refreshed'),
                      subtitle: Text(DateFormat('MMM d, yyyy • hh:mm a').format(lastIg.toLocal())),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  'Scheduling (your account)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (_schedLoading)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (_schedLoadErr case final String schedErr)
                  Card(
                    color: Colors.orange.shade50,
                    child: ListTile(
                      leading: const Icon(Icons.warning_amber_outlined),
                      title: Text(schedErr),
                      subtitle: const Text('Pull to refresh to retry.'),
                    ),
                  )
                else ...[
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.schedule, color: Colors.amber.shade800),
                          title: const Text('Pending'),
                          trailing: Text('$_schedPending'),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                          title: const Text('Posted (scheduler)'),
                          trailing: Text('$_schedPosted'),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.error_outline, color: Colors.red),
                          title: const Text('Failed'),
                          trailing: Text('$_schedFailed'),
                        ),
                      ],
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.insights_outlined),
                      title: const Text('Most common schedule time'),
                      subtitle: Text(
                        _schedPeakHourLocal == null
                            ? 'Not enough scheduled posts yet to infer a pattern.'
                            : 'Hour bucket with the most scheduled posts (device local): $_schedPeakHourLocal',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

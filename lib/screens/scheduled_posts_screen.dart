import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'edit_schedule_post_screen.dart';
import '../services/scheduler_service.dart';

class ScheduledPostsScreen extends StatefulWidget {
  const ScheduledPostsScreen({super.key});

  @override
  State<ScheduledPostsScreen> createState() => _ScheduledPostsScreenState();
}

class _ScheduledPostsScreenState extends State<ScheduledPostsScreen> {
  final SchedulerService _schedulerService = SchedulerService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _posts = const [];

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final posts = await _schedulerService.getScheduledPosts(user.uid);
      if (!mounted) return;
      setState(() {
        _posts = posts;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text('Please login first')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Scheduled Posts'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadPosts,
        child: Builder(
          builder: (_) {
            if (_loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_error case final String errMsg) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text(errMsg)),
                  const SizedBox(height: 12),
                  Center(
                    child: OutlinedButton(
                      onPressed: _loadPosts,
                      child: const Text('Retry'),
                    ),
                  ),
                ],
              );
            }
            if (_posts.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 180),
                  Center(child: Icon(Icons.schedule, size: 64, color: Colors.grey)),
                  SizedBox(height: 16),
                  Center(
                    child: Text(
                      'No scheduled posts',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _posts.length,
              itemBuilder: (context, index) {
                final data = _posts[index];
                final scheduledTime = DateTime.tryParse('${data['scheduledAt'] ?? ''}')?.toLocal();
                final postedAt = DateTime.tryParse('${data['postedAt'] ?? ''}')?.toLocal();
                final status = '${data['status'] ?? 'pending'}';
                final failureReason = '${data['lastError'] ?? ''}'.trim();
                final errCode = '${data['lastErrorCode'] ?? ''}'.trim();

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 4,
                          color: _statusBarColor(status),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        '${(data['imageUrls'] as List?)?.isNotEmpty == true ? (data['imageUrls'] as List).first : (data['imageUrl'] ?? '')}',
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 56,
                                          height: 56,
                                          color: Colors.grey.shade200,
                                          child: const Icon(Icons.image_outlined),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${data['caption'] ?? 'No caption'}',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            scheduledTime == null
                                                ? 'Scheduled: —'
                                                : DateFormat('MMM dd, yyyy • hh:mm a').format(scheduledTime),
                                            style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                                          ),
                                          if (postedAt != null)
                                            Text(
                                              'Posted: ${DateFormat('MMM dd, yyyy • hh:mm a').format(postedAt)}',
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        _StatusChip(status: status),
                                        if (errCode.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            errCode,
                                            style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                if (status == 'failed' && failureReason.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      failureReason,
                                      style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                                    ),
                                  ),
                                if (status == 'failed')
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: () async {
                                        final uid = FirebaseAuth.instance.currentUser?.uid;
                                        if (uid == null) return;
                                        try {
                                          await _schedulerService.retryFailedPost(
                                            userId: uid,
                                            postId: '${data['id']}',
                                          );
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Retry queued — will publish in a few minutes',
                                              ),
                                            ),
                                          );
                                          _loadPosts();
                                        } catch (e) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                e.toString().replaceFirst('Exception: ', ''),
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Retry'),
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    TextButton.icon(
                                      onPressed: status == 'pending'
                                          ? () async {
                                              final changed = await Navigator.push<bool>(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => EditSchedulePostScreen(post: data),
                                                ),
                                              );
                                              if (changed == true) _loadPosts();
                                            }
                                          : null,
                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                      label: const Text('Edit'),
                                    ),
                                    TextButton.icon(
                                      onPressed: () async {
                                        final uid = FirebaseAuth.instance.currentUser?.uid;
                                        if (uid == null) return;
                                        await _schedulerService.deleteScheduledPost(
                                          userId: uid,
                                          postId: '${data['id']}',
                                        );
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Scheduled post deleted')),
                                        );
                                        _loadPosts();
                                      },
                                      icon: const Icon(Icons.delete_outline, size: 18),
                                      label: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/schedule-post'),
        icon: const Icon(Icons.add),
        label: const Text('Schedule Post'),
      ),
    );
  }
}

Color _statusBarColor(String status) {
  switch (status) {
    case 'posted':
      return Colors.green;
    case 'failed':
      return Colors.red;
    default:
      return Colors.amber.shade700;
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case 'posted':
        bg = Colors.green.shade100;
        fg = Colors.green.shade900;
        break;
      case 'failed':
        bg = Colors.red.shade100;
        fg = Colors.red.shade900;
        break;
      default:
        bg = Colors.orange.shade100;
        fg = Colors.orange.shade900;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}


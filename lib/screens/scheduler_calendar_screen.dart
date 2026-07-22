import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'edit_schedule_post_screen.dart';
import '../services/scheduler_service.dart';

class SchedulerCalendarScreen extends StatefulWidget {
  const SchedulerCalendarScreen({super.key});

  @override
  State<SchedulerCalendarScreen> createState() => _SchedulerCalendarScreenState();
}

class _SchedulerCalendarScreenState extends State<SchedulerCalendarScreen> {
  final SchedulerService _schedulerService = SchedulerService();
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _posts = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _loading = true);
    try {
      final posts = await _schedulerService.getScheduledPosts(uid);
      if (!mounted) return;
      setState(() => _posts = posts);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static String _thumbUrl(Map<String, dynamic> p) {
    final urls = p['imageUrls'];
    if (urls is List && urls.isNotEmpty) return '${urls.first}';
    return '${p['imageUrl'] ?? ''}';
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'posted':
        return Colors.green;
      case 'failed':
        return Colors.red;
      default:
        return Colors.amber.shade700;
    }
  }

  void _openPostSheet(Map<String, dynamic> p) {
    final status = '${p['status'] ?? 'pending'}';
    final dt = DateTime.tryParse('${p['scheduledAt'] ?? ''}')?.toLocal();
    final caption = '${p['caption'] ?? ''}';
    final code = '${p['lastErrorCode'] ?? ''}'.trim();
    final err = '${p['lastError'] ?? ''}'.trim();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 8,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _statusColor(status),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        caption.isEmpty ? '(No caption)' : caption,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _DetailRow(icon: Icons.schedule, label: 'Scheduled', value: dt == null ? '—' : DateFormat('dd MMM yyyy • hh:mm a').format(dt)),
                if (status == 'failed' && err.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _DetailRow(
                    icon: Icons.error_outline,
                    label: code.isNotEmpty ? 'Error ($code)' : 'Error',
                    value: err,
                    valueColor: Colors.red.shade800,
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: caption));
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Caption copied')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy caption'),
                ),
                if (status == 'pending') ...[
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final changed = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(builder: (_) => EditSchedulePostScreen(post: p)),
                      );
                      if (changed == true) _load();
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit schedule'),
                  ),
                ],
                if (status == 'failed') ...[
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () async {
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      if (uid == null) return;
                      Navigator.pop(ctx);
                      await _schedulerService.retryFailedPost(userId: uid, postId: '${p['id']}');
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Retry queued — post will run in a few minutes')),
                      );
                      _load();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry failed post'),
                  ),
                ],
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid == null) return;
                    Navigator.pop(ctx);
                    await _schedulerService.deleteScheduledPost(userId: uid, postId: '${p['id']}');
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Scheduled post deleted')),
                    );
                    _load();
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDayPosts = _posts.where((p) {
      final dt = DateTime.tryParse('${p['scheduledAt'] ?? ''}')?.toLocal();
      if (dt == null) return false;
      return dt.year == _selectedDate.year && dt.month == _selectedDate.month && dt.day == _selectedDate.day;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheduler Calendar'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _LegendDot(color: Colors.amber.shade700, label: 'Pending'),
                      _LegendDot(color: Colors.green, label: 'Posted'),
                      _LegendDot(color: Colors.red, label: 'Failed'),
                    ],
                  ),
                ),
                CalendarDatePicker(
                  initialDate: _selectedDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  onDateChanged: (d) => setState(() => _selectedDate = d),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Text(
                    DateFormat('EEEE, d MMM yyyy').format(_selectedDate),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: selectedDayPosts.isEmpty
                      ? Center(
                          child: Text(
                            'No posts on this day',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                          itemCount: selectedDayPosts.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final p = selectedDayPosts[i];
                            final dt = DateTime.tryParse('${p['scheduledAt'] ?? ''}')?.toLocal();
                            final status = '${p['status'] ?? 'pending'}';
                            final thumb = _thumbUrl(p);
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => _openPostSheet(p),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                                  ),
                                  child: IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Container(
                                          width: 5,
                                          decoration: BoxDecoration(
                                            color: _statusColor(status),
                                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(13)),
                                          ),
                                        ),
                                        ClipRRect(
                                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                                          child: SizedBox(
                                            width: 72,
                                            height: 72,
                                            child: thumb.isEmpty
                                                ? ColoredBox(
                                                    color: Colors.grey.shade300,
                                                    child: const Icon(Icons.image_outlined),
                                                  )
                                                : Image.network(
                                                    thumb,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => ColoredBox(
                                                      color: Colors.grey.shade300,
                                                      child: const Icon(Icons.broken_image_outlined),
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${p['caption'] ?? ''}',
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    Icon(Icons.schedule, size: 15, color: Colors.grey.shade700),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      dt == null ? '—' : DateFormat('hh:mm a').format(dt),
                                                      style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: _statusColor(status).withValues(alpha: 0.12),
                                                        borderRadius: BorderRadius.circular(20),
                                                      ),
                                                      child: Text(
                                                        status.toUpperCase(),
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w700,
                                                          color: _statusColor(status),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right),
                                        const SizedBox(width: 4),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade700),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(color: valueColor ?? Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }
}

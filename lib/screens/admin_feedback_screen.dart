import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/feedback_service.dart';
import '../utils/admin_guard.dart';
import '../utils/global_error_handler.dart';
import '../widgets/error_retry_card.dart';

class AdminFeedbackScreen extends StatefulWidget {
  const AdminFeedbackScreen({super.key});

  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen> {
  final AdminGuard _adminGuard = AdminGuard();

  bool _adminCheckDone = false;
  bool _isAdmin = false;
  String _filter = 'all'; // all, bug, feature, suggestion

  @override
  void initState() {
    super.initState();
    _checkAdmin();
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

  @override
  Widget build(BuildContext context) {
    if (!_adminCheckDone) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Feedback'),
          backgroundColor: const Color(0xFF7B2CBF),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Feedback'),
          backgroundColor: const Color(0xFF7B2CBF),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Admin only')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Feedback Panel'),
        backgroundColor: const Color(0xFF7B2CBF),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 48,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Bug',
                  selected: _filter == 'bug',
                  onTap: () => setState(() => _filter = 'bug'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Feature',
                  selected: _filter == 'feature',
                  onTap: () => setState(() => _filter = 'feature'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Suggestion',
                  selected: _filter == 'suggestion',
                  onTap: () => setState(() => _filter = 'suggestion'),
                ),
              ],
            ),
          ),
          ),
          Expanded(
            child: StreamBuilder<List<FeedbackModel>>(
              stream: FeedbackService().getAllFeedbackStream(
                typeFilter: _filter == 'all' ? null : _filter,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return ErrorRetryCard(
                    error: snapshot.error,
                    onRetry: () => setState(() {}),
                  );
                }
                final list = snapshot.data ?? [];
                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No feedback',
                          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final item = list[index];
                    return _AdminFeedbackCard(
                      model: item,
                      onTap: () => _openDetail(context, item),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context, FeedbackModel model) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _AdminFeedbackDetailScreen(feedback: model),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFF7B2CBF).withOpacity(0.3),
      checkmarkColor: const Color(0xFF7B2CBF),
    );
  }
}

class _AdminFeedbackCard extends StatelessWidget {
  const _AdminFeedbackCard({
    required this.model,
    required this.onTap,
  });

  final FeedbackModel model;
  final VoidCallback onTap;

  static Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.orange;
      case 'replied':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  static String _typeLabel(String type) {
    switch (type) {
      case 'bug':
        return 'Bug';
      case 'feature':
        return 'Feature';
      case 'suggestion':
        return 'Suggestion';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = model.message.length > 80
        ? '${model.message.substring(0, 80)}...'
        : model.message;
    final dateStr = model.createdAt != null
        ? DateFormat('MMM d, y').format(model.createdAt!)
        : '—';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _typeLabel(model.type),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7B2CBF),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _statusColor(model.status).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      model.status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _statusColor(model.status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                preview,
                style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                '${model.userEmail} • $dateStr',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminFeedbackDetailScreen extends StatefulWidget {
  const _AdminFeedbackDetailScreen({required this.feedback});

  final FeedbackModel feedback;

  @override
  State<_AdminFeedbackDetailScreen> createState() => _AdminFeedbackDetailScreenState();
}

class _AdminFeedbackDetailScreenState extends State<_AdminFeedbackDetailScreen> {
  final _replyController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await FeedbackService().replyToFeedback(widget.feedback.id, text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reply sent'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        GlobalErrorHandler.log('AdminFeedback', e);
        GlobalErrorHandler.showSnackBar(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.feedback;
    final dateStr = f.createdAt != null
        ? DateFormat('MMM d, y • HH:mm').format(f.createdAt!)
        : '—';
    Color statusColor(String s) {
      switch (s) {
        case 'open': return Colors.orange;
        case 'replied': return Colors.green;
        case 'closed': return Colors.grey;
        default: return Colors.grey;
      }
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Feedback'),
        backgroundColor: const Color(0xFF7B2CBF),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor(f.status).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            f.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: statusColor(f.status),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          f.type,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF7B2CBF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      f.message,
                      style: const TextStyle(fontSize: 16, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    _DetailRow(label: 'Email', value: f.userEmail),
                    if (f.screen != null && f.screen!.isNotEmpty)
                      _DetailRow(label: 'Screen', value: f.screen ?? ''),
                    _DetailRow(label: 'Created', value: dateStr),
                    if (f.appVersion != null)
                      _DetailRow(label: 'App version', value: f.appVersion ?? ''),
                  ],
                ),
              ),
            ),
            if (f.adminReply != null && f.adminReply!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 1,
                color: Colors.green.withOpacity(0.06),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your reply',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        f.adminReply ?? '',
                        style: TextStyle(fontSize: 15, color: Colors.grey[800], height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Reply to user',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _replyController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Write your reply...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _sending ? null : _sendReply,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7B2CBF),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _sending
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Send Reply'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/admin_guard.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final ApiService _api = ApiService();
  final AdminGuard _adminGuard = AdminGuard();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _bodyCtrl = TextEditingController();
  final TextEditingController _deepLinkCtrl = TextEditingController();
  final TextEditingController _ctaCtrl = TextEditingController();

  bool _checkingAdmin = true;
  bool _isAdmin = false;
  bool _loading = false;
  String _segment = 'trial';
  int _inactiveDays = 7;
  Map<String, dynamic>? _preview;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    final isAdmin = await _adminGuard.isAdminUser();
    if (!mounted) return;
    setState(() {
      _isAdmin = isAdmin;
      _checkingAdmin = false;
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _deepLinkCtrl.dispose();
    _ctaCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _payload({required bool includeMessage}) {
    return {
      'segment': _segment,
      if (_segment == 'inactive') 'inactiveDays': _inactiveDays,
      if (includeMessage) 'title': _titleCtrl.text.trim(),
      if (includeMessage) 'body': _bodyCtrl.text.trim(),
      if (includeMessage) 'deepLink': _deepLinkCtrl.text.trim(),
      if (includeMessage) 'ctaLabel': _ctaCtrl.text.trim(),
    };
  }

  Future<void> _previewCampaign() async {
    setState(() {
      _loading = true;
      _result = null;
    });
    try {
      final data = await _api.adminNotificationPreview(_payload(includeMessage: false));
      if (!mounted) return;
      setState(() => _preview = data);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong, try again')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendCampaign() async {
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and body are required')),
      );
      return;
    }
    final targeted = (_preview?['targetUsers'] ?? 0).toString();
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Confirm send'),
            content: Text('You are about to send to $targeted users'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Send')),
            ],
          ),
        ) ??
        false;
    if (!ok) return;

    setState(() {
      _loading = true;
      _result = null;
    });
    try {
      final data = await _api.adminNotificationSend(_payload(includeMessage: true));
      if (!mounted) return;
      setState(() => _result = data);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Campaign sent')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong, try again')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAdmin) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_isAdmin) {
      return const Scaffold(body: Center(child: Text('Admin only')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Notifications'),
        backgroundColor: const Color(0xFF7B2CBF),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: _segment,
            decoration: const InputDecoration(labelText: 'Segment'),
            items: const [
              DropdownMenuItem(value: 'trial', child: Text('Trial users')),
              DropdownMenuItem(value: 'premium', child: Text('Premium users')),
              DropdownMenuItem(value: 'inactive', child: Text('Inactive users')),
            ],
            onChanged: _loading
                ? null
                : (v) => setState(() {
                      _segment = v ?? 'trial';
                      _preview = null;
                    }),
          ),
          if (_segment == 'inactive') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _inactiveDays,
              decoration: const InputDecoration(labelText: 'Inactive days'),
              items: const [1, 3, 7, 14, 30]
                  .map((d) => DropdownMenuItem(value: d, child: Text('$d days')))
                  .toList(),
              onChanged: _loading
                  ? null
                  : (v) => setState(() {
                        _inactiveDays = v ?? 7;
                        _preview = null;
                      }),
            ),
          ],
          const SizedBox(height: 12),
          TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Title *')),
          const SizedBox(height: 12),
          TextField(controller: _bodyCtrl, decoration: const InputDecoration(labelText: 'Body *'), maxLines: 3),
          const SizedBox(height: 12),
          TextField(controller: _deepLinkCtrl, decoration: const InputDecoration(labelText: 'Deep link route (optional)')),
          const SizedBox(height: 12),
          TextField(controller: _ctaCtrl, decoration: const InputDecoration(labelText: 'CTA label (optional)')),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading ? null : _previewCampaign,
                  child: const Text('Preview'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _loading ? null : _sendCampaign,
                  child: const Text('Send'),
                ),
              ),
            ],
          ),
          if (_loading) ...[
            const SizedBox(height: 12),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_preview != null) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                title: const Text('Preview'),
                subtitle: Text(
                  'Users: ${_preview?['targetUsers'] ?? 0}\n'
                  'Tokens: ${_preview?['targetTokens'] ?? 0}\n'
                  'Skipped: ${_preview?['skippedCount'] ?? 0}',
                ),
              ),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                title: const Text('Result'),
                subtitle: Text(
                  'Target users: ${_result?['targetUsers'] ?? 0}\n'
                  'Success: ${_result?['successCount'] ?? 0}\n'
                  'Failure: ${_result?['failureCount'] ?? 0}\n'
                  'Skipped: ${_result?['skippedCount'] ?? 0}',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

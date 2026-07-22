import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../utils/admin_guard.dart';

/// Admin: search a user by email and manage them from the phone — grant/revoke
/// Premium, start a trial, reset daily credits. Writes directly to Firestore
/// (admins are allowed to write any user doc by the security rules), so it works
/// without a laptop or backend keys.
class AdminUserManageScreen extends StatefulWidget {
  const AdminUserManageScreen({super.key});

  @override
  State<AdminUserManageScreen> createState() => _AdminUserManageScreenState();
}

class _AdminUserManageScreenState extends State<AdminUserManageScreen> {
  static const _primary = Color(0xFF7B2CBF);
  final _searchController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _adminGuard = AdminGuard();

  bool _adminChecked = false;
  bool _isAdmin = false;
  bool _loading = false;
  bool _busy = false;
  String? _error;
  DocumentSnapshot<Map<String, dynamic>>? _user;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkAdmin() async {
    final ok = await _adminGuard.isAdminUser();
    if (!mounted) return;
    setState(() {
      _adminChecked = true;
      _isAdmin = ok;
    });
    if (!ok && mounted) Navigator.of(context).pop();
  }

  Future<void> _search() async {
    final email = _searchController.text.trim().toLowerCase();
    if (email.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _user = null;
    });
    try {
      final snap = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (snap.docs.isEmpty) {
          _error = 'No user found for "$email"';
        } else {
          _user = snap.docs.first;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Search failed: $e';
      });
    }
  }

  Future<void> _refresh() async {
    if (_user == null) return;
    final fresh = await _firestore.collection('users').doc(_user!.id).get();
    if (mounted) setState(() => _user = fresh);
  }

  Future<void> _apply(String label, Map<String, dynamic> updates,
      {bool destructive = false}) async {
    if (_user == null || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: Text('Apply "$label" to ${_user!.data()?['email'] ?? _user!.id}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: destructive ? Colors.red : _primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await _firestore.collection('users').doc(_user!.id).set({
        ...updates,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label ✓')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _grantPremium(int days) {
    final expiry = DateTime.now().add(Duration(days: days));
    _apply('Grant Premium ($days days)', {
      'isPremium': true,
      'planType': 'premium',
      'subscriptionPlan': 'pro',
      'premiumPlan': 'pro',
      'premiumProductId': 'premium_monthly',
      'premiumExpiry': Timestamp.fromDate(expiry),
      'premiumStartDate': Timestamp.fromDate(DateTime.now()),
      'premiumExpiryNotified': false,
      'isTrialActive': false,
      'lastPurchaseStatus': 'purchased',
    });
  }

  void _revokePremium() {
    _apply('Revoke Premium', {
      'isPremium': false,
      'planType': 'free',
      'subscriptionPlan': 'free',
      'premiumExpiry': null,
      'lastPurchaseStatus': 'expired',
    }, destructive: true);
  }

  void _startTrial(int days) {
    final end = DateTime.now().add(Duration(days: days));
    _apply('Start $days-day Trial', {
      'planType': 'trial',
      'trialStartDate': Timestamp.fromDate(DateTime.now()),
      'trialEndDate': Timestamp.fromDate(end),
      'trialUsed': true,
      'isPremium': false,
      'premiumExpiry': null,
    });
  }

  void _resetCredits() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now().toUtc());
    _apply('Reset Daily Credits', {
      'dailyAiUsed': 0,
      'dailyUsedCount': 0,
      'dailyAiDate': today,
    });
  }

  String _fmt(dynamic v) {
    if (v == null) return '—';
    if (v is Timestamp) return DateFormat.yMd().add_Hm().format(v.toDate());
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (!_adminChecked || !_isAdmin) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final data = _user?.data();
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Manage User'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _searchController,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: 'Search user by email',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward_rounded), onPressed: _search),
            ),
          ),
          const SizedBox(height: 12),
          if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          if (_error != null)
            Card(color: Colors.red[50], child: Padding(padding: const EdgeInsets.all(14), child: Text(_error!, style: TextStyle(color: Colors.red[800])))),
          if (data != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['email']?.toString() ?? _user!.id,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 8),
                    _row('Plan', data['planType']?.toString() ?? '—'),
                    _row('Premium', data['isPremium'] == true ? 'YES' : 'no'),
                    _row('Premium expiry', _fmt(data['premiumExpiry'])),
                    _row('Trial ends', _fmt(data['trialEndDate'] ?? data['trialEnd'])),
                    _row('Daily used', '${data['dailyAiUsed'] ?? data['dailyUsedCount'] ?? 0}'),
                    _row('Last login', _fmt(data['lastLoginAt'])),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Actions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _actionBtn('Grant Premium 1 month', Icons.workspace_premium, () => _grantPremium(30)),
                _actionBtn('Grant Premium 1 year', Icons.star_rounded, () => _grantPremium(365)),
                _actionBtn('Revoke Premium', Icons.money_off_rounded, _revokePremium, danger: true),
                _actionBtn('Start 3-day Trial', Icons.schedule_rounded, () => _startTrial(3)),
                _actionBtn('Reset Daily Credits', Icons.refresh_rounded, _resetCredits),
              ],
            ),
            if (_busy) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
          ],
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(width: 120, child: Text(k, style: TextStyle(color: Colors.grey[600]))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _actionBtn(String label, IconData icon, VoidCallback onTap, {bool danger = false}) {
    return FilledButton.tonalIcon(
      onPressed: _busy ? null : onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: danger ? Colors.red[50] : const Color(0xFFEDE3FF),
        foregroundColor: danger ? Colors.red[800] : _primary,
      ),
    );
  }
}

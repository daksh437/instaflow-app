import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/admin_user_row.dart';
import '../../services/admin_dashboard_service.dart';
import '../../utils/admin_guard.dart';
import '../../utils/app_error_handler.dart';
import '../../widgets/error_retry_card.dart';

class AdminPremiumUsersScreen extends StatefulWidget {
  const AdminPremiumUsersScreen({super.key});

  @override
  State<AdminPremiumUsersScreen> createState() => _AdminPremiumUsersScreenState();
}

class _AdminPremiumUsersScreenState extends State<AdminPremiumUsersScreen> {
  final AdminDashboardService _service = AdminDashboardService();
  final AdminGuard _adminGuard = AdminGuard();
  final TextEditingController _searchController = TextEditingController();

  bool _adminCheckDone = false;
  bool _isAdmin = false;
  bool _loading = true;
  String? _error;
  List<AdminUserRow> _list = [];
  int _page = 0;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _checkAdminThenLoad();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminThenLoad() async {
    final isAdmin = await _adminGuard.isAdminUser();
    if (!mounted) return;
    setState(() {
      _adminCheckDone = true;
      _isAdmin = isAdmin;
    });
    if (!isAdmin) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    await _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.getPremiumUsersPage(limit: 30, page: _page, search: _search);
      if (!mounted) return;
      setState(() {
        _list = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        AppErrorHandler.log('AdminPremiumUsers', e);
        setState(() {
          _loading = false;
          _error = AppErrorHandler.getFriendlyMessage(e);
        });
      }
    }
  }

  void _onSearch(String value) {
    setState(() {
      _search = value;
      _page = 0;
    });
    _load();
  }

  /// Human-readable duration: `1m` -> `1 month`, `3m` -> `3 months`, etc.
  String _durationLabel(String? d) {
    switch ((d ?? '').trim()) {
      case '1m':
        return '1 month';
      case '3m':
        return '3 months';
      case '6m':
        return '6 months';
      case '12m':
        return '12 months';
      case '':
        return '—';
      default:
        return d!.trim();
    }
  }

  String _fmtDate(DateTime? d) => d != null ? DateFormat('d MMM yyyy').format(d) : '—';

  /// A labelled, non-copyable info line (e.g. dates, duration).
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  /// A copyable id line. Tap to copy the full value to the clipboard.
  Widget _idRow(BuildContext context, String label, String? value) {
    final hasValue = (value ?? '').trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: InkWell(
        onTap: hasValue
            ? () {
                Clipboard.setData(ClipboardData(text: value!.trim()));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$label copied'), duration: const Duration(seconds: 1)),
                );
              }
            : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: Text(
                hasValue ? value!.trim() : '—',
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasValue)
              Icon(Icons.copy_rounded, size: 14, color: Colors.grey[500]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_adminCheckDone || !_isAdmin) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Premium Users'),
        backgroundColor: const Color(0xFF7B2CBF),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Search by email',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? ErrorRetryCard(message: _error, onRetry: _load)
                    : _list.isEmpty
                        ? const Center(child: Text('No premium users'))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: _list.length,
                            itemBuilder: (context, i) {
                              final u = _list[i];
                              final isActive = u.status == 'active';
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.email_outlined, size: 16, color: Color(0xFF7B2CBF)),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              u.email.isNotEmpty ? u.email : u.identity,
                                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: (isActive ? Colors.green : Colors.red).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              isActive ? 'ACTIVE' : 'EXPIRED',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: isActive ? Colors.green[800] : Colors.red[800],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 16),
                                      _infoRow('Active since', _fmtDate(u.purchaseDate)),
                                      _infoRow('Plan', _durationLabel(u.premiumDuration)),
                                      _infoRow('Expires on', _fmtDate(u.premiumExpiry)),
                                      const SizedBox(height: 8),
                                      _idRow(context, 'User ID', u.uid),
                                      _idRow(context, 'Product ID', u.productId),
                                      _idRow(context, 'Payment ID', u.purchaseToken),
                                    ],
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

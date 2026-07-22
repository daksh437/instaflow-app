import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/admin_user_row.dart';
import '../../services/admin_dashboard_service.dart';
import '../../utils/admin_guard.dart';
import '../../utils/app_error_handler.dart';
import '../../widgets/error_retry_card.dart';

class AdminUserListScreen extends StatefulWidget {
  const AdminUserListScreen({super.key});

  @override
  State<AdminUserListScreen> createState() => _AdminUserListScreenState();
}

class _AdminUserListScreenState extends State<AdminUserListScreen> {
  final AdminDashboardService _service = AdminDashboardService();
  final AdminGuard _adminGuard = AdminGuard();
  final TextEditingController _searchController = TextEditingController();

  bool _adminCheckDone = false;
  bool _isAdmin = false;
  bool _loading = true;
  String? _error;
  List<AdminUserRow> _list = [];
  int _page = 0;
  static const int _pageSize = 30;
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
      final list = await _service.getUsersPage(limit: 30, page: _page, search: _search);
      if (!mounted) return;
      setState(() {
        _list = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        AppErrorHandler.log('AdminUserList', e);
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

  @override
  Widget build(BuildContext context) {
    if (!_adminCheckDone || !_isAdmin) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('All Users'),
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
                hintText: 'Search by email or UID',
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
                        ? const Center(child: Text('No users'))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: _list.length + 1,
                            itemBuilder: (context, i) {
                              if (i == _list.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: _page > 0
                                              ? () {
                                                  setState(() => _page--);
                                                  _load();
                                                }
                                              : null,
                                          child: const Text('Previous'),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: _list.length >= _pageSize
                                              ? () {
                                                  setState(() => _page++);
                                                  _load();
                                                }
                                              : null,
                                          child: const Text('Next'),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              final u = _list[i];
                              return _UserTile(row: u);
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.row});

  final AdminUserRow row;

  @override
  Widget build(BuildContext context) {
    String formatDate(DateTime? dt, {bool withTime = false}) {
      if (dt == null) return '—';
      return withTime ? DateFormat('dd MMM yyyy, hh:mm a').format(dt) : DateFormat('dd MMM yyyy').format(dt);
    }

    final expiry = row.activeExpiry;
    final planLine = 'Plan: ${row.plan} • ${row.planDetail} • Expiry: ${formatDate(expiry)}';
    final lastActiveLine = 'Last active: ${formatDate(row.lastActiveAt, withTime: true)}';
    final usageLine = 'AI today: ${row.aiUsesToday} • Total: ${row.aiUsesTotal}';
    final createdLine = 'Created: ${formatDate(row.createdAt)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              row.identity,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              row.uid,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(planLine, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 2),
            Text(lastActiveLine, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 2),
            Text(usageLine, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 2),
            Text(createdLine, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

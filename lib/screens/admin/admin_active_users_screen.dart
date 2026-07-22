import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/admin_user_row.dart';
import '../../services/admin_dashboard_service.dart';
import '../../utils/admin_guard.dart';
import '../../utils/app_error_handler.dart';
import '../../widgets/error_retry_card.dart';

class AdminActiveUsersScreen extends StatefulWidget {
  const AdminActiveUsersScreen({super.key});

  @override
  State<AdminActiveUsersScreen> createState() => _AdminActiveUsersScreenState();
}

class _AdminActiveUsersScreenState extends State<AdminActiveUsersScreen> {
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
      final list = await _service.getDailyActivePage(limit: 30, page: _page, search: _search);
      if (!mounted) return;
      setState(() {
        _list = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        AppErrorHandler.log('AdminActiveUsers', e);
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
        title: const Text('Daily Active Users'),
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
                        ? const Center(child: Text('No active users today'))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: _list.length,
                            itemBuilder: (context, i) {
                              final u = _list[i];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: const Icon(Icons.email_outlined, color: Color(0xFF7B2CBF)),
                                  title: Text(u.identity),
                                  subtitle: Text(
                                    '${u.uid}\nPlan: ${u.plan} • Last active: ${u.lastActiveAt != null ? DateFormat.yMd().add_Hm().format(u.lastActiveAt!) : "—"}\nAI today: ${u.aiUsesToday} • Total: ${u.aiUsesTotal}',
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  isThreeLine: true,
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

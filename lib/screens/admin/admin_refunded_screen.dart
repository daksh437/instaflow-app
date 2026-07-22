import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/refunded_user_row.dart';
import '../../services/admin_dashboard_service.dart';
import '../../utils/admin_guard.dart';
import '../../utils/app_error_handler.dart';
import '../../widgets/error_retry_card.dart';

class AdminRefundedScreen extends StatefulWidget {
  const AdminRefundedScreen({super.key});

  @override
  State<AdminRefundedScreen> createState() => _AdminRefundedScreenState();
}

class _AdminRefundedScreenState extends State<AdminRefundedScreen> {
  final AdminDashboardService _service = AdminDashboardService();
  final AdminGuard _adminGuard = AdminGuard();
  final TextEditingController _searchController = TextEditingController();

  bool _adminCheckDone = false;
  bool _isAdmin = false;
  bool _loading = true;
  String? _error;
  List<RefundedUserRow> _list = [];
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
      final list = await _service.getRefundedPage(limit: 30, page: _page, search: _search);
      if (!mounted) return;
      setState(() {
        _list = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        AppErrorHandler.log('AdminRefunded', e);
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
        title: const Text('Refunded Users'),
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
                        ? const Center(child: Text('No refunded users'))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: _list.length,
                            itemBuilder: (context, i) {
                              final u = _list[i];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Row(
                                    children: [
                                      Expanded(child: Text(u.emailDisplay)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.red[100],
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: (Colors.red[700] ?? Colors.red), width: 1),
                                        ),
                                        child: Text(
                                          'REFUNDED',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red[800],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    'Duration: ${u.duration ?? "—"} • Purchase: ${u.purchaseDate != null ? DateFormat.yMd().format(u.purchaseDate!) : "—"}\nRevoked: ${u.revokedAt != null ? DateFormat.yMd().add_Hm().format(u.revokedAt!) : "—"}${u.reason != null && u.reason!.isNotEmpty ? " • ${u.reason}" : ""}',
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 3,
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

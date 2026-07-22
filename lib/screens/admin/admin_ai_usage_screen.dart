import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/ai_usage_log_row.dart';
import '../../services/admin_dashboard_service.dart';
import '../../utils/admin_guard.dart';
import '../../utils/app_error_handler.dart';
import '../../widgets/error_retry_card.dart';

class AdminAIUsageScreen extends StatefulWidget {
  const AdminAIUsageScreen({super.key});

  @override
  State<AdminAIUsageScreen> createState() => _AdminAIUsageScreenState();
}

class _AdminAIUsageScreenState extends State<AdminAIUsageScreen> {
  final AdminDashboardService _service = AdminDashboardService();
  final AdminGuard _adminGuard = AdminGuard();
  final TextEditingController _searchController = TextEditingController();

  bool _adminCheckDone = false;
  bool _isAdmin = false;
  bool _loading = true;
  String? _error;
  List<AiUsageLogRow> _list = [];
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
      final list = await _service.getTodayAiUsageLogs(search: _search);
      if (!mounted) return;
      setState(() {
        _list = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        AppErrorHandler.log('AdminAIUsage', e);
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
        title: const Text('Today AI Usage'),
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
                hintText: 'Search by email or tool',
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
                        ? const Center(child: Text('No AI usage today'))
                        : Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '${_list.length} AI use${_list.length == 1 ? '' : 's'} today',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  itemCount: _list.length,
                                  itemBuilder: (context, i) {
                                    final r = _list[i];
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        leading: const CircleAvatar(
                                          backgroundColor: Color(0xFFEDE3FF),
                                          child: Icon(Icons.smart_toy_rounded,
                                              color: Color(0xFF7B2CBF), size: 20),
                                        ),
                                        title: Text(
                                          r.identity,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600, fontSize: 14),
                                        ),
                                        subtitle: Text(
                                          'Tool: ${r.toolName}'
                                          '${r.plan.isNotEmpty ? ' • ${r.plan}' : ''}\n'
                                          '${r.usedAt != null ? DateFormat.yMd().add_jm().format(r.usedAt!) : "—"}',
                                          style: const TextStyle(fontSize: 12),
                                          maxLines: 2,
                                        ),
                                        isThreeLine: true,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}

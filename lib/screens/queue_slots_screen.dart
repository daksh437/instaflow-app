import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/scheduler_service.dart';

/// Matches backend / JS [Date.getDay()]: 0 = Sunday … 6 = Saturday.
const _kDayShort = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

class QueueSlotsScreen extends StatefulWidget {
  const QueueSlotsScreen({super.key});

  @override
  State<QueueSlotsScreen> createState() => _QueueSlotsScreenState();
}

class _QueueSlotsScreenState extends State<QueueSlotsScreen> {
  final SchedulerService _schedulerService = SchedulerService();
  final TextEditingController _timeController = TextEditingController(text: '10:00');
  final TextEditingController _tzController = TextEditingController(text: 'Asia/Kolkata');
  List<int> _days = [1, 3, 5];
  bool _active = true;
  bool _loading = true;
  List<Map<String, dynamic>> _slots = const [];

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _loading = true);
    try {
      final slots = await _schedulerService.getSlots(uid);
      if (!mounted) return;
      setState(() => _slots = slots);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createSlot() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (_days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least one day')),
      );
      return;
    }
    try {
      await _schedulerService.createSlot(
        userId: uid,
        days: _days,
        time: _timeController.text.trim(),
        timezone: _tzController.text.trim(),
        active: _active,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Queue slot created')),
      );
      await _loadSlots();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _confirmDelete(String slotId) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete slot?'),
        content: const Text('Scheduled queue posts already using this slot are not changed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (go != true) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _schedulerService.deleteSlot(userId: uid, slotId: slotId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Slot deleted')));
      await _loadSlots();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _editSlot(Map<String, dynamic> slot) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final id = '${slot['id']}';
    var days = List<int>.from(
      (slot['days'] as List?)?.map((e) => (e as num).toInt()) ?? const <int>[],
    );
    days = days.toSet().toList()..sort();
    final timeCtrl = TextEditingController(text: '${slot['time'] ?? '10:00'}');
    final tzCtrl = TextEditingController(text: '${slot['timezone'] ?? 'UTC'}');
    var active = slot['active'] != false;

    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Edit queue slot'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: List.generate(7, (i) {
                        final selected = days.contains(i);
                        return FilterChip(
                          showCheckmark: false,
                          selected: selected,
                          label: Text(_kDayShort[i]),
                          onSelected: (v) {
                            setLocal(() {
                              if (v) {
                                days = [...days, i]..sort();
                              } else {
                                days = days.where((d) => d != i).toList();
                              }
                            });
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: timeCtrl,
                      decoration: const InputDecoration(labelText: 'Time (HH:mm)'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: tzCtrl,
                      decoration: const InputDecoration(labelText: 'Timezone (e.g. Asia/Kolkata)'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active'),
                      value: active,
                      onChanged: (v) => setLocal(() => active = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                FilledButton(
                  onPressed: days.isEmpty ? null : () => Navigator.pop(ctx, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) {
      timeCtrl.dispose();
      tzCtrl.dispose();
      return;
    }

    try {
      await _schedulerService.updateSlot(
        userId: uid,
        slotId: id,
        days: days,
        time: timeCtrl.text.trim(),
        timezone: tzCtrl.text.trim(),
        active: active,
      );
      timeCtrl.dispose();
      tzCtrl.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Slot updated')));
      await _loadSlots();
    } catch (e) {
      timeCtrl.dispose();
      tzCtrl.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  String _daysLabel(List<dynamic>? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final nums = raw.map((e) => (e as num).toInt()).toList()..sort();
    return nums.map((d) => d >= 0 && d < 7 ? _kDayShort[d] : '$d').join(', ');
  }

  @override
  void dispose() {
    _timeController.dispose();
    _tzController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Queue Slots')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSlots,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Posting windows',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Queue mode assigns the next matching slot. Times use your slot timezone.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(7, (i) {
                      final selected = _days.contains(i);
                      return FilterChip(
                        showCheckmark: false,
                        selected: selected,
                        label: Text(_kDayShort[i]),
                        onSelected: (v) {
                          setState(() {
                            if (v) {
                              _days = [..._days, i]..sort();
                            } else {
                              _days = _days.where((d) => d != i).toList();
                            }
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _timeController,
                    decoration: const InputDecoration(
                      labelText: 'Time (HH:mm)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _tzController,
                    decoration: const InputDecoration(
                      labelText: 'Timezone',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    subtitle: const Text('Inactive slots are ignored when scheduling'),
                    value: _active,
                    onChanged: (v) => setState(() => _active = v),
                  ),
                  FilledButton.icon(
                    onPressed: _createSlot,
                    icon: const Icon(Icons.add),
                    label: const Text('Create slot'),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Your slots (${_slots.length})',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  if (_slots.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No slots yet — create one to use queue scheduling.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                    ),
                  ..._slots.map((slot) {
                    final active = slot['active'] != false;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        title: Text(
                          '${slot['time'] ?? '-'} • ${slot['timezone'] ?? 'UTC'}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text('Days: ${_daysLabel(slot['days'] as List?)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Chip(
                                label: Text(active ? 'On' : 'Off', style: const TextStyle(fontSize: 11)),
                                backgroundColor: active ? Colors.green.shade50 : Colors.grey.shade200,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Edit',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _editSlot(slot),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _confirmDelete('${slot['id']}'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}

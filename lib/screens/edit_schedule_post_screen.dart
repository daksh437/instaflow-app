import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/scheduler_service.dart';

class EditSchedulePostScreen extends StatefulWidget {
  const EditSchedulePostScreen({super.key, required this.post});

  final Map<String, dynamic> post;

  @override
  State<EditSchedulePostScreen> createState() => _EditSchedulePostScreenState();
}

class _EditSchedulePostScreenState extends State<EditSchedulePostScreen> {
  final SchedulerService _schedulerService = SchedulerService();
  late final TextEditingController _captionController;
  late DateTime _scheduledAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(text: '${widget.post['caption'] ?? ''}');
    _scheduledAt = DateTime.tryParse('${widget.post['scheduledAt'] ?? ''}')?.toLocal() ??
        DateTime.now().add(const Duration(hours: 1));
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      await _schedulerService.updateScheduledPost(
        userId: uid,
        postId: '${widget.post['id']}',
        caption: _captionController.text.trim(),
        scheduledAt: _scheduledAt,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Scheduled Post')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _captionController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Write a caption...',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickDateTime,
              icon: const Icon(Icons.schedule),
              label: Text('Scheduled: ${DateFormat('dd MMM yyyy • hh:mm a').format(_scheduledAt)}'),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}

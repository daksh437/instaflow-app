import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/schedule_provider.dart';
import '../../services/instagram_auth_service.dart';

/// Schedule Post Screen – date picker, caption, media picker.
/// Isolated for Instagram Business automation. Uses mock/placeholder services.

const _accent = Color(0xFF7B2CBF);

class SchedulePostScreen extends StatefulWidget {
  const SchedulePostScreen({super.key});

  @override
  State<SchedulePostScreen> createState() => _SchedulePostScreenState();
}

class _SchedulePostScreenState extends State<SchedulePostScreen> {
  final _captionController = TextEditingController();
  DateTime _scheduledDate = DateTime.now().add(const Duration(hours: 1));
  File? _pickedImage;
  bool _authChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await InstagramAuthService.instance.init();
      if (mounted) setState(() => _authChecked = true);
    });
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);
    if (xfile != null && mounted) setState(() => _pickedImage = File(xfile.path));
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null && mounted) setState(() => _scheduledDate = DateTime(date.year, date.month, date.day, _scheduledDate.hour, _scheduledDate.minute));
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledDate),
    );
    if (time != null && mounted) {
      setState(() {
        _scheduledDate = DateTime(_scheduledDate.year, _scheduledDate.month, _scheduledDate.day, time.hour, time.minute);
      });
    }
  }

  Future<void> _submit() async {
    if (_captionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a caption')));
      return;
    }
    final prov = context.read<ScheduleProvider>();
    final ok = await prov.schedulePost(
      scheduledAt: _scheduledDate,
      caption: _captionController.text.trim(),
      imagePath: _pickedImage?.path,
      isReel: false,
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scheduled (mock)'), backgroundColor: _accent));
      Navigator.maybePop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(prov.error ?? 'Failed'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_authChecked) {
      return Scaffold(
        appBar: AppBar(title: const Text('Schedule Post'), backgroundColor: _accent, foregroundColor: Colors.white),
        body: const Center(child: CircularProgressIndicator(color: _accent)),
      );
    }

    final isLoggedIn = InstagramAuthService.instance.isLoggedIn;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule Post'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isLoggedIn) ...[
              const Text('Connect Instagram to schedule posts.', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await InstagramAuthService.instance.login();
                  if (mounted) setState(() {});
                },
                style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Connect Instagram (mock)'),
              ),
              const SizedBox(height: 24),
            ],
            if (isLoggedIn) ...[
              const Text('Caption', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextField(
                controller: _captionController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Write your caption...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _accent, width: 2)),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Media', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickImage,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _accent.withOpacity(0.5)),
                  ),
                  child: _pickedImage != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_pickedImage!, fit: BoxFit.cover, width: double.infinity))
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_rounded, size: 48, color: Colors.grey[600]),
                            const SizedBox(height: 8),
                            Text('Tap to pick image', style: TextStyle(color: Colors.grey[700])),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Schedule at', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_rounded, size: 20),
                      label: Text('${_scheduledDate.day}/${_scheduledDate.month}/${_scheduledDate.year}'),
                      style: OutlinedButton.styleFrom(foregroundColor: _accent, side: const BorderSide(color: _accent)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.access_time_rounded, size: 20),
                      label: Text('${_scheduledDate.hour.toString().padLeft(2, '0')}:${_scheduledDate.minute.toString().padLeft(2, '0')}'),
                      style: OutlinedButton.styleFrom(foregroundColor: _accent, side: const BorderSide(color: _accent)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Consumer<ScheduleProvider>(
                builder: (context, prov, _) {
                  return ElevatedButton(
                    onPressed: prov.isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: prov.isLoading
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Schedule Post'),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

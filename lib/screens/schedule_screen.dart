import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';
import '../models/post_model.dart';
import '../utils/app_error_handler.dart';
import 'dart:io';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _hashtagController = TextEditingController();

  File? _selectedImage;
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;
  bool _isSaving = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() => _scheduledDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() => _scheduledTime = picked);
    }
  }

  Future<void> _schedulePost() async {
    if (_captionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a caption')),
      );
      return;
    }

    if (_scheduledDate == null || _scheduledTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date and time')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final date = _scheduledDate;
      final time = _scheduledTime;
      if (date == null || time == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select date and time')),
          );
        }
        return;
      }

      final scheduledDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );

      final hashtags = _hashtagController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      // Save to Firestore
      final postRef = await _firestore.collection('posts').add({
        'userId': user.uid,
        'caption': _captionController.text,
        'hashtags': hashtags,
        'scheduledTime': Timestamp.fromDate(scheduledDateTime),
        'status': 'scheduled',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Schedule notification
      await _notificationService.scheduleNotification(
        id: postRef.id.hashCode,
        title: 'Scheduled Post Reminder',
        body: 'Your post is scheduled in 30 minutes!',
        scheduledDate: scheduledDateTime.subtract(const Duration(minutes: 30)),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post scheduled successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppErrorHandler.log('ScheduleScreen', e);
        AppErrorHandler.show(context, e);
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Schedule Post'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Picker
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300] ?? Colors.grey),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, size: 50),
                          SizedBox(height: 8),
                          Text('Tap to select image'),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // Caption Input
            TextField(
              controller: _captionController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Caption',
                hintText: 'Write your caption...',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // Hashtags Input
            TextField(
              controller: _hashtagController,
              decoration: const InputDecoration(
                labelText: 'Hashtags (comma-separated)',
                hintText: '#tag1, #tag2, #tag3',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            // Date Picker
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Schedule Date'),
                subtitle: Text(
                  _scheduledDate != null
                      ? DateFormat('MMM dd, yyyy').format(_scheduledDate!)
                      : 'Select date',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _selectDate,
              ),
            ),

            const SizedBox(height: 12),

            // Time Picker
            Card(
              child: ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('Schedule Time'),
                subtitle: Text(
                  _scheduledTime != null
                      ? _scheduledTime!.format(context)
                      : 'Select time',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _selectTime,
              ),
            ),

            const SizedBox(height: 24),

            // Schedule Button
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _schedulePost,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.schedule),
              label: Text(_isSaving ? 'Scheduling...' : 'Schedule Post'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _captionController.dispose();
    _hashtagController.dispose();
    super.dispose();
  }
}


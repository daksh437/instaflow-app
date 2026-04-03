import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/instagram_auth_service.dart';
import '../../services/instagram_publish_service.dart';

/// Reel Publish Screen – pick video, caption, publish (mock).
/// Isolated for Instagram Business automation.

const _accent = Color(0xFF7B2CBF);

class ReelPublishScreen extends StatefulWidget {
  const ReelPublishScreen({super.key});

  @override
  State<ReelPublishScreen> createState() => _ReelPublishScreenState();
}

class _ReelPublishScreenState extends State<ReelPublishScreen> {
  final _captionController = TextEditingController();
  File? _pickedVideo;
  bool _publishing = false;
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

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final xfile = await picker.pickVideo(source: ImageSource.gallery);
    if (xfile != null && mounted) setState(() => _pickedVideo = File(xfile.path));
  }

  Future<void> _publish() async {
    if (_pickedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick a video first')));
      return;
    }
    setState(() => _publishing = true);
    final result = await InstagramPublishService.instance.publishReel(
      videoPath: _pickedVideo!.path,
      caption: _captionController.text.trim().isEmpty ? null : _captionController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _publishing = false);
    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reel published (mock)'), backgroundColor: _accent));
      Navigator.maybePop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_authChecked) {
      return Scaffold(
        appBar: AppBar(title: const Text('Publish Reel'), backgroundColor: _accent, foregroundColor: Colors.white),
        body: const Center(child: CircularProgressIndicator(color: _accent)),
      );
    }

    final isLoggedIn = InstagramAuthService.instance.isLoggedIn;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Publish Reel'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isLoggedIn) ...[
              const Text('Connect Instagram to publish reels.', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await InstagramAuthService.instance.login();
                  if (mounted) setState(() {});
                },
                style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Connect Instagram (mock)'),
              ),
            ],
            if (isLoggedIn) ...[
              const Text('Video', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickVideo,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _accent.withOpacity(0.5)),
                  ),
                  child: _pickedVideo != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(_pickedVideo!, fit: BoxFit.cover, width: double.infinity),
                            ),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.videocam_rounded, size: 48, color: Colors.white),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.video_library_rounded, size: 56, color: Colors.grey[600]),
                            const SizedBox(height: 8),
                            Text('Tap to pick video', style: TextStyle(color: Colors.grey[700], fontSize: 16)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Caption (optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextField(
                controller: _captionController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add a caption...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _accent, width: 2)),
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _publishing ? null : _publish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _publishing
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Publish Reel'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

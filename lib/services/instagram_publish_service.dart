import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

/// Publishing service backed by backend Instagram routes.

class InstagramPublishService {
  InstagramPublishService._();
  static final InstagramPublishService _instance = InstagramPublishService._();
  static InstagramPublishService get instance => _instance;

  Future<PublishResult> publishPhoto({
    required String imagePath,
    String? caption,
  }) async {
    return _publishMedia(
      mediaPath: imagePath,
      isReel: false,
      caption: caption,
    );
  }

  Future<PublishResult> publishReel({
    required String videoPath,
    String? caption,
    String? coverUrl,
  }) async {
    return _publishMedia(
      mediaPath: videoPath,
      isReel: true,
      caption: caption,
    );
  }

  Future<PublishResult> _publishMedia({
    required String mediaPath,
    required bool isReel,
    String? caption,
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) {
        return PublishResult(success: false, message: 'Please sign in first.');
      }
      final file = File(mediaPath);
      if (!await file.exists()) {
        return PublishResult(success: false, message: 'Media file not found.');
      }

      final ext = mediaPath.split('.').last;
      final typeDir = isReel ? 'reel' : 'photo';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('instagram_publish')
          .child(uid)
          .child('${DateTime.now().millisecondsSinceEpoch}.$ext');
      await storageRef.putFile(file);
      final mediaUrl = await storageRef.getDownloadURL();

      final createRes = await http.post(
        Uri.parse('${ApiService.baseUrl}/instagram/media'),
        headers: {
          'Content-Type': 'application/json',
          'x-user-uid': uid,
        },
        body: jsonEncode({
          ...(isReel ? {'videoUrl': mediaUrl} : {'imageUrl': mediaUrl}),
          'caption': caption ?? '',
          'isReel': isReel,
          'mediaType': typeDir,
        }),
      );
      final createBody = jsonDecode(createRes.body) as Map<String, dynamic>;
      if (createRes.statusCode >= 400 || createBody['success'] != true) {
        return PublishResult(
          success: false,
          message: createBody['error']?.toString() ?? 'Failed to create media',
        );
      }

      final creationId = createBody['creationId']?.toString() ?? '';
      if (creationId.isEmpty) {
        return PublishResult(success: false, message: 'Missing creation id');
      }

      final publishRes = await http.post(
        Uri.parse('${ApiService.baseUrl}/instagram/media/publish'),
        headers: {
          'Content-Type': 'application/json',
          'x-user-uid': uid,
        },
        body: jsonEncode({'creationId': creationId}),
      );
      final publishBody = jsonDecode(publishRes.body) as Map<String, dynamic>;
      if (publishRes.statusCode >= 400 || publishBody['success'] != true) {
        return PublishResult(
          success: false,
          message: publishBody['error']?.toString() ?? 'Failed to publish media',
        );
      }

      return PublishResult(
        success: true,
        message: isReel ? 'Reel published successfully' : 'Photo published successfully',
        mediaId: publishBody['mediaId']?.toString(),
      );
    } catch (e) {
      return PublishResult(success: false, message: e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<ScheduleResult> schedulePost({
    required DateTime scheduledAt,
    required String caption,
    String? imagePath,
    String? videoPath,
  }) async {
    return ScheduleResult(
      success: false,
      message: 'Use Schedule flow for timed posting.',
      scheduleId: null,
    );
  }
}

class PublishResult {
  final bool success;
  final String message;
  final String? mediaId;

  PublishResult({required this.success, required this.message, this.mediaId});
}

class ScheduleResult {
  final bool success;
  final String message;
  final String? scheduleId;

  ScheduleResult({required this.success, required this.message, this.scheduleId});
}

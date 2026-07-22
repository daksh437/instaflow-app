import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class SchedulerService {
  SchedulerService({
    FirebaseAuth? auth,
    FirebaseStorage? storage,
    http.Client? client,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _client = client ?? http.Client();

  final FirebaseAuth _auth;
  final FirebaseStorage _storage;
  final http.Client _client;

  String _extractErrorMessage(Map<String, dynamic> data, String fallback) {
    final error = data['error'];
    if (error is String && error.trim().isNotEmpty) return error;
    if (error is Map && error['message'] != null) {
      final message = error['message'].toString().trim();
      if (message.isNotEmpty) return message;
    }
    return fallback;
  }

  Future<String> uploadMedia(File file, {required bool isVideo}) async {
    final user = _auth.currentUser;
    final uid = user?.uid;
    if (uid == null || uid.isEmpty) throw Exception('Please sign in first.');
    if (Firebase.apps.isEmpty) {
      throw Exception('Firebase is not initialized. Restart app and try again.');
    }
    if (!await file.exists()) throw Exception('Selected media file not found.');

    final ext = isVideo ? 'mp4' : 'jpg';
    final storageRef = _storage
        .ref()
        .child('scheduler_uploads')
        .child(uid)
        .child('${DateTime.now().millisecondsSinceEpoch}.$ext');

    try {
      await storageRef.putFile(file);
    } catch (e) {
      throw Exception('Upload failed: $e');
    }

    try {
      final downloadUrl = await storageRef.getDownloadURL();
      // ignore: avoid_print
      print('UPLOAD SUCCESS URL: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      // ignore: avoid_print
      print('DOWNLOAD URL ERROR: $e');
      throw Exception('Failed to resolve uploaded file URL.');
    }
  }

  /// Uploads an audio file (e.g. music attached to a reel). Returns download URL.
  Future<String> uploadAudio(File file) async {
    final user = _auth.currentUser;
    final uid = user?.uid;
    if (uid == null || uid.isEmpty) throw Exception('Please sign in first.');
    if (Firebase.apps.isEmpty) {
      throw Exception('Firebase is not initialized. Restart app and try again.');
    }
    if (!await file.exists()) throw Exception('Audio file not found.');
    final parts = file.path.replaceAll(r'\', '/').split('.');
    final rawExt = parts.length > 1 ? parts.last.toLowerCase() : 'm4a';
    final ext = RegExp(r'^[a-z0-9]{1,8}$').hasMatch(rawExt) ? rawExt : 'm4a';
    final storageRef = _storage
        .ref()
        .child('scheduler_uploads')
        .child(uid)
        .child('audio_${DateTime.now().millisecondsSinceEpoch}.$ext');
    try {
      await storageRef.putFile(file);
    } catch (e) {
      throw Exception('Audio upload failed: $e');
    }
    try {
      return await storageRef.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to resolve audio URL.');
    }
  }

  Future<Map<String, dynamic>> schedulePost({
    required String userId,
    required String imageUrl,
    required String caption,
    required DateTime scheduledAt,
    List<String>? imageUrls,
    bool isVideo = false,
  }) async {
    final response = await _client
        .post(
          Uri.parse('${ApiService.baseUrl}/scheduler/schedule-post'),
          headers: <String, String>{
            'Content-Type': 'application/json',
            'x-user-uid': userId,
          },
          body: jsonEncode({
            'userId': userId,
            'imageUrl': imageUrl,
            'imageUrls': imageUrls ?? [imageUrl],
            'caption': caption,
            'scheduledAt': scheduledAt.toUtc().toIso8601String(),
            'mediaType': isVideo ? 'video' : 'image',
          }),
        )
        .timeout(const Duration(seconds: 25));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || data['success'] != true) {
      throw Exception(_extractErrorMessage(data, 'Failed to schedule post'));
    }
    return data;
  }

  Future<List<Map<String, dynamic>>> getScheduledPosts(String userId) async {
    final uri = Uri.parse('${ApiService.baseUrl}/scheduler/scheduled-posts').replace(
      queryParameters: {'userId': userId},
    );
    final response = await _client.get(uri, headers: {'x-user-uid': userId}).timeout(const Duration(seconds: 25));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || data['success'] != true) {
      throw Exception(_extractErrorMessage(data, 'Failed to fetch scheduled posts'));
    }
    final posts = (data['posts'] as List?) ?? const [];
    return posts.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<String>> uploadMultipleImages(List<File> files) async {
    final urls = <String>[];
    for (final file in files) {
      urls.add(await uploadMedia(file, isVideo: false));
    }
    return urls;
  }

  Future<void> updateScheduledPost({
    required String userId,
    required String postId,
    String? caption,
    DateTime? scheduledAt,
    List<String>? imageUrls,
  }) async {
    final body = <String, dynamic>{};
    if (caption != null) body['caption'] = caption;
    if (scheduledAt != null) body['scheduledAt'] = scheduledAt.toUtc().toIso8601String();
    if (imageUrls != null && imageUrls.isNotEmpty) {
      body['imageUrls'] = imageUrls;
      body['imageUrl'] = imageUrls.first;
    }
    final response = await _client
        .put(
          Uri.parse('${ApiService.baseUrl}/scheduler/update-post/$postId'),
          headers: {'Content-Type': 'application/json', 'x-user-uid': userId},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 25));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || data['success'] != true) {
      throw Exception(_extractErrorMessage(data, 'Failed to update scheduled post'));
    }
  }

  Future<void> deleteScheduledPost({
    required String userId,
    required String postId,
  }) async {
    final response = await _client
        .delete(
          Uri.parse('${ApiService.baseUrl}/scheduler/delete-post/$postId'),
          headers: {'Content-Type': 'application/json', 'x-user-uid': userId},
        )
        .timeout(const Duration(seconds: 25));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || data['success'] != true) {
      throw Exception(_extractErrorMessage(data, 'Failed to delete scheduled post'));
    }
  }

  Future<List<Map<String, dynamic>>> getSlots(String userId) async {
    final uri = Uri.parse('${ApiService.baseUrl}/scheduler/slots');
    final response = await _client.get(uri, headers: {'x-user-uid': userId}).timeout(const Duration(seconds: 25));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || data['success'] != true) {
      throw Exception(_extractErrorMessage(data, 'Failed to fetch slots'));
    }
    final slots = (data['slots'] as List?) ?? const [];
    return slots.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> createSlot({
    required String userId,
    required List<int> days,
    required String time,
    required String timezone,
    bool active = true,
  }) async {
    final response = await _client
        .post(
          Uri.parse('${ApiService.baseUrl}/scheduler/slots'),
          headers: {'Content-Type': 'application/json', 'x-user-uid': userId},
          body: jsonEncode({'days': days, 'time': time, 'timezone': timezone, 'active': active}),
        )
        .timeout(const Duration(seconds: 25));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || data['success'] != true) {
      throw Exception(_extractErrorMessage(data, 'Failed to create slot'));
    }
  }

  Future<void> updateSlot({
    required String userId,
    required String slotId,
    List<int>? days,
    String? time,
    String? timezone,
    bool? active,
  }) async {
    final payload = <String, dynamic>{};
    if (days != null) payload['days'] = days;
    if (time != null) payload['time'] = time;
    if (timezone != null) payload['timezone'] = timezone;
    if (active != null) payload['active'] = active;
    final response = await _client
        .put(
          Uri.parse('${ApiService.baseUrl}/scheduler/slots/$slotId'),
          headers: {'Content-Type': 'application/json', 'x-user-uid': userId},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 25));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || data['success'] != true) {
      throw Exception(_extractErrorMessage(data, 'Failed to update slot'));
    }
  }

  Future<void> deleteSlot({
    required String userId,
    required String slotId,
  }) async {
    final response = await _client
        .delete(
          Uri.parse('${ApiService.baseUrl}/scheduler/slots/$slotId'),
          headers: {'Content-Type': 'application/json', 'x-user-uid': userId},
        )
        .timeout(const Duration(seconds: 25));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || data['success'] != true) {
      throw Exception(_extractErrorMessage(data, 'Failed to delete slot'));
    }
  }

  Future<void> scheduleQueuePost({
    required String userId,
    required String queueSlotId,
    required String imageUrl,
    required List<String> imageUrls,
    required String caption,
    bool isVideo = false,
  }) async {
    final response = await _client
        .post(
          Uri.parse('${ApiService.baseUrl}/scheduler/schedule-queue'),
          headers: {'Content-Type': 'application/json', 'x-user-uid': userId},
          body: jsonEncode({
            'queueSlotId': queueSlotId,
            'imageUrl': imageUrl,
            'imageUrls': imageUrls,
            'caption': caption,
            'mediaType': isVideo ? 'video' : 'image',
          }),
        )
        .timeout(const Duration(seconds: 25));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || data['success'] != true) {
      throw Exception(_extractErrorMessage(data, 'Failed to queue post'));
    }
  }

  Future<void> retryFailedPost({
    required String userId,
    required String postId,
  }) async {
    final response = await _client
        .post(
          Uri.parse('${ApiService.baseUrl}/scheduler/retry-failed/$postId'),
          headers: {'Content-Type': 'application/json', 'x-user-uid': userId},
        )
        .timeout(const Duration(seconds: 25));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || data['success'] != true) {
      throw Exception(_extractErrorMessage(data, 'Failed to retry post'));
    }
  }
}

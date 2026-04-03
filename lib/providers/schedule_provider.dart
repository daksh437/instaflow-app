import 'dart:io';
import 'package:flutter/foundation.dart';

import '../models/scheduled_post_model.dart';
import '../services/schedule_service.dart';

/// Provider for post scheduling. Uses Firebase (ScheduleService) for persistence.
/// No local-only mock; all create/fetch/delete go through Firestore.

class ScheduleProvider extends ChangeNotifier {
  ScheduleProvider() : _scheduleService = ScheduleService() {
    fetchMyScheduledPosts();
  }

  final ScheduleService _scheduleService;

  List<ScheduledPostModel> _scheduled = [];
  bool _isLoading = false;
  String? _error;

  List<ScheduledPostModel> get scheduledPosts => List.unmodifiable(_scheduled);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetch scheduled posts from Firestore.
  Future<void> fetchMyScheduledPosts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _scheduleService.fetchMyScheduledPosts();
      if (result.success && result.data != null) {
        _scheduled = result.data!;
      } else {
        _error = result.error ?? 'Failed to load';
        _scheduled = [];
      }
    } catch (e) {
      _error = e.toString();
      _scheduled = [];
      if (kDebugMode) debugPrint('[ScheduleProvider] fetchMyScheduledPosts: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Schedule a post: uploads media to Storage then creates Firestore doc.
  Future<bool> schedulePost({
    required DateTime scheduledAt,
    required String caption,
    String? imagePath,
    String? videoPath,
    bool isReel = false,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      String? mediaUrl;
      final mediaType = isReel ? 'reel' : 'photo';
      if (imagePath != null) {
        final file = File(imagePath);
        if (!await file.exists()) {
          _error = 'Image file not found';
          _isLoading = false;
          notifyListeners();
          return false;
        }
        final uploadResult = await _scheduleService.uploadMedia(file, mediaType: 'photo');
        if (!uploadResult.success) {
          _error = uploadResult.error ?? 'Upload failed';
          _isLoading = false;
          notifyListeners();
          return false;
        }
        mediaUrl = uploadResult.data;
      } else if (videoPath != null) {
        final file = File(videoPath);
        if (!await file.exists()) {
          _error = 'Video file not found';
          _isLoading = false;
          notifyListeners();
          return false;
        }
        final uploadResult = await _scheduleService.uploadMedia(file, mediaType: 'reel');
        if (!uploadResult.success) {
          _error = uploadResult.error ?? 'Upload failed';
          _isLoading = false;
          notifyListeners();
          return false;
        }
        mediaUrl = uploadResult.data;
      } else {
        _error = 'Pick an image or video';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      if (mediaUrl == null || mediaUrl.isEmpty) {
        _error = 'Could not get media URL';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      final createResult = await _scheduleService.createScheduledPost(
        caption: caption,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        scheduledAt: scheduledAt,
      );
      if (!createResult.success) {
        _error = createResult.error ?? 'Failed to schedule';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      await fetchMyScheduledPosts();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      if (kDebugMode) debugPrint('[ScheduleProvider] schedulePost: $e');
      return false;
    }
  }

  /// Remove a scheduled post (delete from Firestore).
  Future<void> cancelScheduled(String id) async {
    try {
      final result = await _scheduleService.deleteScheduledPost(id);
      if (result.success) {
        _scheduled.removeWhere((p) => p.id == id);
        notifyListeners();
      } else {
        _error = result.error;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      if (kDebugMode) debugPrint('[ScheduleProvider] cancelScheduled: $e');
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

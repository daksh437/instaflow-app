/// Placeholder service for publishing content to Instagram Business.
/// Isolated from rest of app. Use only for automation flows.
///
/// TODO: Insert Facebook App ID, Client Token, App Secret; wire Instagram Graph API (Content Publishing).
/// TODO: Use InstagramAuthService.getAccessToken() for authenticated requests.

class InstagramPublishService {
  InstagramPublishService._();
  static final InstagramPublishService _instance = InstagramPublishService._();
  static InstagramPublishService get instance => _instance;

  /// Publish a single photo to Instagram Business.
  /// TODO: Call Graph API: create container with image_url then publish with creation_id.
  Future<PublishResult> publishPhoto({
    required String imagePath,
    String? caption,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return PublishResult(
      success: true,
      message: 'Mock: photo publish (replace with real API)',
      mediaId: 'mock_media_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  /// Publish a reel (video) to Instagram.
  /// TODO: Call Graph API: create video container then publish (reel).
  Future<PublishResult> publishReel({
    required String videoPath,
    String? caption,
    String? coverUrl,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return PublishResult(
      success: true,
      message: 'Mock: reel publish (replace with real API)',
      mediaId: 'mock_reel_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  /// Schedule a post for later. Local mock only.
  /// TODO: Either use Instagram Graph API scheduling (if available) or backend cron + publish at scheduled time.
  Future<ScheduleResult> schedulePost({
    required DateTime scheduledAt,
    required String caption,
    String? imagePath,
    String? videoPath,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return ScheduleResult(
      success: true,
      message: 'Mock: post scheduled locally (replace with real scheduling)',
      scheduleId: 'mock_schedule_${scheduledAt.millisecondsSinceEpoch}',
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

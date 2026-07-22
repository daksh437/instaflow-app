import 'dart:io';

import '../../models/schedule_post_media_slot.dart';

enum PostFeedAspect { square, portrait, reel }

/// Shared state across the 3-step post creation flow.
class PostCreationSession {
  final List<SchedulePostMediaSlot> imageSlots = [];
  File? videoFile;
  int currentImageIndex = 0;
  PostFeedAspect aspect = PostFeedAspect.portrait;

  File? musicFile;
  String? musicLabel;
  double trimStart = 0;
  double trimEnd = 1;

  String scheduleMode = 'exact';
  String? selectedQueueSlotId;
  List<Map<String, dynamic>> queueSlots = [];
  DateTime scheduledAt = DateTime.now().add(const Duration(hours: 1));

  bool previewCaption = true;
  bool autoPostMode = false;

  /// Last full-assist AI results (shown in editor / caption steps).
  int? aiEngagementScore;
  String? aiBestTime;
  String? aiTips;

  bool get isVideo => videoFile != null;

  double? get aspectRatioForCrop {
    switch (aspect) {
      case PostFeedAspect.square:
        return 1;
      case PostFeedAspect.portrait:
        return 4 / 5;
      case PostFeedAspect.reel:
        return 9 / 16;
    }
  }
}

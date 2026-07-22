import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';

import '../../utils/schedule_post_image_export.dart';
import '../../services/scheduler_service.dart';
import 'post_creation_session.dart';

String composeCaption({
  required String caption,
  required String hashtags,
  String? audioUrl,
}) {
  final c = caption.trim();
  final h = hashtags.trim();
  var body = h.isEmpty ? c : '$c\n\n$h';
  if (audioUrl != null && audioUrl.isNotEmpty) {
    body = '$body\n\n🎵 $audioUrl';
  }
  return body;
}

Future<void> submitScheduledPost({
  required PostCreationSession session,
  required String captionText,
  required String hashtagText,
  required SchedulerService scheduler,
}) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) throw Exception('Please sign in first.');

  String? audioUrl;
  if (session.musicFile != null && await session.musicFile!.exists()) {
    audioUrl = await scheduler.uploadAudio(session.musicFile!);
  }
  final cap = composeCaption(caption: captionText, hashtags: hashtagText, audioUrl: audioUrl);

  if (session.isVideo) {
    final v = session.videoFile;
    if (v == null) throw Exception('Please add media');
    final url = await scheduler.uploadMedia(v, isVideo: true);
    if (session.scheduleMode == 'queue') {
      final slotId = session.selectedQueueSlotId;
      if (slotId == null || slotId.isEmpty) throw Exception('Please select queue slot');
      await scheduler.scheduleQueuePost(
        userId: uid,
        queueSlotId: slotId,
        imageUrl: url,
        imageUrls: [url],
        caption: cap,
        isVideo: true,
      );
    } else {
      await scheduler.schedulePost(
        userId: uid,
        imageUrl: url,
        imageUrls: [url],
        caption: cap,
        scheduledAt: session.scheduledAt,
        isVideo: true,
      );
    }
  } else {
    if (session.imageSlots.isEmpty) throw Exception('Please add media');
    final exported = <File>[];
    for (final slot in session.imageSlots) {
      exported.add(await exportEditedImage(slot));
    }
    final urls = await scheduler.uploadMultipleImages(exported);
    if (session.scheduleMode == 'queue') {
      final slotId = session.selectedQueueSlotId;
      if (slotId == null || slotId.isEmpty) throw Exception('Please select queue slot');
      await scheduler.scheduleQueuePost(
        userId: uid,
        queueSlotId: slotId,
        imageUrl: urls.first,
        imageUrls: urls,
        caption: cap,
        isVideo: false,
      );
    } else {
      await scheduler.schedulePost(
        userId: uid,
        imageUrl: urls.first,
        imageUrls: urls,
        caption: cap,
        scheduledAt: session.scheduledAt,
        isVideo: false,
      );
    }
  }
}

/// Heuristic “best engagement” local time (early evening).
DateTime suggestedBestPostTime() {
  final now = DateTime.now();
  var t = DateTime(now.year, now.month, now.day, 18, 30);
  if (!t.isAfter(now)) {
    t = t.add(const Duration(days: 1));
  }
  return t;
}

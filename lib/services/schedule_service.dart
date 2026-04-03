import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/scheduled_post_model.dart';

/// Production Firebase backend for scheduled posts.
/// Uses Firestore scheduled_posts and optional Storage for media.
/// Do NOT store plain access tokens in Firestore; use encrypted value or Functions config.

class ScheduleService {
  ScheduleService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  static const String _collection = 'scheduled_posts';
  static const String _storagePrefix = 'scheduled_media';

  String? get _uid => _auth.currentUser?.uid;

  /// Upload media file to Storage and return download URL. Call before createScheduledPost.
  /// Returns null on error; check [ScheduleServiceResult.error].
  Future<ScheduleServiceResult<String>> uploadMedia(File file, {required String mediaType}) async {
    final uid = _uid;
    if (uid == null) {
      return ScheduleServiceResult.fail('Not signed in');
    }
    try {
      final ext = file.path.split('.').last;
      final ref = _storage.ref().child(_storagePrefix).child(uid).child('${DateTime.now().millisecondsSinceEpoch}.$ext');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      return ScheduleServiceResult.success(url);
    } catch (e) {
      if (kDebugMode) debugPrint('[ScheduleService] uploadMedia: $e');
      return ScheduleServiceResult.fail(e.toString());
    }
  }

  /// Create a scheduled post in Firestore. mediaUrl required for Cloud Function to publish.
  Future<ScheduleServiceResult<String>> createScheduledPost({
    required String caption,
    required String mediaUrl,
    required String mediaType,
    required DateTime scheduledAt,
  }) async {
    final uid = _uid;
    if (uid == null) {
      return ScheduleServiceResult.fail('Not signed in');
    }
    try {
      final ref = _firestore.collection(_collection).doc();
      await ref.set({
        'uid': uid,
        'caption': caption,
        'mediaUrl': mediaUrl,
        'mediaType': mediaType == 'reel' ? 'reel' : 'photo',
        'scheduledAt': Timestamp.fromDate(scheduledAt),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return ScheduleServiceResult.success(ref.id);
    } catch (e) {
      if (kDebugMode) debugPrint('[ScheduleService] createScheduledPost: $e');
      return ScheduleServiceResult.fail(e.toString());
    }
  }

  /// Fetch all scheduled posts for the current user.
  Future<ScheduleServiceResult<List<ScheduledPostModel>>> fetchMyScheduledPosts() async {
    final uid = _uid;
    if (uid == null) {
      return ScheduleServiceResult.fail('Not signed in');
    }
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('uid', isEqualTo: uid)
          .orderBy('scheduledAt', descending: false)
          .get();
      final list = snapshot.docs.map((d) => ScheduledPostModel.fromFirestore(d)).toList();
      return ScheduleServiceResult.success(list);
    } catch (e) {
      if (kDebugMode) debugPrint('[ScheduleService] fetchMyScheduledPosts: $e');
      return ScheduleServiceResult.fail(e.toString());
    }
  }

  /// Delete a scheduled post by id. Only allowed for own posts (enforced by rules).
  Future<ScheduleServiceResult<void>> deleteScheduledPost(String postId) async {
    if (_uid == null) {
      return ScheduleServiceResult.fail('Not signed in');
    }
    try {
      await _firestore.collection(_collection).doc(postId).delete();
      return ScheduleServiceResult.success(null);
    } catch (e) {
      if (kDebugMode) debugPrint('[ScheduleService] deleteScheduledPost: $e');
      return ScheduleServiceResult.fail(e.toString());
    }
  }
}

class ScheduleServiceResult<T> {
  final bool success;
  final T? data;
  final String? error;

  const ScheduleServiceResult._({required this.success, this.data, this.error});

  factory ScheduleServiceResult.success(T data) {
    return ScheduleServiceResult._(success: true, data: data);
  }

  factory ScheduleServiceResult.fail(String message) {
    return ScheduleServiceResult._(success: false, error: message);
  }
}

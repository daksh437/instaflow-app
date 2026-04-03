import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for a scheduled post. Firestore: scheduled_posts/{postId}.
/// Fields: uid, caption, mediaUrl, mediaType (photo|reel), scheduledAt, status, createdAt.

class ScheduledPostModel {
  final String id;
  final String uid;
  final DateTime scheduledAt;
  final String caption;
  final String? mediaUrl;
  final String mediaType; // 'photo' | 'reel'
  final DateTime createdAt;
  final String status; // 'pending' | 'published' | 'failed'

  /// Local-only: path to file before upload (not stored in Firestore).
  final String? imagePath;
  final String? videoPath;

  const ScheduledPostModel({
    required this.id,
    required this.uid,
    required this.scheduledAt,
    required this.caption,
    this.mediaUrl,
    this.mediaType = 'photo',
    required this.createdAt,
    this.status = 'pending',
    this.imagePath,
    this.videoPath,
  });

  bool get isReel => mediaType == 'reel';

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'caption': caption,
      'mediaUrl': mediaUrl ?? '',
      'mediaType': mediaType,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ScheduledPostModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final scheduledAt = (data['scheduledAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    return ScheduledPostModel(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      caption: data['caption'] as String? ?? '',
      mediaUrl: data['mediaUrl'] as String?,
      mediaType: data['mediaType'] as String? ?? 'photo',
      scheduledAt: scheduledAt,
      createdAt: createdAt,
      status: data['status'] as String? ?? 'pending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'scheduledAt': scheduledAt.toIso8601String(),
      'caption': caption,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'createdAt': createdAt.toIso8601String(),
      'status': status,
      'imagePath': imagePath,
      'videoPath': videoPath,
    };
  }

  factory ScheduledPostModel.fromMap(Map<String, dynamic> map) {
    return ScheduledPostModel(
      id: map['id'] as String? ?? '',
      uid: map['uid'] as String? ?? '',
      scheduledAt: DateTime.tryParse(map['scheduledAt'] as String? ?? '') ?? DateTime.now(),
      caption: map['caption'] as String? ?? '',
      mediaUrl: map['mediaUrl'] as String?,
      mediaType: map['mediaType'] as String? ?? 'photo',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      status: map['status'] as String? ?? 'pending',
      imagePath: map['imagePath'] as String?,
      videoPath: map['videoPath'] as String?,
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Feedback document in Firestore (feedback collection).
/// Matches backend: id, userId, userEmail, type, message, screenshotUrl, status, adminReply, createdAt, repliedAt.
class FeedbackModel {
  FeedbackModel({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.type,
    required this.message,
    this.screen,
    this.screenshotUrl,
    this.appVersion,
    required this.status,
    this.adminReply,
    this.createdAt,
    this.repliedAt,
  });

  final String id;
  final String userId;
  final String userEmail;
  final String type;
  final String message;
  final String? screen;
  final String? screenshotUrl;
  final String? appVersion;
  final String status;
  final String? adminReply;
  final DateTime? createdAt;
  final DateTime? repliedAt;

  factory FeedbackModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return FeedbackModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      userEmail: data['userEmail'] as String? ?? '',
      type: data['type'] as String? ?? 'suggestion',
      message: data['message'] as String? ?? '',
      screen: data['screen'] as String?,
      screenshotUrl: data['screenshotUrl'] as String?,
      appVersion: data['appVersion'] as String?,
      status: data['status'] as String? ?? 'open',
      adminReply: data['adminReply'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      repliedAt: (data['repliedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class FeedbackService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _collection = 'feedback';

  /// Submit new feedback. Authenticated user only. Writes to feedback collection with required fields.
  Future<void> submitFeedback({
    required String type,
    required String message,
    String? screen,
    String? screenshotUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      if (kDebugMode) debugPrint('[FeedbackService] submitFeedback: no user');
      throw Exception('Please sign in to send feedback');
    }

    String? appVersion;
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = info.version;
    } catch (e) {
      if (kDebugMode) debugPrint('[FeedbackService] PackageInfo: $e');
    }

    try {
      final ref = _firestore.collection(_collection).doc();
      final data = <String, dynamic>{
        'id': ref.id,
        'userId': user.uid,
        'userEmail': user.email ?? '',
        'type': type,
        'message': message.trim(),
        'screenshotUrl': screenshotUrl?.trim().isEmpty == true ? '' : (screenshotUrl?.trim() ?? ''),
        'status': 'open',
        'adminReply': '',
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (screen != null && screen.trim().isNotEmpty) data['screen'] = screen.trim();
      if (appVersion != null) data['appVersion'] = appVersion;

      await ref.set(data);
      if (kDebugMode) debugPrint('[FeedbackService] submitFeedback: saved ${ref.id}');
    } catch (e) {
      if (kDebugMode) debugPrint('[FeedbackService] submitFeedback: $e');
      rethrow;
    }
  }

  /// Stream of feedback for the current user. Query: userId == currentUser.uid, orderBy createdAt desc.
  Stream<List<FeedbackModel>> getUserFeedbackStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    try {
      return _firestore
          .collection(_collection)
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .handleError((e) {
        if (kDebugMode) debugPrint('[FeedbackService] getUserFeedbackStream: $e');
      }).map((snap) {
        try {
          return snap.docs.map((d) => FeedbackModel.fromFirestore(d)).toList();
        } catch (e) {
          if (kDebugMode) debugPrint('[FeedbackService] getUserFeedbackStream map: $e');
          return <FeedbackModel>[];
        }
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[FeedbackService] getUserFeedbackStream: $e');
      return Stream.value([]);
    }
  }

  /// All feedback for admin. OrderBy createdAt desc. Optional type filter.
  Stream<List<FeedbackModel>> getAllFeedbackStream({String? typeFilter}) {
    try {
      Query<Map<String, dynamic>> q = _firestore
          .collection(_collection)
          .orderBy('createdAt', descending: true);
      if (typeFilter != null && typeFilter.isNotEmpty && typeFilter != 'all') {
        q = q.where('type', isEqualTo: typeFilter);
      }
      return q.snapshots().handleError((e) {
        if (kDebugMode) debugPrint('[FeedbackService] getAllFeedbackStream: $e');
      }).map((snap) {
        try {
          return snap.docs.map((d) => FeedbackModel.fromFirestore(d)).toList();
        } catch (e) {
          if (kDebugMode) debugPrint('[FeedbackService] getAllFeedbackStream map: $e');
          return <FeedbackModel>[];
        }
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[FeedbackService] getAllFeedbackStream: $e');
      return Stream.value([]);
    }
  }

  /// Admin reply: update status, adminReply, repliedAt.
  Future<void> replyToFeedback(String feedbackId, String replyText) async {
    if (replyText.trim().isEmpty) throw Exception('Reply cannot be empty');
    try {
      await _firestore.collection(_collection).doc(feedbackId).update({
        'status': 'replied',
        'adminReply': replyText.trim(),
        'repliedAt': FieldValue.serverTimestamp(),
      });
      if (kDebugMode) debugPrint('[FeedbackService] replyToFeedback: $feedbackId');
    } catch (e) {
      if (kDebugMode) debugPrint('[FeedbackService] replyToFeedback: $e');
      rethrow;
    }
  }

  /// Set status to closed.
  Future<void> closeFeedback(String feedbackId) async {
    try {
      await _firestore.collection(_collection).doc(feedbackId).update({
        'status': 'closed',
      });
      if (kDebugMode) debugPrint('[FeedbackService] closeFeedback: $feedbackId');
    } catch (e) {
      if (kDebugMode) debugPrint('[FeedbackService] closeFeedback: $e');
      rethrow;
    }
  }
}

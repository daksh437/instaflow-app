import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Save AI-generated content to history
  Future<void> saveHistory({
    required String serviceType,
    required String input,
    required String output,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('ai_history').add({
        'userId': user.uid,
        'serviceType': serviceType,
        'input': input,
        'output': output,
        'metadata': metadata ?? {},
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('[HistoryService] Error saving history: $e');
    }
  }

  /// Get history for a specific service type
  Stream<List<Map<String, dynamic>>> getHistoryByService(String serviceType) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('ai_history')
        .where('userId', isEqualTo: user.uid)
        .where('serviceType', isEqualTo: serviceType)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                ...data,
                'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
              };
            }).toList());
  }

  /// Alias for unified naming across AI tools pages.
  Stream<List<Map<String, dynamic>>> getHistoryByToolType(String toolType) {
    return getHistoryByService(toolType);
  }

  /// Get all history
  Stream<List<Map<String, dynamic>>> getAllHistory() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('ai_history')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                ...data,
                'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
              };
            }).toList());
  }

  /// Delete a history item
  Future<void> deleteHistory(String historyId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User must be logged in to delete history');
      }

      // Verify the document belongs to the user before deleting
      final doc = await _firestore.collection('ai_history').doc(historyId).get();
      if (!doc.exists) {
        throw Exception('History item not found');
      }

      final data = doc.data();
      if (data?['userId'] != user.uid) {
        throw Exception('Permission denied: You can only delete your own history');
      }

      await _firestore.collection('ai_history').doc(historyId).delete();
    } catch (e) {
      print('[HistoryService] Error deleting history: $e');
      rethrow;
    }
  }

  /// Clear all history for a service type
  Future<void> clearHistoryByService(String serviceType) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final batch = _firestore.batch();
      final snapshot = await _firestore
          .collection('ai_history')
          .where('userId', isEqualTo: user.uid)
          .where('serviceType', isEqualTo: serviceType)
          .get();

      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      print('[HistoryService] Error clearing history: $e');
      rethrow;
    }
  }
}


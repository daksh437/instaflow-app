import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Safe Firestore helpers: try/catch + null safety. Never throw to caller.
class FirestoreHelpers {
  FirestoreHelpers._();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Duration _timeout = Duration(seconds: 8);

  /// Safe get document. Returns null on error or if doc doesn't exist.
  static Future<DocumentSnapshot<Map<String, dynamic>>?> safeGetDoc(String collection, String docId) async {
    try {
      final snap = await _firestore.collection(collection).doc(docId).get().timeout(_timeout);
      return snap;
    } catch (e) {
      if (kDebugMode) debugPrint('[FirestoreHelpers] safeGetDoc $collection/$docId: $e');
      return null;
    }
  }

  /// Safe get document data. Returns null on error or if doc doesn't exist.
  static Future<Map<String, dynamic>?> safeGetDocData(String collection, String docId) async {
    try {
      final snap = await _firestore.collection(collection).doc(docId).get().timeout(_timeout);
      if (snap.exists && snap.data() != null) return snap.data();
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[FirestoreHelpers] safeGetDocData $collection/$docId: $e');
      return null;
    }
  }

  /// Safe set document. Returns true on success, false on error.
  static Future<bool> safeSetDoc(
    String collection,
    String docId,
    Map<String, dynamic> data, {
    bool merge = false,
  }) async {
    try {
      await _firestore.collection(collection).doc(docId).set(data, SetOptions(merge: merge));
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[FirestoreHelpers] safeSetDoc $collection/$docId: $e');
      return false;
    }
  }

  /// Safe update document. Returns true on success, false on error.
  static Future<bool> safeUpdateDoc(String collection, String docId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(collection).doc(docId).update(data);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[FirestoreHelpers] safeUpdateDoc $collection/$docId: $e');
      return false;
    }
  }

  /// Safe add document. Returns doc id on success, null on error.
  static Future<String?> safeAddDoc(String collection, Map<String, dynamic> data) async {
    try {
      final ref = await _firestore.collection(collection).add(data);
      return ref.id;
    } catch (e) {
      if (kDebugMode) debugPrint('[FirestoreHelpers] safeAddDoc $collection: $e');
      return null;
    }
  }

  /// Safe query: get docs. Returns empty list on error.
  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> safeQuery(
    Query<Map<String, dynamic>> query, {
    int? limit,
  }) async {
    try {
      var q = query;
      if (limit != null) q = q.limit(limit);
      final snap = await q.get();
      return snap.docs;
    } catch (e) {
      if (kDebugMode) debugPrint('[FirestoreHelpers] safeQuery: $e');
      return [];
    }
  }
}

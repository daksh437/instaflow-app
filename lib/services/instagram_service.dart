import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../models/analytics_model.dart';
import 'api_service.dart';

class InstagramService {
  Future<bool> login() async {
    final result = await connectInstagram();
    return result['success'] == true;
  }

  Future<void> logout() async {
    // We intentionally do not clear backend token here to avoid accidental disconnect.
  }

  Future<bool> isLoggedIn() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return false;
    final uri =
        Uri.parse('${ApiService.baseUrl}/auth/instagram/status').replace(
      queryParameters: {'state': uid},
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || decoded['success'] != true) return false;
    return decoded['connected'] == true && decoded['tokenExpired'] != true;
  }

  Future<Map<String, dynamic>> connectInstagram(
      [String? legacyUserId, String? legacyAccessToken, String? pageId]) async {
    final uid = legacyUserId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) throw Exception('User not logged in');

    final connectRes = await http
        .post(
          Uri.parse('${ApiService.baseUrl}/instagram-connect'),
          headers: <String, String>{
            'Content-Type': 'application/json',
            'x-user-uid': uid,
          },
          body: jsonEncode({'userId': uid}),
        )
        .timeout(const Duration(seconds: 20));
    final connectBody = jsonDecode(connectRes.body) as Map<String, dynamic>;
    if (connectRes.statusCode >= 400 || connectBody['success'] != true) {
      throw Exception(connectBody['error']?.toString() ??
          'Failed to start Instagram OAuth');
    }
    final authUrlRaw = connectBody['authUrl']?.toString() ?? '';
    if (authUrlRaw.isEmpty) {
      throw Exception('Backend did not return Instagram OAuth URL');
    }
    final authUrl = Uri.parse(authUrlRaw);

    final launched = await launchUrl(
      authUrl,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!launched) throw Exception('Unable to open Instagram login');

    final result =
        await waitForInstagramConnection(timeout: const Duration(minutes: 2));
    if (!result) {
      throw Exception('Instagram login not completed. Try again.');
    }
    return {'success': true};
  }

  Future<Map<String, dynamic>> fetchInstagramStats() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) throw Exception('User not logged in');

    return _withRetry(() async {
      final uri = Uri.parse('${ApiService.baseUrl}/instagram-stats');
      final response = await http.get(
        uri,
        headers: <String, String>{
          'x-user-id': uid,
          'x-user-uid': uid,
        },
      ).timeout(const Duration(seconds: 45));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400 || decoded['success'] == false) {
        throw Exception(
            decoded['error']?.toString() ?? 'Failed to load Instagram stats');
      }
      final merged = <String, dynamic>{
        'followers': (decoded['followers'] as num?)?.toInt() ?? 0,
        'following': (decoded['following'] as num?)?.toInt() ?? 0,
        'posts': (decoded['posts'] as num?)?.toInt() ?? 0,
        'likes': (decoded['likes'] as num?)?.toInt() ?? 0,
        'comments': (decoded['comments'] as num?)?.toInt() ?? 0,
        'views': (decoded['views'] as num?)?.toInt() ?? 0,
        'accountType': decoded['accountType']?.toString() ?? '',
      };
      for (final e in decoded.entries) {
        if (e.key == 'success' || e.key == 'error') continue;
        merged.putIfAbsent(e.key, () => e.value);
      }
      return merged;
    });
  }

  Future<bool> hasExistingInstagramAccount(String userId) async {
    try {
      final stats = await fetchInstagramStats();
      return (stats['followers'] as int? ?? 0) >= 0;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getUserProfile(String _) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) throw Exception('User not logged in');
    final uri =
        Uri.parse('${ApiService.baseUrl}/auth/instagram/status').replace(
      queryParameters: {'state': uid},
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || decoded['success'] != true) {
      throw Exception(
          decoded['error']?.toString() ?? 'Failed to fetch profile');
    }
    final stats = await fetchInstagramStats();
    return <String, dynamic>{
      'username': decoded['username']?.toString() ?? '',
      'account_type': stats['accountType']?.toString() ?? 'BUSINESS',
      'followers_count': stats['followers'],
      'follows_count': stats['following'],
      'media_count': stats['posts'],
    };
  }

  Future<AnalyticsModel?> fetchAnalytics(String userId, dynamic _) async {
    try {
      final stats = await fetchInstagramStats();
      return AnalyticsModel(
        userId: userId,
        followers: stats['followers'] as int? ?? 0,
        following: stats['following'] as int? ?? 0,
        posts: stats['posts'] as int? ?? 0,
        engagementRate: 0,
        totalReach: 0,
        totalLikes: 0,
        totalComments: 0,
        topPosts: const <PostPerformance>[],
        lastUpdated: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> waitForInstagramConnection(
      {Duration timeout = const Duration(minutes: 2)}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return false;
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final uri =
          Uri.parse('${ApiService.baseUrl}/auth/instagram/status').replace(
        queryParameters: {'state': uid},
      );
      try {
        final response =
            await http.get(uri).timeout(const Duration(seconds: 20));
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        if (response.statusCode == 200 && decoded['success'] == true) {
          final connected = decoded['connected'] == true;
          final tokenExpired = decoded['tokenExpired'] == true;
          if (connected && !tokenExpired) return true;
        }
      } catch (_) {}
      await Future<void>.delayed(const Duration(seconds: 3));
    }
    return false;
  }

  Future<T> _withRetry<T>(Future<T> Function() action) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await action();
      } on TimeoutException catch (e) {
        lastError = e;
      } on SocketException catch (e) {
        lastError = e;
      } catch (e) {
        lastError = e;
      }
      if (attempt < 2) {
        await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
    throw Exception(lastError.toString());
  }
}

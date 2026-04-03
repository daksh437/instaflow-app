import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/instagram_model.dart';
import '../models/analytics_model.dart';

const _storageKeyToken = 'ig_graph_access_token';
const _storageKeyUserId = 'ig_graph_user_id';
const _graphBase = 'https://graph.facebook.com/v25.0';
const _permissions = [
  'instagram_business_basic',
  'instagram_business_content_publish',
  'instagram_business_manage_messages',
  'instagram_business_manage_comments',
  'pages_show_list',
  'pages_read_engagement',
];

class InstagramService {
  InstagramService() : _storage = const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));

  final FlutterSecureStorage _storage;

  Future<String?> getStoredToken() => _storage.read(key: _storageKeyToken);
  Future<String?> getStoredIgUserId() => _storage.read(key: _storageKeyUserId);

  Future<bool> isLoggedIn() async {
    final token = await getStoredToken();
    if (token != null && token.isNotEmpty) return true;
    final result = await FacebookAuth.instance.accessToken;
    return result != null;
  }

  Future<String?> login() async {
    try {
      final result = await FacebookAuth.instance.login(
        permissions: _permissions,
      );
      if (result.status != LoginStatus.success) {
        if (kDebugMode) debugPrint('[InstagramService] Login status: ${result.status}');
        return null;
      }
      final token = result.accessToken;
      if (token == null) return null;
      final accessToken = token.tokenString;
      await _storage.write(key: _storageKeyToken, value: accessToken);
      return accessToken;
    } catch (e) {
      if (kDebugMode) debugPrint('[InstagramService] login error: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    await FacebookAuth.instance.logOut();
    await _storage.delete(key: _storageKeyToken);
    await _storage.delete(key: _storageKeyUserId);
  }

  Future<String?> _getValidToken() async {
    String? token = await getStoredToken();
    if (token != null && token.isNotEmpty) return token;
    final fbToken = await FacebookAuth.instance.accessToken;
    if (fbToken != null) {
      token = fbToken.tokenString;
      await _storage.write(key: _storageKeyToken, value: token);
      return token;
    }
    return null;
  }

  Future<Map<String, dynamic>?> _get(String path, {Map<String, String>? query}) async {
    final token = await _getValidToken();
    if (token == null) return null;
    final uri = Uri.parse('$_graphBase$path').replace(queryParameters: {
      'access_token': token,
      ...?query,
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
    if (decoded != null && decoded['error'] != null) return null;
    return decoded;
  }

  Future<String?> getInstagramBusinessAccountId() async {
    String? igUserId = await getStoredIgUserId();
    if (igUserId != null && igUserId.isNotEmpty) return igUserId;

    final pages = await _get('/me/accounts', query: {'fields': 'access_token,instagram_business_account'});
    final data = pages?['data'] as List<dynamic>?;
    if (data == null || data.isEmpty) return null;

    for (final page in data) {
      final map = page is Map<String, dynamic> ? page : {};
      final igAccount = map['instagram_business_account'];
      if (igAccount != null) {
        final id = igAccount is Map ? (igAccount['id']?.toString()) : igAccount.toString();
        if (id != null && id.isNotEmpty) {
          igUserId = id;
          await _storage.write(key: _storageKeyUserId, value: igUserId);
          return igUserId;
        }
      }
    }
    return null;
  }

  Future<IgProfile?> fetchProfile(String igUserId) async {
    final data = await _get('/$igUserId', query: {
      'fields': 'followers_count,follows_count,media_count,username,profile_picture_url',
    });
    if (data == null) return null;
    return IgProfile.fromJson(data);
  }

  Future<List<IgMedia>> fetchMedia(String igUserId, {int limit = 24}) async {
    final data = await _get('/$igUserId/media', query: {
      'fields': 'id,caption,media_type,media_url,timestamp,like_count,comments_count',
      'limit': limit.toString(),
    });
    final list = data?['data'] as List<dynamic>?;
    if (list == null) return [];
    return list
        .map((e) => IgMedia.fromJson(e is Map<String, dynamic> ? e : {}))
        .toList();
  }

  Future<IgInsights> fetchInsights(String igUserId) async {
    final data = await _get('/$igUserId/insights', query: {
      'metric': 'impressions,reach,profile_views',
      'period': 'day',
    });
    final list = data?['data'] as List<dynamic>?;
    return IgInsights.fromMetrics(list);
  }

  Future<List<IgComment>> fetchComments(String mediaId) async {
    final data = await _get('/$mediaId/comments', query: {
      'fields': 'id,text,username,timestamp',
    });
    final list = data?['data'] as List<dynamic>?;
    if (list == null) return [];
    return list
        .map((e) => IgComment.fromJson(e is Map<String, dynamic> ? e : {}))
        .toList();
  }

  /// Returns analytics for existing screens (analytics_screen, stats_service). Uses stored token/IG account when connected.
  Future<AnalyticsModel?> fetchAnalytics(String userId, dynamic _) async {
    try {
      final igUserId = await getInstagramBusinessAccountId();
      if (igUserId == null) return null;
      final profile = await fetchProfile(igUserId);
      final mediaList = await fetchMedia(igUserId, limit: 50);
      final insights = await fetchInsights(igUserId);
      if (profile == null) return null;
      final totalLikes = mediaList.fold<int>(0, (s, m) => s + m.likeCount);
      final totalComments = mediaList.fold<int>(0, (s, m) => s + m.commentsCount);
      final reach = insights?.reach ?? 0;
      final topPosts = mediaList.take(10).map((m) {
        return PostPerformance(
          postId: m.id,
          likes: m.likeCount,
          comments: m.commentsCount,
          reach: reach ~/ (mediaList.isEmpty ? 1 : mediaList.length),
          postedAt: m.timestamp != null ? DateTime.tryParse(m.timestamp!) ?? DateTime.now() : DateTime.now(),
        );
      }).toList();
      final engagementRate = profile.followersCount > 0
          ? (totalLikes + totalComments * 2) / profile.followersCount * 100
          : 0.0;
      return AnalyticsModel(
        userId: userId,
        followers: profile.followersCount,
        following: profile.followsCount,
        posts: profile.mediaCount,
        engagementRate: engagementRate.clamp(0.0, 100.0),
        totalReach: insights?.impressions ?? reach,
        totalLikes: totalLikes,
        totalComments: totalComments,
        topPosts: topPosts,
        lastUpdated: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }
}

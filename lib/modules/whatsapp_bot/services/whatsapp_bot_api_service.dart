import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../config/app_secrets.dart';

/// HTTP client for WhatsApp Bot backend endpoints.
/// Failures are non-fatal for UI; callers may ignore errors.
class WhatsAppBotApiService {
  WhatsAppBotApiService({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;

  Uri _url(String path) {
    final base = AppSecrets.whatsappBotApiBaseUrl.replaceAll(RegExp(r'/$'), '');
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$p');
  }

  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final token = await user.getIdToken();
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[WhatsAppBotApi] getIdToken: $e');
      }
    }
    return headers;
  }

  /// Called after Meta OAuth redirect succeeds (WebView callback).
  Future<void> connectWhatsApp({
    required String accessToken,
    String? code,
  }) async {
    final uri = _url('/whatsapp-bot/connect');
    final body = jsonEncode({
      'accessToken': accessToken,
      if (code != null) 'code': code,
    });
    final res = await _http
        .post(uri, headers: await _headers(), body: body)
        .timeout(const Duration(seconds: 15));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw WhatsAppBotApiException(
        'connectWhatsApp failed: ${res.statusCode} ${res.body}',
      );
    }
  }

  /// Outbound message to a chat (dashboard / automation).
  Future<void> sendMessage({
    required String chatId,
    required String text,
  }) async {
    final uri = _url('/whatsapp-bot/send-message');
    final body = jsonEncode({
      'chatId': chatId,
      'text': text,
    });
    final res = await _http
        .post(uri, headers: await _headers(), body: body)
        .timeout(const Duration(seconds: 15));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw WhatsAppBotApiException(
        'sendMessage failed: ${res.statusCode} ${res.body}',
      );
    }
  }

  /// List chats (server may return cached or live data).
  Future<List<Map<String, dynamic>>> getChats() async {
    final uri = _url('/whatsapp-bot/chats');
    final res = await _http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 15));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw WhatsAppBotApiException(
        'getChats failed: ${res.statusCode} ${res.body}',
      );
    }
    final decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) {
      final list = decoded['chats'];
      if (list is List) {
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    }
    return [];
  }
}

class WhatsAppBotApiException implements Exception {
  WhatsAppBotApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

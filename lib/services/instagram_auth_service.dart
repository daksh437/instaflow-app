import 'package:flutter/foundation.dart';
import 'instagram_service.dart';

/// Handles Instagram Business login state.
/// Backed by Node API + Firestore stored tokens.

class InstagramAuthService {
  InstagramAuthService._();
  static final InstagramAuthService _instance = InstagramAuthService._();
  static InstagramAuthService get instance => _instance;

  final InstagramService _instagramService = InstagramService();
  bool _isLoggedIn = false;

  bool get isLoggedIn => _isLoggedIn;

  /// Initialize from backend status.
  Future<void> init() async {
    try {
      _isLoggedIn = await _instagramService.isLoggedIn();
    } catch (e) {
      if (kDebugMode) debugPrint('[InstagramAuthService] init error: $e');
      _isLoggedIn = false;
    }
  }

  /// Opens Instagram Business OAuth in browser and waits for callback completion.
  Future<bool> login() async {
    try {
      final connected = await _instagramService.connectInstagram();
      _isLoggedIn = connected == true;
      return _isLoggedIn;
    } catch (e) {
      if (kDebugMode) debugPrint('[InstagramAuthService] login error: $e');
      _isLoggedIn = false;
      return false;
    }
  }

  /// Local logout state reset; backend disconnect endpoint can be added if needed.
  Future<void> logout() async {
    try {
      await _instagramService.logout();
      _isLoggedIn = false;
    } catch (e) {
      if (kDebugMode) debugPrint('[InstagramAuthService] logout error: $e');
    }
  }

  /// Direct token access is intentionally not exposed to app layer.
  Future<String?> getAccessToken() async {
    return null;
  }
}

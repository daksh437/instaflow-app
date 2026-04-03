import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles Instagram Business / Facebook login and token storage.
/// Isolated layer for full Instagram Business automation.
///
/// TODO: Insert Facebook App ID, Client Token, App Secret and wire real Facebook Login SDK.
/// TODO: Replace placeholder token storage with secure storage + long-lived token exchange.
const String _keyTokenPlaceholder = 'ig_business_automation_token_placeholder';
const String _keyIsLoggedIn = 'ig_business_automation_logged_in';

class InstagramAuthService {
  InstagramAuthService._();
  static final InstagramAuthService _instance = InstagramAuthService._();
  static InstagramAuthService get instance => _instance;

  bool _isLoggedIn = false;
  String? _storedTokenPlaceholder;

  bool get isLoggedIn => _isLoggedIn;
  String? get tokenPlaceholder => _storedTokenPlaceholder;

  /// Initialize from local storage (placeholder). Call on app start.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
      _storedTokenPlaceholder = prefs.getString(_keyTokenPlaceholder);
    } catch (e) {
      if (kDebugMode) debugPrint('[InstagramAuthService] init error: $e');
    }
  }

  /// Login placeholder. No real API call.
  /// TODO: Replace with real Facebook Login using App ID + Client Token; request instagram_business_* permissions.
  /// TODO: Exchange short-lived for long-lived token using App Secret (server-side recommended).
  Future<bool> login() async {
    await Future.delayed(const Duration(milliseconds: 600)); // Simulate network
    try {
      final prefs = await SharedPreferences.getInstance();
      const mockToken = 'mock_ig_business_token_replace_with_real';
      await prefs.setString(_keyTokenPlaceholder, mockToken);
      await prefs.setBool(_keyIsLoggedIn, true);
      _storedTokenPlaceholder = mockToken;
      _isLoggedIn = true;
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[InstagramAuthService] login error: $e');
      return false;
    }
  }

  /// Logout and clear stored token.
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyTokenPlaceholder);
      await prefs.setBool(_keyIsLoggedIn, false);
      _storedTokenPlaceholder = null;
      _isLoggedIn = false;
    } catch (e) {
      if (kDebugMode) debugPrint('[InstagramAuthService] logout error: $e');
    }
  }

  /// Returns token for API calls. Placeholder until real API is connected.
  /// TODO: Return real access token from Facebook Login / token storage.
  Future<String?> getAccessToken() async {
    if (_storedTokenPlaceholder != null) return _storedTokenPlaceholder;
    await init();
    return _storedTokenPlaceholder;
  }
}

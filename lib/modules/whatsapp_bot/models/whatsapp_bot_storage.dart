import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'whatsapp_bot_setup.dart';

class WhatsAppBotStorage {
  static const String _kSetupKey = 'whatsapp_bot_setup_v1';

  static Future<WhatsAppBotSetup> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kSetupKey);
      if (raw == null || raw.isEmpty) return WhatsAppBotSetup.empty();
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return WhatsAppBotSetup.fromJson(decoded);
      }
      return WhatsAppBotSetup.empty();
    } catch (_) {
      return WhatsAppBotSetup.empty();
    }
  }

  static Future<void> save(WhatsAppBotSetup setup) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSetupKey, jsonEncode(setup.toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSetupKey);
  }
}


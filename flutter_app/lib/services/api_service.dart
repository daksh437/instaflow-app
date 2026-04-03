import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

const String baseUrl = 'https://insta-flow-backend.onrender.com';

class ApiService {
  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final res = await http.get(Uri.parse('$baseUrl$path'));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<String?> getAuthUrl() async {
    final data = await _get('/auth/url');
    return data['data']?['url'] as String?;
  }

  Future<bool> getAuthStatus({String userId = 'demo-user'}) async {
    final data = await _get('/auth/status?userId=$userId');
    return data['data']?['connected'] == true;
  }

  Future<List<dynamic>> generateCaptions({required String topic, required String tone}) async {
    final data = await _post('/ai/captions', {'topic': topic, 'tone': tone});
    return (data['data'] as List?) ?? [];
  }

  Future<List<dynamic>> generateCalendar({required String topic, int days = 7}) async {
    final data = await _post('/ai/calendar', {'topic': topic, 'days': days});
    return (data['data'] as List?) ?? [];
  }

  Future<Map<String, dynamic>> generateStrategy({required String niche}) async {
    final data = await _post('/ai/strategy', {'niche': niche});
    return (data['data'] as Map?)?.cast<String, dynamic>() ?? {};
  }

  Future<bool> scheduleEvent({
    required String userId,
    required String title,
    required String description,
    required String startDateTime,
    required String endDateTime,
  }) async {
    final data = await _post('/calendar/create', {
      'userId': userId,
      'title': title,
      'description': description,
      'startDateTime': startDateTime,
      'endDateTime': endDateTime,
    });
    return data['success'] == true;
  }

  Future<void> openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}


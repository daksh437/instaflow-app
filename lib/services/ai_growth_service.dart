import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';

import 'api_service.dart';

/// Instagram growth endpoints: `/ai/full-assist`, `/ai/caption`, `/ai/analyze-post`.
class AiGrowthService {
  AiGrowthService({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  Future<FullAssistResult> fullAssist({
    String? imageUrl,
    String? imageBase64,
    String imageMimeType = 'image/jpeg',
    String? topic,
  }) async {
    if (FirebaseAuth.instance.currentUser == null) {
      throw Exception('Sign in to use AI Assist');
    }
    final body = <String, dynamic>{
      if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
      if (imageBase64 != null && imageBase64.isNotEmpty) 'imageBase64': imageBase64,
      'imageMimeType': imageMimeType,
      if (topic != null && topic.isNotEmpty) 'topic': topic,
    };
    final map = await _api.postAiFullAssist(body);
    if (map['success'] != true) {
      throw Exception(map['details']?.toString() ?? map['error']?.toString() ?? 'Full assist failed');
    }
    final hashtags = (map['hashtags'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    return FullAssistResult(
      enhancedImageDataUrl: map['enhancedImage']?.toString(),
      caption: map['caption']?.toString() ?? '',
      hashtags: hashtags,
      engagementScore: (map['engagementScore'] as num?)?.toInt() ?? 0,
      bestTime: map['bestTime']?.toString() ?? '',
      tips: map['tips']?.toString() ?? '',
    );
  }

  Future<FullAssistResult> fullAssistFromFile(File file, {String? topic}) async {
    final bytes = await file.readAsBytes();
    final b64 = base64Encode(bytes);
    return fullAssist(imageBase64: b64, topic: topic);
  }

  Future<String> viralCaption({String? topic, String? imageBase64, String imageMimeType = 'image/jpeg'}) async {
    if (FirebaseAuth.instance.currentUser == null) {
      throw Exception('Sign in to use AI');
    }
    final map = await _api.postAiViralCaption({
      if (topic != null) 'topic': topic,
      if (imageBase64 != null) 'imageBase64': imageBase64,
      'imageMimeType': imageMimeType,
    });
    if (map['success'] != true) {
      throw Exception(map['details']?.toString() ?? 'Caption failed');
    }
    return map['caption']?.toString() ?? '';
  }

  Future<PostAnalyzeResult> analyzePost({required String caption, required String hashtags}) async {
    if (FirebaseAuth.instance.currentUser == null) {
      throw Exception('Sign in to use AI');
    }
    final map = await _api.postAiAnalyzePost({'caption': caption, 'hashtags': hashtags});
    if (map['success'] != true) {
      throw Exception(map['details']?.toString() ?? 'Analyze failed');
    }
    final sugg = (map['suggestions'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    return PostAnalyzeResult(
      engagementScore: (map['engagementScore'] as num?)?.toInt() ?? 0,
      bestTime: map['bestTime']?.toString() ?? '',
      tips: map['tips']?.toString() ?? '',
      suggestions: sugg,
    );
  }
}

class FullAssistResult {
  FullAssistResult({
    required this.enhancedImageDataUrl,
    required this.caption,
    required this.hashtags,
    required this.engagementScore,
    required this.bestTime,
    required this.tips,
  });

  final String? enhancedImageDataUrl;
  final String caption;
  final List<String> hashtags;
  final int engagementScore;
  final String bestTime;
  final String tips;
}

class PostAnalyzeResult {
  PostAnalyzeResult({
    required this.engagementScore,
    required this.bestTime,
    required this.tips,
    required this.suggestions,
  });

  final int engagementScore;
  final String bestTime;
  final String tips;
  final List<String> suggestions;
}

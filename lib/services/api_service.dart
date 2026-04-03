import 'dart:convert';
import 'dart:async';
import 'dart:io'; // For SocketException
import 'dart:math'; // For min() function
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/ai_performance_config.dart';
import '../utils/ai_access_exception.dart';
import '../utils/ai_prompt_trim.dart';
import '../utils/ai_prompt_validation.dart';

class ApiService {
  static final http.Client _sharedClient = http.Client();
  ApiService({http.Client? client}) : _client = client ?? _sharedClient;

  final http.Client _client;
  
  // CRITICAL FIX: No static Futures or cached responses - each call is fresh
  
  // Production backend URL - Single source of truth for all AI services
  static const String baseUrl = "https://insta-flow-backend.onrender.com";

  Map<String, String> _buildHeaders() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept-Encoding': 'gzip',
      'Cache-Control': 'no-cache, no-store, must-revalidate',
      'Pragma': 'no-cache',
      'Expires': '0',
      'X-Request-Time': DateTime.now().millisecondsSinceEpoch.toString(),
    };
    
    // Add user ID header if user is logged in
    if (uid != null) {
      headers['x-user-uid'] = uid;
      print('[API] ✅ Header added: x-user-uid = $uid');
    } else {
      print('[API] ⚠️ No user ID available - user not logged in');
    }
    
    return headers;
  }

  Future<Map<String, dynamic>> _get(String path) async {
    try {
      print('🔵 [API] GET Request: $baseUrl$path');
      
      final headers = _buildHeaders();
      final res = await _client
          .get(Uri.parse('$baseUrl$path'), headers: headers)
          .timeout(const Duration(seconds: 30));
      
      print('✅ [API] Response Status: ${res.statusCode}');
      
      if (res.statusCode == 200) {
        try {
          return jsonDecode(res.body) as Map<String, dynamic>;
        } catch (e) {
          throw Exception('Invalid JSON response: ${e.toString()}');
        }
      } else {
        throw Exception('Server error: ${res.statusCode} - ${res.body}');
      }
    } on SocketException catch (e) {
      print('❌ [API] Error: $e');
      throw Exception('CONNECTION_ERROR: Cannot connect to backend at $baseUrl. Make sure server is running and device is connected.');
    } on TimeoutException catch (e) {
      print('❌ [API] Error: $e');
      throw Exception('TIMEOUT_ERROR: Request timed out. Check your connection.');
    } catch (e) {
      print('❌ [API] Error: $e');
      throw Exception('Request failed: ${e.toString()}');
    }
  }

  Map<String, dynamic> _trimBody(Map<String, dynamic> body) {
    final out = Map<String, dynamic>.from(body);
    const promptKeys = ['topic', 'text', 'niche', 'description', 'comment', 'caption'];
    for (final k in promptKeys) {
      if (out[k] is String) out[k] = trimPromptForAi(out[k] as String);
    }
    return out;
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body, {Function(String)? onRetry}) async {
    final trimmedBody = _trimBody(body);
    int attempt = 0;
    final requestTimestamp = DateTime.now().millisecondsSinceEpoch;
    print('[API] 🔵 POST Request #$requestTimestamp to: $baseUrl$path');
    
    while (true) {
      attempt++;
      try {
        final headers = _buildHeaders();
        final requestBodyJson = jsonEncode(trimmedBody);
        final res = await _client
            .post(
              Uri.parse('$baseUrl$path'),
              headers: headers,
              body: requestBodyJson,
            )
            .timeout(Duration(seconds: AiPerformanceConfig.requestTimeoutSeconds));
        
        print('[API] ✅ Response #$requestTimestamp Status: ${res.statusCode}');
        print('[API] 📄 Response Body (first 500 chars): ${res.body.length > 500 ? res.body.substring(0, 500) + "..." : res.body}');
        
        if (res.statusCode == 200) {
          try {
            return jsonDecode(res.body) as Map<String, dynamic>;
          } catch (e) {
            throw Exception('Invalid JSON response: ${e.toString()}');
          }
        }
        if (res.statusCode == 403) {
          try {
            final errBody = jsonDecode(res.body) as Map<String, dynamic>?;
            final code = errBody?['code'] ?? errBody?['error'];
            if (code == 'DAILY_LIMIT_REACHED') {
              final msg = errBody?['message'] as String? ?? 'Daily AI limit reached.';
              throw DailyLimitReachedException(msg);
            }
          } catch (e) {
            if (e is DailyLimitReachedException) rethrow;
          }
        }
        throw Exception('Server error: ${res.statusCode} - ${res.body}');
      } on SocketException catch (e) {
        print('❌ [API] Error: $e');
        if (attempt < 2) {
          if (onRetry != null) onRetry('Waking up AI server...');
          await Future.delayed(Duration(milliseconds: (AiPerformanceConfig.retryBackoffSeconds * 1000).round()));
          continue;
        }
        throw Exception('CONNECTION_ERROR: Cannot connect to backend at $baseUrl.');
      } on TimeoutException catch (e) {
        print('❌ [API] Error: $e');
        if (attempt < 2) {
          if (onRetry != null) onRetry('Retrying...');
          await Future.delayed(Duration(milliseconds: (AiPerformanceConfig.retryBackoffSeconds * 1000).round()));
          continue;
        }
        throw Exception('TIMEOUT_ERROR: Request timed out after 25 seconds.');
      } catch (e) {
        print('❌ [API] Error: $e');
        if (e is DailyLimitReachedException) rethrow;
        throw Exception('Request failed: ${e.toString()}');
      }
    }
  }

  /// Check AI access (backend is source of truth). Returns allowed, planType, trialDaysLeft, creditsLeftToday.
  ///
  /// **LINT / BYPASS PROTECTION:** All AI generation methods below (create*Job, generateCaptions,
  /// generateImageCaptions, generateCaptionFromMedia, etc.) must ONLY be called after
  /// [runWithBackendAiGuard] or equivalent. Do not call them directly from UI without the guard.
  Future<Map<String, dynamic>> checkAiAccess() async {
    try {
      final data = await _get('/check-ai-access');
      return data;
    } catch (e) {
      print('[API] ❌ checkAiAccess failed: $e');
      rethrow;
    }
  }

  /// Get job status (unified endpoint for all AI jobs)
  Future<Map<String, dynamic>> getJobStatus(String jobId) async {
    try {
      print('[API] 🔍 Checking job status for: $jobId');
      final data = await _get('/ai/job-status/$jobId');
      print('[API] 📊 Job status response: status=${data['status']}, hasData=${data['data'] != null}');
      if (data['data'] != null) {
        print('[API] 📦 Data type: ${data['data'].runtimeType}, length: ${data['data'] is List ? (data['data'] as List).length : 'N/A'}');
      }
      return data;
    } catch (e) {
      print('[API] ❌ Error getting job status: $e');
      rethrow;
    }
  }

  /// Poll job status until done or timeout
  Future<Map<String, dynamic>> pollJobUntilDone(
    String jobId, {
    Duration pollInterval = const Duration(seconds: 2),
    Duration timeout = const Duration(seconds: 60),
    Function(String)? onStatusUpdate,
  }) async {
    final startTime = DateTime.now();
    
    while (true) {
      if (DateTime.now().difference(startTime) > timeout) {
        throw Exception('TIMEOUT_ERROR: Job polling timed out after ${timeout.inSeconds} seconds');
      }
      
      try {
        final statusData = await getJobStatus(jobId);
        final status = statusData['status'] as String?;
        
        print('[API] Job $jobId status: $status');
        
        if (onStatusUpdate != null && status != null) {
          onStatusUpdate(status);
        }
        
        if (status == 'done' || status == 'completed') {
          final data = statusData['data'];
          if (data != null) {
            return data as Map<String, dynamic>;
          } else {
            throw Exception('Job completed but no data returned');
          }
        } else if (status == 'error') {
          final error = statusData['error'] as String? ?? 'AI generation failed';
          final data = statusData['data'];
          if (data != null) {
            return data as Map<String, dynamic>;
          } else {
            throw Exception('Job failed: $error');
          }
        } else if (status == 'pending' || status == 'processing') {
          await Future.delayed(pollInterval);
          continue;
        } else {
          throw Exception('Unknown job status: $status');
        }
      } catch (e) {
        if (e.toString().contains('TIMEOUT_ERROR') || 
            e.toString().contains('CONNECTION_ERROR')) {
          rethrow;
        }
        print('[API] Error polling job status, retrying: $e');
        await Future.delayed(pollInterval);
      }
    }
  }

  /// Unified job status polling helper
  Future<Map<String, dynamic>> pollJobStatus(
    String jobId, {
    Duration pollInterval = const Duration(seconds: 2),
    Duration timeout = const Duration(seconds: 60),
    Function(String)? onStatusUpdate,
  }) async {
    final startTime = DateTime.now();
    
    while (true) {
      if (DateTime.now().difference(startTime) > timeout) {
        throw Exception('TIMEOUT_ERROR: Job polling timed out after ${timeout.inSeconds} seconds');
      }
      
      try {
        final statusData = await getJobStatus(jobId);
        final status = statusData['status'] as String?;
        
        print('[API] 🔄 Job $jobId status: $status');
        print('[API] 📦 Status data keys: ${statusData.keys}');
        print('[API] 📦 Has data: ${statusData['data'] != null}');
        
        if (onStatusUpdate != null) {
          onStatusUpdate(status ?? 'pending');
        }
        
        if (status == 'done' || status == 'error' || status == 'completed' || status == 'failed') {
          final data = statusData['data'];
          print('[API] ✅ Job $jobId final status: $status');
          print('[API] 📦 Final data type: ${data?.runtimeType ?? 'null'}');
          
          if (data != null) {
            print('[API] ✅ Job $jobId completed, returning data');
            return statusData;
          } else if (status == 'error' || status == 'failed') {
            final error = statusData['error'] ?? 'Unknown error';
            print('[API] ❌ Job $jobId failed with error: $error');
            throw Exception('Job failed: $error');
          } else {
            print('[API] ⚠️ Job $jobId completed but no data, returning empty');
            return {
              'success': true,
              'status': 'completed',
              'data': {}
            };
          }
        } else if (status == 'pending' || status == 'processing') {
          print('[API] ⏳ Job $jobId still $status, waiting ${pollInterval.inSeconds}s...');
          await Future.delayed(pollInterval);
          continue;
        } else {
          print('[API] ⚠️ Unknown job status: $status');
          throw Exception('Unknown job status: $status');
        }
      } catch (e) {
        if (e.toString().contains('TIMEOUT_ERROR') || e.toString().contains('404')) {
          rethrow;
        }
        print('[API] Error polling job status, retrying: $e');
        await Future.delayed(pollInterval);
      }
    }
  }

  /// Create hashtags generation job
  Future<Map<String, dynamic>> createHashtagsJob({
    required String topic,
    String? caption,
    int count = 20,
  }) async {
    validatePromptLength(topic, fieldName: 'Topic');
    try {
      print('[API] 🚀 Creating hashtags job - Topic: "$topic"');
      
      final requestBody = {
        'topic': topic,
        if (caption != null && caption.isNotEmpty) 'caption': caption,
        'count': count,
      };
      
      print('[API] 📦 Request body: $requestBody');
      
      final data = await _post('/ai/hashtags', requestBody);
      
      final jobId = data['jobId'] as String;
      print('[API] ✅ Hashtags job created: $jobId');
      return {'jobId': jobId};
    } catch (e) {
      print('[API] ❌ Error creating hashtags job: $e');
      rethrow;
    }
  }

  /// Create carousel generation job
  Future<Map<String, dynamic>> createCarouselJob({
    required String topic,
    int slides = 5,
  }) async {
    validatePromptLength(topic, fieldName: 'Topic');
    try {
      final topicPreview = topic.length > 50 ? '${topic.substring(0, 50)}...' : topic;
      print('[API] 🚀 Creating carousel job - Topic: "$topicPreview", Slides: $slides');
      
      final requestBody = {
        'topic': topic,
        'slides': slides,
      };
      
      print('[API] 📦 Request body: $requestBody');
      
      final data = await _post('/ai/carousel', requestBody);
      
      final jobId = data['jobId'] as String;
      print('[API] ✅ Carousel job created: $jobId');
      return {'jobId': jobId};
    } catch (e) {
      print('[API] ❌ Error creating carousel job: $e');
      rethrow;
    }
  }

  /// Create trends generation job
  Future<Map<String, dynamic>> createTrendsJob({
    String? niche,
    String category = 'All',
  }) async {
    try {
      print('[API] 🚀 Creating trends job - Niche: "$niche", Category: $category');
      
      final requestBody = {
        if (niche != null && niche.isNotEmpty) 'niche': niche,
        'category': category,
      };
      
      print('[API] 📦 Request body: $requestBody');
      
      final data = await _post('/ai/trends', requestBody);
      
      final jobId = data['jobId'] as String;
      print('[API] ✅ Trends job created: $jobId');
      return {'jobId': jobId};
    } catch (e) {
      print('[API] ❌ Error creating trends job: $e');
      rethrow;
    }
  }

  /// Create comment reply generation job
  Future<Map<String, dynamic>> createCommentReplyJob({
    required String comment,
    String tone = 'friendly',
  }) async {
    validatePromptLength(comment, fieldName: 'Comment');
    try {
      final commentPreview = comment.length > 50 ? '${comment.substring(0, 50)}...' : comment;
      print('[API] 🚀 Creating comment reply job - Comment: "$commentPreview", Tone: $tone');
      
      final requestBody = {
        'comment': comment,
        'tone': tone,
      };
      
      print('[API] 📦 Request body: $requestBody');
      
      final data = await _post('/ai/comment-reply', requestBody);
      
      final jobId = data['jobId'] as String;
      print('[API] ✅ Comment reply job created: $jobId');
      return {'jobId': jobId};
    } catch (e) {
      print('[API] ❌ Error creating comment reply job: $e');
      rethrow;
    }
  }

  /// Create hooks generation job
  Future<Map<String, dynamic>> createHooksJob({
    required String topic,
    int count = 5,
  }) async {
    validatePromptLength(topic, fieldName: 'Topic');
    try {
      final topicPreview = topic.length > 50 ? '${topic.substring(0, 50)}...' : topic;
      print('[API] 🚀 Creating hooks job - Topic: "$topicPreview", Count: $count');
      
      // Enhanced prompt instructions to ensure unique hooks with different psychological angles
      final promptInstructions = '''
Generate EXACTLY $count UNIQUE viral hooks for the topic: "$topic".

CRITICAL REQUIREMENTS:
1. You MUST generate EXACTLY $count hooks - no more, no less.

2. Each hook MUST use a DIFFERENT psychological angle:
   - Hook 1: Curiosity (questions, mysteries, "what if")
   - Hook 2: Shock (surprising facts, bold statements)
   - Hook 3: Authority (expert advice, proven methods)
   - Hook 4: Relatability (personal stories, "you're not alone")
   - Hook 5+: Challenge/Bold claim, FOMO, Social proof, etc. (vary the angles)

3. DO NOT repeat:
   - Sentence structure
   - Wording patterns
   - Themes or ideas
   - Opening phrases

4. DO NOT add labels like "(variation 1)", "(variation 2)", etc.

5. Each hook must be DISTINCT and UNIQUE - no similar hooks.

6. Return format: ONE hook per line, no numbering, no labels, no bullet points.
   Example format:
   What if I told you...
   Most people don't know this...
   Here's the secret...
   You're not alone if...
   This will change everything...

7. IMPORTANT: Return EXACTLY $count hooks, one per line.
''';
      
      final requestBody = {
        'topic': topic,
        'count': count,
        'promptInstructions': promptInstructions, // Send explicit instructions to backend
      };
      
      print('[API] 📦 Request body: $requestBody');
      
      final data = await _post('/ai/hooks', requestBody);
      
      final jobId = data['jobId'] as String;
      print('[API] ✅ Hooks job created: $jobId');
      return {'jobId': jobId};
    } catch (e) {
      print('[API] ❌ Error creating hooks job: $e');
      rethrow;
    }
  }

  /// Create bio generation job
  Future<Map<String, dynamic>> createBioJob({
    required String description,
    String style = 'short',
  }) async {
    validatePromptLength(description, fieldName: 'Description');
    try {
      final descPreview = description.length > 50 ? '${description.substring(0, 50)}...' : description;
      print('[API] 🚀 Creating bio job - Description: "$descPreview", Style: $style');
      
      final requestBody = {
        'description': description,
        'style': style,
      };
      
      print('[API] 📦 Request body: $requestBody');
      
      final data = await _post('/ai/bio', requestBody);
      
      final jobId = data['jobId'] as String;
      print('[API] ✅ Bio job created: $jobId');
      return {'jobId': jobId};
    } catch (e) {
      print('[API] ❌ Error creating bio job: $e');
      rethrow;
    }
  }

  /// Create post ideas generation job
  Future<Map<String, dynamic>> createPostIdeasJob({
    required String topic,
    String? niche,
    int count = 5,
  }) async {
    validatePromptLength(topic, fieldName: 'Topic');
    try {
      print('[API] 🚀 Creating post ideas job - Topic: "$topic", Niche: "$niche"');
      
      final requestBody = {
        'topic': topic,
        if (niche != null && niche.isNotEmpty) 'niche': niche,
        'count': count,
      };
      
      print('[API] 📦 Request body: $requestBody');
      
      final data = await _post('/ai/post-ideas', requestBody);
      
      final jobId = data['jobId'] as String;
      print('[API] ✅ Post ideas job created: $jobId');
      return {'jobId': jobId};
    } catch (e) {
      print('[API] ❌ Error creating post ideas job: $e');
      rethrow;
    }
  }

  /// Create captions generation job with free-text input
  Future<String> createCaptionsJob({
    required String userInput,
    bool regenerate = false,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = (timestamp % 1000000) + (DateTime.now().microsecondsSinceEpoch % 1000000);
      final requestId = '$timestamp-$random-${userInput.hashCode}';
      
      print('[API] 🚀 Creating captions job - Request ID: $requestId');
      print('[API] User Input: "$userInput", regenerate=$regenerate');
      
      final requestBody = {
        'userInput': userInput,
        'regenerate': regenerate,
        'requestId': requestId,
      };
      
      print('[API] 📦 Request body: $requestBody');
      
      final data = await _post('/ai/captions', requestBody);
      
      final jobId = data['jobId'] as String;
      print('[API] ✅ Captions job created: $jobId (Request ID: $requestId)');
      return jobId;
    } catch (e) {
      print('[API] ❌ Error creating captions job: $e');
      rethrow;
    }
  }

  /// Generate captions from free-text user input
  Future<List<dynamic>> generateCaptions(String userInput, {bool regenerate = false, Function(String)? onRetry}) async {
    final callId = DateTime.now().millisecondsSinceEpoch;
    print('[API] 🎯 generateCaptions CALLED #$callId');
    print('[API] User Input: "$userInput", regenerate=$regenerate');
    
    try {
      final jobId = await createCaptionsJob(
        userInput: userInput,
        regenerate: regenerate,
      );
      
      print('[API] ✅ Job created #$callId with ID: $jobId');
      
      final result = await pollJobStatus(
        jobId,
        onStatusUpdate: onRetry,
      );
      
      print('[API] ✅ Polling completed #$callId. Success: ${result['success']}, Status: ${result['status']}');
      
      // Extract data from response
      var data = result['data'];
      
      // DEBUG: Log the data structure
      print('[API] Raw data type: ${data.runtimeType}');
      if (data != null) {
        print('[API] Raw data value: ${data.toString().substring(0, min(data.toString().length, 500))}');
      }
      
      // Handle different response formats
      List<dynamic> captions = [];
      
      // ✅ FORMAT 1: Direct array of caption objects
      if (data is List) {
        print('[API] Data is List with ${data.length} items');
        
        // Filter out JSON structure markers first
        final filteredData = data.where((item) {
          if (item is String) {
            final str = item.toString().trim();
            // Skip JSON structure markers
            if (str == '"captions":' || 
                str.startsWith('"captions":') ||
                str == '"hashtags":' ||
                str.startsWith('"hashtags":') ||
                (str.startsWith('{') && str.length < 100 && (str.contains('"captions":') || str.contains('"hashtags":'))) ||
                (str.startsWith('[') && str.length < 50)) {
              print('[API] 🚫 Filtered out JSON marker: ${str.substring(0, min(50, str.length))}');
              return false;
            }
          } else if (item is Map) {
            final text = item['text']?.toString() ?? item['caption']?.toString() ?? '';
            if (text.trim() == '"captions":' || 
                text.trim().startsWith('"captions":') ||
                text.trim() == '"hashtags":' ||
                text.trim().startsWith('"hashtags":')) {
              print('[API] 🚫 Filtered out Map with JSON marker in text');
              return false;
            }
          }
          return true;
        }).toList();
        
        print('[API] Filtered list: ${filteredData.length} items (from ${data.length})');
        
        for (var item in filteredData) {
          // Handle Map objects
          if (item is Map) {
            // Extract text from various possible keys
            String? text;
            if (item['text'] != null) {
              text = item['text'].toString();
            } else if (item['caption'] != null) {
              text = item['caption'].toString();
            } else if (item['content'] != null) {
              text = item['content'].toString();
            }
            
            // Skip if text contains JSON structure markers (like "captions": or "hashtags":)
            if (text != null) {
              final textTrimmed = text.trim();
              // Skip JSON structure markers
              if (textTrimmed.contains('"captions":') || 
                  textTrimmed.contains('"hashtags":') || 
                  textTrimmed.startsWith('{') ||
                  textTrimmed.startsWith('[') ||
                  textTrimmed == '"captions":' ||
                  textTrimmed.startsWith('"hashtags":')) {
                print('[API] ⚠️ Skipping item with JSON structure in text: ${text.substring(0, min(50, text.length))}');
                continue;
              }
            }
            
            if (text != null && text.isNotEmpty) {
              // Extract hashtags
              List<String> hashtags = [];
              if (item['hashtags'] is List) {
                hashtags = List<String>.from(item['hashtags']);
              } else if (item['tags'] is List) {
                hashtags = List<String>.from(item['tags']);
              }
              
              // Extract style
              String style = item['style']?.toString() ?? 
                            item['angle']?.toString() ?? 
                            item['type']?.toString() ?? 
                            'general';
              
              captions.add({
                'style': style,
                'text': text,
                'hashtags': hashtags,
              });
              
              print('[API] ✅ Added caption: ${text.substring(0, min(30, text.length))}...');
            }
          } 
          // Handle String items - check if it's JSON or plain text
          else if (item is String) {
            final itemStr = item.toString().trim();
            
            // Skip if it's a JSON structure marker (exact matches or starts with markers)
            if (itemStr == '"captions":' || 
                itemStr.startsWith('"captions":') ||
                itemStr == '"hashtags":' ||
                itemStr.startsWith('"hashtags":') ||
                (itemStr.startsWith('{') && (itemStr.contains('"captions":') || itemStr.contains('"hashtags":'))) ||
                (itemStr.startsWith('[') && itemStr.length < 50)) {
              print('[API] ⚠️ Skipping JSON structure marker: ${itemStr.substring(0, min(50, itemStr.length))}');
              continue;
            }
            
            // Try to parse as JSON if it looks like JSON
            if (itemStr.startsWith('{') || itemStr.startsWith('[')) {
              // Try to parse as JSON first
              try {
                final parsed = jsonDecode(itemStr);
                if (parsed is Map) {
                  // Extract from parsed JSON
                  final text = parsed['text']?.toString() ?? 
                              parsed['caption']?.toString() ?? 
                              '';
                  if (text.isNotEmpty) {
                    final hashtags = parsed['hashtags'] is List 
                        ? List<String>.from(parsed['hashtags'])
                        : [];
                    final style = parsed['style']?.toString() ?? 'general';
                    
                    captions.add({
                      'style': style,
                      'text': text,
                      'hashtags': hashtags,
                    });
                    print('[API] ✅ Parsed JSON string, added caption: ${text.substring(0, min(30, text.length))}...');
                    continue;
                  }
                } else if (parsed is List) {
                  // If it's a list, process each item
                  for (var subItem in parsed) {
                    if (subItem is Map) {
                      final text = subItem['text']?.toString() ?? 
                                  subItem['caption']?.toString() ?? 
                                  '';
                      if (text.isNotEmpty) {
                        final hashtags = subItem['hashtags'] is List 
                            ? List<String>.from(subItem['hashtags'])
                            : [];
                        final style = subItem['style']?.toString() ?? 'general';
                        
                        captions.add({
                          'style': style,
                          'text': text,
                          'hashtags': hashtags,
                        });
                      }
                    }
                  }
                  continue;
                }
              } catch (e) {
                print('[API] ⚠️ Failed to parse JSON string: $e');
                // Skip this item if it looks like JSON but can't be parsed
                continue;
              }
            }
            
            // Plain text caption - extract hashtags from text
            final hashtagRegex = RegExp(r'#(\w+)');
            final matches = hashtagRegex.allMatches(itemStr);
            final hashtags = matches.map((m) => m.group(0)!).toList();
            
            // Remove hashtags from text
            var cleanText = itemStr;
            for (final tag in hashtags) {
              cleanText = cleanText.replaceAll(tag, '').trim();
            }
            cleanText = cleanText.replaceAll(RegExp(r'\s+'), ' ').trim();
            
            // Remove bullet points and numbering
            cleanText = cleanText
                .replaceAll(RegExp(r'^[•\-*]\s*'), '')
                .replaceAll(RegExp(r'^\d+[\.\)]\s*'), '')
                .trim();
            
            if (cleanText.isNotEmpty && cleanText.length > 5) {
              captions.add({
                'style': 'general',
                'text': cleanText,
                'hashtags': hashtags,
              });
              print('[API] ✅ Added plain text caption: ${cleanText.substring(0, min(30, cleanText.length))}...');
            }
          }
        }
      } 
      // ✅ FORMAT 2: Map with 'captions' key
      else if (data is Map) {
        print('[API] Data is Map with keys: ${data.keys}');
        
        if (data['captions'] is List) {
          final captionsList = data['captions'] as List;
          print('[API] Found captions list with ${captionsList.length} items');
          
          for (var item in captionsList) {
            if (item is Map && item['text'] != null) {
              captions.add({
                'style': item['style']?.toString() ?? 'general',
                'text': item['text'].toString(),
                'hashtags': item['hashtags'] is List ? List<String>.from(item['hashtags']) : [],
              });
            }
          }
        }
      }
      
      // ✅ FORMAT 3: String that might be JSON
      else if (data is String) {
        print('[API] Data is String, length: ${data.length}');
        
        try {
          // Try to parse as JSON
          final parsed = jsonDecode(data);
          if (parsed is List) {
            print('[API] Parsed string as JSON List with ${parsed.length} items');
            // Recursively process
            final processed = await _parseCaptionsData(parsed);
            captions.addAll(processed);
          } else if (parsed is Map) {
            print('[API] Parsed string as JSON Map');
            final processed = await _parseCaptionsData([parsed]);
            captions.addAll(processed);
          }
        } catch (e) {
          print('[API] String is not JSON, treating as plain text');
          // Treat as single caption
          captions.add({
            'style': 'general',
            'text': data,
            'hashtags': [],
          });
        }
      }
      
      // FALLBACK: If no captions found
      if (captions.isEmpty) {
        print('[API] ⚠️ No captions extracted, using fallback');
        captions = _getFallbackCaptions(userInput);
      }
      
      print('[API] ✅ Returning ${captions.length} captions');
      return captions;
    } catch (e) {
      print('[API] ❌ Error in generateCaptions: $e');
      
      // Always return fallback captions instead of throwing error
      return _getFallbackCaptions(userInput);
    }
  }

  /// Helper to parse captions data recursively
  Future<List<dynamic>> _parseCaptionsData(dynamic data) async {
    final List<dynamic> result = [];
    
    if (data is List) {
      for (var item in data) {
        if (item is Map) {
          String? text;
          if (item['text'] != null) {
            text = item['text'].toString();
          } else if (item['caption'] != null) {
            text = item['caption'].toString();
          }
          
          if (text != null && text.isNotEmpty) {
            result.add({
              'style': item['style']?.toString() ?? 'general',
              'text': text,
              'hashtags': item['hashtags'] is List ? List<String>.from(item['hashtags']) : [],
            });
          }
        } else if (item is String) {
          result.add({
            'style': 'general',
            'text': item,
            'hashtags': [],
          });
        }
      }
    } else if (data is Map) {
      String? text;
      if (data['text'] != null) {
        text = data['text'].toString();
      } else if (data['caption'] != null) {
        text = data['caption'].toString();
      }
      
      if (text != null && text.isNotEmpty) {
        result.add({
          'style': data['style']?.toString() ?? 'general',
          'text': text,
          'hashtags': data['hashtags'] is List ? List<String>.from(data['hashtags']) : [],
        });
      }
    }
    
    return result;
  }

  /// Get fallback captions
  List<dynamic> _getFallbackCaptions(String userInput) {
    // Extract keywords from user input for hashtags
    final words = userInput.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 3).take(3).toList();
    final hashtags = words.map((w) => '#$w').toList();
    if (hashtags.isEmpty) {
      hashtags.addAll(['#content', '#instagram', '#reels']);
    }
    
    return [
      {
        'style': 'general',
        'text': 'Ready to create amazing content! Let\'s go! 🚀',
        'hashtags': hashtags,
      },
      {
        'style': 'general',
        'text': 'Time to shine! ✨',
        'hashtags': hashtags,
      },
    ];
  }

  // Other existing methods remain the same...

  Future<String?> getAuthUrl() async {
    // Ensure user is logged in before making request
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('[API] ❌ getAuthUrl: User not logged in');
      throw Exception('Please login first to connect Google Calendar');
    }
    print('[API] ✅ getAuthUrl: User ID: ${user.uid}');
    final data = await _get('/auth/url');
    return data['data']?['url'] as String?;
  }

  Future<bool> getAuthStatus() async {
    // Ensure user is logged in before making request
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('[API] ❌ getAuthStatus: User not logged in');
      return false;
    }
    print('[API] ✅ getAuthStatus: User ID: ${user.uid}');
    final data = await _get('/auth/status');
    return data['data']?['connected'] == true;
  }

  Future<String> createCalendarJob({
    required String topic,
    int days = 7,
  }) async {
    try {
      final data = await _post('/ai/calendar', {
        'topic': topic,
        'days': days,
      });
      final jobId = data['jobId'] as String;
      return jobId;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> generateCalendar(String topic, {int days = 7, Function(String)? onRetry}) async {
    try {
      final jobId = await createCalendarJob(topic: topic, days: days);
      final result = await pollJobStatus(jobId, onStatusUpdate: onRetry);
      return (result['data'] ?? []) as List<dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<String> createStrategyJob({
    required String niche,
  }) async {
    try {
      final data = await _post('/ai/strategy', {
        'niche': niche,
      });
      return data['jobId'] as String;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> generateStrategy(String niche, {Function(String)? onRetry}) async {
    try {
      final jobId = await createStrategyJob(niche: niche);
      final result = await pollJobStatus(jobId, onStatusUpdate: onRetry);
      return (result['data'] ?? {}) as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> scheduleEvent({
    required String title,
    required String description,
    required String startDateTime,
    required String endDateTime,
  }) async {
    final data = await _post('/calendar/create', {
      'title': title,
      'description': description,
      'startDateTime': startDateTime,
      'endDateTime': endDateTime,
    });
    return data['success'] == true;
  }

  Future<String> createNicheAnalysisJob({
    required String topic,
  }) async {
    try {
      final data = await _post('/ai/analyze', {
        'topic': topic,
      });
      return data['jobId'] as String;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> analyzeNiche(String topic, {Function(String)? onRetry}) async {
    try {
      final jobId = await createNicheAnalysisJob(topic: topic);
      final result = await pollJobStatus(jobId, onStatusUpdate: onRetry);
      return (result['data'] ?? {}) as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> generateImageCaptions(String imageBase64, String imageMimeType) async {
    final data = await _post('/ai/image-captions', {
      'imageBase64': imageBase64,
      'imageMimeType': imageMimeType,
    });
    return (data['data'] ?? {}) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> generateCaptionFromMedia(String imageBase64, String imageMimeType) async {
    try {
      final data = await _post('/ai/caption-from-media', {
        'imageBase64': imageBase64,
        'imageMimeType': imageMimeType,
      });
      return (data['data'] ?? {}) as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<String> createReelsScriptJob({
    required String topic,
    required String duration,
    required String tone,
    required String audience,
    required String language,
    bool regenerate = false,
  }) async {
    validatePromptLength(topic, fieldName: 'Topic');
    try {
      final data = await _post('/ai/reels-script', {
        'topic': topic,
        'duration': duration,
        'tone': tone,
        'audience': audience,
        'language': language,
        'regenerate': regenerate,
      });
      return data['jobId'] as String;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> generateReelsScript({
    String? userInput,
    String? topic,
    String? duration,
    String? tone,
    String? audience,
    String? language,
    bool regenerate = false,
    Function(String)? onRetry,
  }) async {
    try {
      // New ChatGPT-style: Send userInput if provided
      // Old format: Send separate parameters for backward compatibility
      final requestBody = <String, dynamic>{
        'regenerate': regenerate,
      };
      
      if (userInput != null && userInput.trim().isNotEmpty) {
        // New ChatGPT-style approach
        requestBody['userInput'] = userInput.trim();
        print('[API] 🚀 Using ChatGPT-style input: "$userInput"');
      } else if (topic != null && topic.trim().isNotEmpty) {
        // Old format for backward compatibility
        requestBody['topic'] = topic.trim();
        requestBody['duration'] = duration ?? '15s';
        requestBody['tone'] = tone ?? 'motivational';
        requestBody['audience'] = audience ?? 'general';
        requestBody['language'] = language ?? 'English';
        print('[API] 📋 Using old format with separate parameters');
      } else {
        throw Exception('Please provide either userInput or topic');
      }
      
      final response = await _post('/ai/reels-script', requestBody, onRetry: onRetry);
      
      final data = response['data'] ?? {};
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      
      return <String, dynamic>{};
    } catch (e) {
      rethrow;
    }
  }
}
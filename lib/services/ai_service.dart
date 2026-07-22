import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_secrets.dart';
import '../config/ai_performance_config.dart';
import '../utils/ai_prompt_trim.dart';
import '../utils/ai_prompt_validation.dart';
import '../models/daily_viral_drop_model.dart';
import '../models/daily_drop_model.dart';
import 'ai_cache_service.dart';
import 'analytics_service.dart';
import 'api_service.dart';

/// Centralized AI Service for InstaFlow
/// 
/// Handles all AI-related API calls with proper error handling and fallbacks.
/// Uses AppSecrets for API configuration.
class AIService {
  // Get current user UID for history tracking
  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;
  Map<String, dynamic>? lastHashtagAdvice;

  /// Check if AI service is properly configured
  bool get isConfigured => AppSecrets.isAiConfigured;

  /// Call AI API endpoint. 25s timeout, 1 retry on timeout with 1.5s backoff, cache, slow-call log.
  Future<Map<String, dynamic>> _callApi({
    required String endpoint,
    required Map<String, dynamic> body,
    bool useFirebaseFunctions = true,
  }) async {
    if (!AppSecrets.isAiConfigured && useFirebaseFunctions) {
      throw Exception(
        'AI service is not configured. Please set AI_API_KEY or FUNCTIONS_BASE_URL.',
      );
    }

    final trimmed = _trimBodyPrompts(body);
    final cache = AiCacheService();
    final cached = await cache.get(endpoint, trimmed);
    if (cached != null) return cached;

    const timeout = Duration(seconds: 25);
    const retryDelay = Duration(milliseconds: 1500);
    int attempts = 0;

    while (true) {
      attempts++;
      final stopwatch = Stopwatch()..start();
      try {
        final baseUrl = useFirebaseFunctions
            ? AppSecrets.functionsBaseUrl
            : AppSecrets.aiApiBaseUrl;
        final url = Uri.parse('$baseUrl/$endpoint');
        final headers = AppSecrets.getApiHeaders();

        final response = await http
            .post(
              url,
              headers: headers,
              body: jsonEncode(trimmed),
            )
            .timeout(timeout);

        stopwatch.stop();
        if (stopwatch.elapsedMilliseconds > AiPerformanceConfig.slowCallThresholdSeconds * 1000) {
          AnalyticsService.logAiSlowCall(
            endpoint: endpoint,
            durationMs: stopwatch.elapsedMilliseconds,
          );
        }

        if (response.statusCode == 200) {
          final result = jsonDecode(response.body) as Map<String, dynamic>;
          unawaited(cache.put(endpoint, trimmed, result));
          return result;
        }
        final errorMsg = _parseError(response);
        throw Exception(errorMsg);
      } on TimeoutException catch (e) {
        if (attempts < 2) {
          await Future.delayed(retryDelay);
          continue;
        }
        if (endpoint == 'generateCaption') rethrow;
        if (useFirebaseFunctions && e.toString().contains('timeout')) {
          return _getMockResponse(endpoint, body);
        }
        rethrow;
      } catch (e) {
        if (endpoint == 'generateCaption') rethrow;
        if (useFirebaseFunctions && e.toString().contains('Failed to fetch')) {
          return _getMockResponse(endpoint, body);
        }
        rethrow;
      }
    }
  }

  Map<String, dynamic> _trimBodyPrompts(Map<String, dynamic> body) {
    final out = <String, dynamic>{};
    for (final e in body.entries) {
      if (e.value is String && _promptKeys.contains(e.key)) {
        out[e.key] = trimPromptForAi(e.value as String);
      } else {
        out[e.key] = e.value;
      }
    }
    return out;
  }

  static const _promptKeys = {'topic', 'text', 'niche', 'description', 'comment'};

  /// Parse error from API response
  String _parseError(http.Response response) {
    try {
      final error = jsonDecode(response.body) as Map<String, dynamic>;
      return error['error']?.toString() ?? 
          'API request failed with status ${response.statusCode}';
    } catch (_) {
      return 'API request failed with status ${response.statusCode}';
    }
  }

  /// Fallback mock responses for development when API is unavailable
  Map<String, dynamic> _getMockResponse(String functionName, Map<String, dynamic> body) {
    final topic = body['topic']?.toString() ?? 
        body['description']?.toString() ?? 
        body['comment']?.toString() ?? 
        body['text']?.toString() ?? 
        body['niche']?.toString() ?? 
        'content';
    
    switch (functionName) {
      case 'generateCaption':
        final style = body['style'] ?? 'trending';
        return {
          'ok': true,
          'caption': _getMockCaption(topic, style),
        };
      
      case 'generateHashtags':
        return {
          'ok': true,
          'hashtags': _getMockHashtags(topic),
        };
      
      case 'generateBio':
        return {
          'ok': true,
          'bio': _getMockBio(topic),
        };
      
      case 'generateReelScript':
        return {
          'ok': true,
          'script': _getMockReelScript(topic),
        };
      
      case 'generatePostIdeas':
        return {
          'ok': true,
          'ideas': _getMockIdeas(topic),
        };
      
      case 'rewriteText':
        final tone = body['tone'] ?? 'engaging';
        return {
          'ok': true,
          'rewritten': _getMockRewrite(topic, tone),
        };
      
      case 'generateCommentReply':
        return {
          'ok': true,
          'reply': _getMockCommentReply(),
        };
      
      case 'generateDailyViralDrop':
        return _getMockDailyViralDrop(body['trend']?.toString() ?? topic, body['niche']?.toString() ?? topic);
      
      case 'generateDailyDrop':
        return _getMockDailyDrop(body['niche']?.toString() ?? topic, body['trend']?.toString() ?? topic);
      
      default:
        return {
          'ok': true,
          'result': 'Mock response for $functionName',
        };
    }
  }

  // ========== MOCK DATA GENERATORS ==========

  // Random emoji sets for variety
  final List<List<String>> _emojiSets = [
    ['🔥', '✨', '💫', '🌟'],
    ['💜', '💙', '💚', '🧡'],
    ['😍', '🥰', '😊', '😎'],
    ['🎯', '🎨', '🎭', '🎪'],
    ['⚡', '💥', '🚀', '⭐'],
    ['🌸', '🌺', '🌻', '🌷'],
    ['💪', '🔥', '✨', '🎉'],
    ['🌈', '☀️', '🌙', '⭐'],
  ];

  // Get random emoji set
  List<String> _getRandomEmojis() {
    final random = DateTime.now().millisecond % _emojiSets.length;
    return _emojiSets[random];
  }

  // Generate unique caption with variations
  String _getMockCaption(String topic, String style) {
    // Extract key words from topic for hashtags and shorter references
    final topicWords = _extractKeyWords(topic);
    final topicShort = topicWords.isNotEmpty ? topicWords[0] : (topic.length > 25 ? topic.substring(0, 25) : topic);
    final topicClean = topic.length > 50 ? topic.substring(0, 50) : topic;
    
    final random = DateTime.now().millisecond;
    final emojis = _getRandomEmojis();
    final emoji1 = emojis[random % emojis.length];
    final emoji2 = emojis[(random + 1) % emojis.length];
    final emoji3 = emojis[(random + 2) % emojis.length];
    
    // Different templates for each style to ensure variety
    // Pass both short and full topic for better caption generation
    final templates = _getCaptionTemplates(style.toLowerCase(), topicClean, topicShort, emoji1, emoji2, emoji3);
    final selectedTemplate = templates[random % templates.length];
    
    return selectedTemplate;
  }

  // Extract key words from topic for hashtags
  List<String> _extractKeyWords(String topic) {
    // Remove common words and extract meaningful keywords
    final commonWords = ['a', 'an', 'the', 'is', 'are', 'with', 'and', 'or', 'beautiful', 'stunning', 'amazing'];
    final words = topic.toLowerCase().split(RegExp(r'[,\s]+'));
    return words.where((word) => 
      word.length > 3 && !commonWords.contains(word)
    ).take(3).toList();
  }

  // Get multiple caption templates for each style
  // topic: Full description, topicShort: Short keyword for hashtags
  List<String> _getCaptionTemplates(String style, String topic, String topicShort, String e1, String e2, String e3) {
    // Generate hashtags from topic
    final hashtags = _generateHashtagsFromTopic(topic, topicShort);
    switch (style) {
      case 'funny':
        return [
          '$e1 When you see $topicShort and it\'s just perfect $e2\n\nThis is the content we needed! Drop a $e3 if you agree! 😎\n\n$hashtags',
          'POV: You\'re scrolling and see $topicShort $e1\n\nMe: *immediately saves* $e2\n\nWho else relates? $e3\n\n$hashtags',
          '$e1 $topicShort hits different! $e2\n\nNo cap, this is everything! $e3\n\n$hashtags',
          'When $topicShort becomes your whole personality $e1\n\nWe\'ve all been there, right? $e2 $e3\n\n$hashtags',
        ];
      
      case 'emotional':
        return [
          '$e1 Sometimes $topicShort hits different...\n\n$topic\n\nLife has its ups and downs, but we keep moving forward. $e2\n\nWho can relate? ❤️\n\n$hashtags',
          '$e2 $topicShort taught me that growth comes from within $e1\n\n$topic\n\nEvery experience shapes us. This one? It changed everything. $e3\n\n$hashtags',
          'In the quiet moments, $topicShort reminds us what matters most $e1\n\n$topic\n\nGrateful for these moments. $e2 $e3\n\n$hashtags',
          '$e3 $topicShort: where memories meet emotions $e1\n\n$topic\n\nThis is what life is about. $e2\n\n$hashtags',
        ];
      
      case 'short':
        return [
          '$topicShort = Everything $e1\n\n$topic\n\nThat\'s it. That\'s the caption. $e2\n\n$hashtags',
          '$e1 $topicShort $e2\n\n$topic\n\nPeriod. $e3\n\n$hashtags',
          '$topicShort. $e1\n\n$topic\n\nNo explanation needed. $e2\n\n$hashtags',
          '$e2 $topicShort $e3\n\n$topic\n\nThat\'s the vibe. $e1\n\n$hashtags',
        ];
      
      case 'marketing':
        return [
          '$e1 Ready to level up your $topicShort game?\n\n$topic\n\nHere\'s what you need to know:\n\n✅ Transform your approach\n✅ See real results\n✅ Join the movement\n\nDM for more details! 📩\n\n$hashtags',
          '$e2 $topicShort: The game-changer you\'ve been waiting for $e1\n\n$topic\n\nWhy it matters:\n\n💡 Innovation\n💡 Results\n💡 Community\n\nLet\'s connect! $e3\n\n$hashtags',
          '$e3 Unlock the power of $topicShort $e1\n\n$topic\n\nWhat you get:\n\n🚀 Growth\n🚀 Impact\n🚀 Transformation\n\nReady? Let\'s talk! $e2\n\n$hashtags',
        ];
      
      case 'professional':
        return [
          '$e1 Excited to share insights on $topicShort.\n\n$topic\n\nThis represents a significant opportunity for growth and development in our industry.\n\nLooking forward to your thoughts and feedback. $e2\n\n$hashtags',
          '$e2 $topicShort: A strategic approach to excellence $e1\n\n$topic\n\nKey highlights:\n\n📊 Data-driven insights\n📊 Industry best practices\n📊 Future-forward thinking\n\nLet\'s discuss! $e3\n\n$hashtags',
          '$e3 Presenting: $topicShort $e1\n\n$topic\n\nOur analysis shows promising trends and opportunities.\n\nWould love to hear your perspective. $e2\n\n$hashtags',
        ];
      
      case 'casual':
        return [
          'Hey! $e1 Just wanted to share this $topicShort moment with you all.\n\n$topic\n\nNothing fancy, just keeping it real! $e2\n\nWhat\'s your take on this? $e3\n\n$hashtags',
          '$e2 So, about $topicShort... $e1\n\n$topic\n\nJust vibing and sharing the moment! $e3\n\nThoughts? $e1\n\n$hashtags',
          '$e3 $topicShort update! $e1\n\n$topic\n\nKeeping it chill and authentic. $e2\n\nWhat do you think? $e3\n\n$hashtags',
        ];
      
      case 'inspiring':
        return [
          '$e1 $topicShort reminds us that every day is a new opportunity.\n\n$topic\n\nBelieve in yourself, stay positive, and keep pushing forward! $e2\n\nYou\'ve got this! $e3\n\n$hashtags',
          '$e2 $topicShort: Proof that dreams become reality $e1\n\n$topic\n\nWhen you believe, you achieve. $e3\n\nKeep going! $e1\n\n$hashtags',
          '$e3 $topicShort taught me: growth happens outside comfort zones $e1\n\n$topic\n\nEmbrace the journey. $e2\n\nYou\'re capable of amazing things! $e3\n\n$hashtags',
        ];
      
      case 'friendly':
        return [
          'Hey everyone! $e1\n\nJust wanted to share this $topicShort with you all.\n\n$topic\n\nHope you\'re having an amazing day! $e2\n\nWould love to hear your thoughts! $e3\n\n$hashtags',
          '$e2 Quick update on $topicShort! $e1\n\n$topic\n\nHope this brightens your day! $e3\n\nLet\'s connect! $e1\n\n$hashtags',
          '$e3 Sharing some $topicShort vibes! $e1\n\n$topic\n\nHope you\'re all doing well! $e2\n\nDrop a comment! $e3\n\n$hashtags',
        ];
      
      default: // trending
        return [
          '$e1 ${topicShort.toUpperCase()} $e2\n\n$topic\n\nJust another day living my best life! Who else can relate? $e3\n\nDrop a ❤️ if you agree!\n\n$hashtags',
          '$e2 $topicShort energy is unmatched $e1\n\n$topic\n\nLiving in the moment and loving it! $e3\n\nWho\'s with me? $e1\n\n$hashtags',
          '$e3 $topicShort = the vibe $e1\n\n$topic\n\nThis is what we needed today! $e2\n\nAgree? $e3\n\n$hashtags',
          '$e1 $topicShort hitting different today $e2\n\n$topic\n\nCan\'t get enough of this! $e3\n\nShare if you feel the same! $e1\n\n$hashtags',
        ];
    }
  }

  // Generate relevant hashtags from image topic
  String _generateHashtagsFromTopic(String topic, String topicShort) {
    final keywords = _extractKeyWords(topic);
    final hashtagList = <String>[];
    
    // Add topic-based hashtags
    if (topicShort.isNotEmpty) {
      hashtagList.add('#${topicShort.toLowerCase().replaceAll(' ', '')}');
    }
    
    // Add keyword hashtags
    for (final keyword in keywords) {
      if (keyword.length > 3) {
        hashtagList.add('#$keyword');
      }
    }
    
    // Add style-based hashtags
    hashtagList.addAll(['#photooftheday', '#instagood', '#trending', '#viral', '#lifestyle']);
    
    // Add relevant hashtags based on topic content
    final topicLower = topic.toLowerCase();
    if (topicLower.contains('sunset') || topicLower.contains('sunrise')) {
      hashtagList.addAll(['#sunset', '#sunrise', '#nature', '#sky']);
    }
    if (topicLower.contains('beach') || topicLower.contains('ocean')) {
      hashtagList.addAll(['#beach', '#ocean', '#travel', '#vacation']);
    }
    if (topicLower.contains('food') || topicLower.contains('delicious')) {
      hashtagList.addAll(['#food', '#foodie', '#delicious', '#yummy']);
    }
    if (topicLower.contains('fashion') || topicLower.contains('outfit')) {
      hashtagList.addAll(['#fashion', '#style', '#ootd', '#outfit']);
    }
    if (topicLower.contains('travel') || topicLower.contains('destination')) {
      hashtagList.addAll(['#travel', '#wanderlust', '#adventure', '#explore']);
    }
    if (topicLower.contains('nature') || topicLower.contains('forest')) {
      hashtagList.addAll(['#nature', '#naturelover', '#outdoors', '#green']);
    }
    
    return hashtagList.join(' ');
  }

  List<String> _getMockHashtags(String topic) {
    final topicLower = topic.toLowerCase().replaceAll(' ', '');
    return [
      '#$topicLower',
      '#$topic',
      '#${topicLower}s',
      '#instagram',
      '#instagood',
      '#photooftheday',
      '#trending',
      '#love',
      '#beautiful',
      '#happy',
      '#fashion',
      '#style',
      '#photography',
      '#art',
      '#lifestyle',
      '#follow',
      '#like',
      '#instadaily',
      '#picoftheday',
      '#viral',
    ];
  }

  String _getMockBio(String topic) {
    return '✨ Creator | $topic | Living my best life 🌟\n\nPassionate about sharing authentic content and connecting with amazing people. Follow along for daily inspiration! 💫';
  }

  String _getMockReelScript(String topic) {
    return '''HOOK (0-3s):
"Stop scrolling! This $topic hack changed everything for me..."

BODY (3-12s):
"Here's what I learned about $topic:
1. First key point
2. Second important tip
3. Third game-changer
Watch how it works..."

CTA (12-15s):
"Save this reel and try it! Let me know how it goes in the comments 👇

#${topic.replaceAll(' ', '').toLowerCase()} #reels #tips #viral''';
  }

  Map<String, dynamic> _getMockDailyViralDrop(String trend, String niche) {
    final theme = 'Trending: $trend for $niche creators';
    final concept = 'A quick, scroll-stopping reel that combines "$trend" with your $niche angle in under 30 seconds.';
    final steps = [
      'Hook (0–3s): Show the result or ask a bold question about $trend',
      'Problem (3–8s): One line on why people get $trend wrong',
      'Tip 1 (8–15s): First actionable step for $niche',
      'Tip 2 (15–22s): Second step with a quick demo',
      'CTA (22–30s): Tell them to save, follow, or comment their biggest $trend question',
    ];
    final hooks = [
      'Nobody talks about this $trend trick…',
      'Stop scrolling if you do $niche content.',
      'This $trend tip changed everything for me.',
      'POV: You finally understand $trend.',
      'I wish I knew this $trend hack sooner.',
    ];
    final caption = '$concept\n\nDrop a 🔥 if you’re trying this. #$niche #$trend';
    final cta = 'Save this reel and try it today. Comment your go-to $trend tip below.';
    final hashtags = ['#$trend', '#$niche', '#reels', '#viral', '#contentcreator', '#tips'];
    final bestTime = '7–9 AM or 7–9 PM in your timezone';
    return {
      'ok': true,
      'trendTheme': theme,
      'reelConcept': concept,
      'shotPlan': steps,
      'hooks': hooks,
      'caption': caption,
      'cta': cta,
      'hashtags': hashtags,
      'bestPostTime': bestTime,
    };
  }

  Map<String, dynamic> _getMockDailyDrop(String niche, String trend) {
    final theme = 'Trending: $trend for $niche creators';
    final concept = 'A quick, scroll-stopping reel that combines "$trend" with your $niche angle in under 30 seconds.';
    final steps = [
      'Hook (0–3s): Show the result or ask a bold question about $trend',
      'Problem (3–8s): One line on why people get $trend wrong',
      'Tip 1 (8–15s): First actionable step for $niche',
      'Tip 2 (15–22s): Second step with a quick demo',
      'CTA (22–30s): Tell them to save, follow, or comment their biggest $trend question',
    ];
    final hooks = [
      'Nobody talks about this $trend trick…',
      'Stop scrolling if you do $niche content.',
      'This $trend tip changed everything for me.',
      'POV: You finally understand $trend.',
      'I wish I knew this $trend hack sooner.',
    ];
    final caption = '$concept\n\nDrop a 🔥 if you\'re trying this.';
    final hashtags = ['#$trend', '#$niche', '#reels', '#viral', '#contentcreator', '#tips', '#reels', '#fyp', '#viral', '#trending'];
    final bestTime = '7–9 AM or 7–9 PM in your timezone';
    final coachSummary = 'Today\'s trend: $theme. Concept: $concept. Best time to post: $bestTime.';
    return {
      'ok': true,
      'trend_theme': theme,
      'reel_concept': concept,
      'steps': steps,
      'hooks': hooks,
      'caption': caption,
      'hashtags': hashtags,
      'best_post_time': bestTime,
      'coach_summary': coachSummary,
      'virality_score': 78,
    };
  }

  List<String> _getMockIdeas(String topic) {
    return [
      'Behind-the-scenes: Show your creative process with $topic',
      'Day in the life: A typical day in your $topic journey',
      'Quick tips: Share 3-5 actionable $topic tips',
      'Before & after: Transformation or comparison',
      'Q&A: Answer common questions about $topic',
      'Tutorial: Step-by-step guide for $topic beginners',
      'Trending challenge: Join a popular $topic challenge',
      'Collaboration: Partner with another $topic creator',
      'User-generated content: Feature your $topic audience',
      'Inspirational story: Share your $topic journey',
    ];
  }

  String _getMockRewrite(String text, String tone) {
    switch (tone) {
      case 'simple':
        return 'Simple version: $text';
      case 'attractive':
        return '✨ Attractive version: $text ✨';
      case 'seo':
        return 'SEO optimized: $text | Keywords included';
      case 'professional':
        return 'Professional: $text. We strive for excellence in all our endeavors.';
      default: // engaging
        return 'Engaging version: $text 💫\n\nWhat are your thoughts? Let me know in the comments! 👇';
    }
  }

  String _getMockCommentReply() {
    return 'Thank you so much! 🙏✨ Really appreciate your kind words. Stay tuned for more! 💫';
  }

  // ========== PUBLIC API METHODS ==========

  /// Analyze image and extract detailed description
  /// 
  /// [imagePath] - Path to the image file
  /// Returns detailed description of image content for caption generation
  Future<String> analyzeImage(String imagePath) async {
    try {
      // Try to call vision API endpoint if available
      try {
        final result = await _callApi(
          endpoint: 'analyzeImage',
          body: {
            'imagePath': imagePath,
            if (_currentUserId != null) 'uid': _currentUserId,
          },
        );

        if (result['ok'] == true && result['description'] != null) {
          return result['description'] as String;
        }
      } catch (e) {
        // Fall back to enhanced mock analysis
      }
      
      // Enhanced mock image analysis with more detailed descriptions
      await Future.delayed(const Duration(milliseconds: 500));
      
      // More detailed and varied image descriptions
      final mockDescriptions = [
        'A stunning sunset over snow-capped mountains with vibrant orange and pink sky, peaceful and majestic landscape',
        'People laughing and enjoying a sunny beach day with crystal clear turquoise water and white sand',
        'Artistically plated gourmet food with vibrant colors, fresh ingredients beautifully arranged on a wooden table',
        'Modern urban cityscape at golden hour with tall glass buildings reflecting warm sunlight',
        'Lush green forest with tall trees, dappled sunlight filtering through leaves, serene nature scene',
        'Stylish fashion outfit in a trendy urban setting, well-composed with good lighting and background',
        'Breathtaking travel destination with scenic mountain views, clear blue sky, perfect vacation moment',
        'Cozy lifestyle moment with warm lighting, comfortable setting, authentic and relatable scene',
        'Colorful street art and graffiti on urban walls, vibrant and artistic urban culture',
        'Delicious coffee and pastries on a rustic wooden table, cozy cafe atmosphere',
        'Beautiful flower garden with colorful blooms, soft natural lighting, peaceful garden scene',
        'Adventure travel moment with hiking gear, scenic mountain trail, outdoor adventure vibe',
        'Elegant fashion portrait with professional styling, sophisticated and chic aesthetic',
        'Fun group photo with friends laughing, happy and energetic moment captured',
        'Minimalist modern interior with clean lines, contemporary design, stylish home decor',
      ];
      
      // Use timestamp for variety but make it more consistent per image
      final hash = imagePath.hashCode;
      return mockDescriptions[hash.abs() % mockDescriptions.length];
    } catch (e) {
      return 'Beautiful image with interesting content';
    }
  }

  Future<String> generateCaption({
    String? topic,
    String style = 'trending',
    String? imagePath,
    String? tone,
    bool useRandomProvider = true,
  }) async {
    if (imagePath == null) validatePromptLength(topic ?? '', fieldName: 'Topic');
    try {
      String finalTopic = topic ?? '';
      
      // If image is provided, analyze it first and use as primary topic
      if (imagePath != null) {
        final imageDescription = await analyzeImage(imagePath);
        // Image description becomes the main topic, keywords are additional context
        if (finalTopic.isNotEmpty) {
          finalTopic = '$imageDescription. Additional context: $finalTopic';
        } else {
          finalTopic = imageDescription;
        }
      }
      
      final styleOrTone = tone ?? style;
      final uniqueToken = DateTime.now().millisecondsSinceEpoch;
      
      final result = await _callApi(
        endpoint: 'generateCaption',
        body: {
          'topic': finalTopic.isNotEmpty ? finalTopic : 'content',
          'style': styleOrTone,
          'uniqueToken': uniqueToken,
          if (imagePath != null)
            ...{
              'hasImage': true,
              'imageDescription': finalTopic,
              'generateFromImage': true,
            },
          if (_currentUserId != null) 'uid': _currentUserId,
          'aiProvider': 'chatgpt',
        },
      );

      if (result['ok'] == true) {
        return result['caption'] as String? ?? '';
      }
      throw Exception('Failed to generate caption');
    } catch (e) {
      throw Exception('AI service unavailable. Please try again later.');
    }
  }

  // Get random AI provider for variety
  String _getRandomAIProvider() {
    final providers = ['gemini', 'chatgpt', 'claude', 'openai', 'anthropic'];
    final random = DateTime.now().millisecond % providers.length;
    return providers[random];
  }

  /// Generate multiple caption styles in parallel.
  Future<Map<String, String>> generateCaptionStyles(String topic) async {
    validatePromptLength(topic, fieldName: 'Topic');
    const styles = ['trending', 'funny', 'emotional', 'short', 'marketing'];
    final futures = styles.map((style) => generateCaption(
      topic: topic,
      style: style,
      useRandomProvider: false,
    ));
    try {
      final captions = await Future.wait(futures);
      return Map.fromIterables(styles, captions);
    } catch (e) {
      throw Exception('AI service unavailable. Please try again later.');
    }
  }

  /// Generate hashtags for a topic
  Future<List<String>> generateHashtags(String topic) async {
    final out = await generateHashtagsWithAdvice(topic);
    return out['hashtags'] as List<String>;
  }

  Future<Map<String, dynamic>> generateHashtagsWithAdvice(String topic) async {
    validatePromptLength(topic, fieldName: 'Topic');
    try {
      // Use new backend API with job-based async pattern
      final apiService = ApiService();
      
      print('[AI Service] 🚀 Creating hashtags job for topic: "$topic"');
      
      // Create job using ApiService's public method
      final jobResponse = await apiService.createHashtagsJob(topic: topic, count: 20);
      final jobId = jobResponse['jobId'] as String;
      
      print('[AI Service] ✅ Hashtags job created: $jobId');
      
      // Poll for results
      print('[AI Service] 🔄 Starting to poll job status for: $jobId');
      final result = await apiService.pollJobStatus(
        jobId,
        timeout: const Duration(seconds: 60),
      );
      
      print('[AI Service] ✅ Hashtags job completed, status: ${result['status']}');
      print('[AI Service] 📦 Full response: $result');
      print('[AI Service] 📦 Response data type: ${result['data']?.runtimeType ?? 'null'}');
      print('[AI Service] 📦 Response data: ${result['data']}');
      
      // Extract hashtags from response
      final data = result['data'];
      
      if (data == null) {
        print('[AI Service] ⚠️ Data is null');
        throw Exception('No data received from hashtags API');
      }
      
      List<String> hashtags = [];
      Map<String, dynamic>? advice;
      
      if (data is List) {
        // Direct array of hashtags
        hashtags = data.map((h) {
          String tag = h.toString();
          // Ensure hashtag starts with #
          if (!tag.startsWith('#')) {
            tag = '#$tag';
          }
          return tag;
        }).toList();
        print('[AI Service] ✅ Extracted ${hashtags.length} hashtags from List');
      } else if (data is Map) {
        // Check for nested hashtags array
        if (data['hashtags'] is List) {
          if (data['ai_advice'] is Map) {
            advice = Map<String, dynamic>.from(data['ai_advice']);
          }
          hashtags = (data['hashtags'] as List).map((h) {
            String tag = h.toString();
            if (!tag.startsWith('#')) {
              tag = '#$tag';
            }
            return tag;
          }).toList();
          print('[AI Service] ✅ Extracted ${hashtags.length} hashtags from Map.hashtags');
        } else {
          print('[AI Service] ⚠️ Data is Map but no hashtags key found. Keys: ${data.keys}');
          throw Exception('Invalid response format: Map without hashtags key');
        }
      } else {
        print('[AI Service] ⚠️ Data is neither List nor Map. Type: ${data.runtimeType}');
        throw Exception('Invalid response format: Expected List or Map, got ${data.runtimeType}');
      }
      
      if (hashtags.isEmpty) {
        throw Exception('No hashtags generated');
      }
      
      print('[AI Service] ✅ Generated ${hashtags.length} hashtags: ${hashtags.take(5).join(", ")}...');
      lastHashtagAdvice = advice;
      return {
        'hashtags': hashtags,
        'ai_advice': advice,
      };
    } catch (e) {
      print('[AI Service] ❌ Error generating hashtags: $e');
      throw Exception('Failed to generate hashtags: ${e.toString()}');
    }
  }

  /// Generate bio
  Future<String> generateBio(String description, {String style = 'short'}) async {
    validatePromptLength(description, fieldName: 'Description');
    try {
      // Use new backend API with job-based async pattern
      final apiService = ApiService();
      
      final descPreview = description.length > 50 ? '${description.substring(0, 50)}...' : description;
      print('[AI Service] 🚀 Creating bio job for description: "$descPreview", style: $style');
      
      // Create job
      final jobResponse = await apiService.createBioJob(description: description, style: style);
      final jobId = jobResponse['jobId'] as String;
      
      print('[AI Service] ✅ Bio job created: $jobId');
      
      // Poll for results
      print('[AI Service] 🔄 Starting to poll job status for: $jobId');
      final result = await apiService.pollJobStatus(
        jobId,
        timeout: const Duration(seconds: 60),
      );
      
      print('[AI Service] ✅ Bio job completed, status: ${result['status']}');
      print('[AI Service] 📦 Full response: $result');
      print('[AI Service] 📦 Response data type: ${result['data']?.runtimeType ?? 'null'}');
      print('[AI Service] 📦 Response data: ${result['data']}');
      
      // Extract bio from response
      final data = result['data'];
      
      if (data == null) {
        print('[AI Service] ⚠️ Data is null');
        throw Exception('No data received from bio API');
      }
      
      String bio = '';
      
      if (data is String) {
        bio = data.trim();
        print('[AI Service] ✅ Extracted bio from String, length: ${bio.length}');
      } else if (data is Map) {
        // Check for nested bio field
        if (data['bio'] is String) {
          bio = (data['bio'] as String).trim();
          print('[AI Service] ✅ Extracted bio from Map.bio, length: ${bio.length}');
        } else {
          print('[AI Service] ⚠️ Data is Map but no bio key found. Keys: ${data.keys}');
          throw Exception('Invalid response format: Map without bio key');
        }
      } else {
        print('[AI Service] ⚠️ Data is neither String nor Map. Type: ${data.runtimeType}');
        // Try to convert to string
        bio = data.toString().trim();
        print('[AI Service] ✅ Converted data to string, length: ${bio.length}');
      }
      
      if (bio.isEmpty || bio.length < 10) {
        throw Exception('No valid bio generated');
      }
      
      final bioPreview = bio.length > 50 ? '${bio.substring(0, 50)}...' : bio;
      print('[AI Service] ✅ Generated bio (${bio.length} chars): $bioPreview');
      return bio;
    } catch (e) {
      print('[AI Service] ❌ Error generating bio: $e');
      throw Exception('Failed to generate bio: ${e.toString()}');
    }
  }

  /// Calculate similarity between two strings (0.0 to 1.0, where 1.0 is identical)
  double _calculateSimilarity(String str1, String str2) {
    // Normalize strings (lowercase, remove extra spaces)
    final s1 = str1.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
    final s2 = str2.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
    
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    
    // Calculate word overlap similarity
    final words1 = s1.split(' ').where((w) => w.length > 2).toSet();
    final words2 = s2.split(' ').where((w) => w.length > 2).toSet();
    
    if (words1.isEmpty || words2.isEmpty) return 0.0;
    
    final intersection = words1.intersection(words2).length;
    final union = words1.union(words2).length;
    
    // Jaccard similarity
    final jaccard = intersection / union;
    
    // Also check substring similarity (for cases like "variation 1" vs "variation 2")
    final longer = s1.length > s2.length ? s1 : s2;
    final shorter = s1.length > s2.length ? s2 : s1;
    
    if (longer.contains(shorter) && shorter.length > longer.length * 0.7) {
      // High substring similarity
      return (jaccard + 0.8) / 2; // Weighted average
    }
    
    return jaccard;
  }

  /// Clean hook text - remove labels like "(variation 1)", "(variation 2)", etc.
  /// IMPORTANT: Only removes labels, preserves the actual hook content
  String _cleanHook(String hook) {
    if (hook.isEmpty) return hook;
    
    // Remove labels like "(variation 1)", "(variation 2)", "(variation 3)", etc.
    hook = hook.replaceAll(RegExp(r'\s*\(variation\s*\d+\)\s*', caseSensitive: false), '');
    // Remove labels like "1.", "2.", "3.", etc. at the start (but keep content after)
    hook = hook.replaceAll(RegExp(r'^\d+[\.\)]\s+'), '');
    // Remove labels like "Hook 1:", "Hook 2:", etc.
    hook = hook.replaceAll(RegExp(r'^hook\s*\d+:\s*', caseSensitive: false), '');
    // Remove bullet points at the start
    hook = hook.replaceAll(RegExp(r'^[•\-*]\s+'), '');
    // Remove leading/trailing whitespace
    hook = hook.trim();
    
    // If after cleaning, the hook is too short or empty, return original (might be a valid short hook)
    if (hook.length < 3 && hook != hook.trim()) {
      return hook.trim();
    }
    
    return hook;
  }

  /// Remove duplicate or highly similar hooks
  List<String> _deduplicateHooks(List<String> hooks, {double similarityThreshold = 0.7}) {
    if (hooks.length <= 1) return hooks;
    
    final cleanedHooks = hooks.map((h) => _cleanHook(h)).toList();
    final uniqueHooks = <String>[];
    
    for (final hook in cleanedHooks) {
      if (hook.isEmpty || hook.length < 5) continue;
      
      bool isDuplicate = false;
      for (final existing in uniqueHooks) {
        final similarity = _calculateSimilarity(hook, existing);
        if (similarity > similarityThreshold) {
          print('[AI Service] ⚠️ Skipping duplicate hook (similarity: ${similarity.toStringAsFixed(2)}): "$hook"');
          isDuplicate = true;
          break;
        }
      }
      
      if (!isDuplicate) {
        uniqueHooks.add(hook);
      }
    }
    
    return uniqueHooks;
  }

  /// Generate viral hooks
  Future<List<String>> generateHooks(String topic, {int count = 5}) async {
    validatePromptLength(topic, fieldName: 'Topic');
    const maxRetries = 2; // Maximum regeneration attempts
    int attempt = 0;
    
    while (attempt < maxRetries) {
      attempt++;
      try {
        // Use new backend API with job-based async pattern
        final apiService = ApiService();
        
        final topicPreview = topic.length > 50 ? '${topic.substring(0, 50)}...' : topic;
        print('[AI Service] 🚀 Creating hooks job (attempt $attempt) for topic: "$topicPreview", count: $count');
        
        // Create job
        final jobResponse = await apiService.createHooksJob(topic: topic, count: count);
        final jobId = jobResponse['jobId'] as String;
        
        print('[AI Service] ✅ Hooks job created: $jobId');
        
        // Poll for results
        print('[AI Service] 🔄 Starting to poll job status for: $jobId');
        final result = await apiService.pollJobStatus(
          jobId,
          timeout: const Duration(seconds: 60),
        );
        
        print('[AI Service] ✅ Hooks job completed, status: ${result['status']}');
        
        // Extract hooks from response
        final data = result['data'];
        
        if (data == null) {
          print('[AI Service] ⚠️ Data is null');
          if (attempt < maxRetries) {
            print('[AI Service] 🔄 Retrying hook generation...');
            continue;
          }
          throw Exception('No data received from hooks API');
        }
        
        List<String> hooks = [];
        
        if (data is List) {
          hooks = data.map((item) {
            if (item is String) {
              return _cleanHook(item.trim());
            } else if (item is Map && item['hook'] is String) {
              return _cleanHook((item['hook'] as String).trim());
            } else if (item is Map && item['text'] is String) {
              return _cleanHook((item['text'] as String).trim());
            } else {
              return _cleanHook(item.toString().trim());
            }
          }).where((hook) => hook.isNotEmpty && hook.length > 5).toList();
          print('[AI Service] ✅ Extracted ${hooks.length} hooks from List');
        } else if (data is String) {
          // Try to parse as JSON string or split by newlines
          try {
            final parsed = List<String>.from(jsonDecode(data));
            hooks = parsed.map((h) => _cleanHook(h.trim())).where((h) => h.isNotEmpty && h.length > 5).toList();
            print('[AI Service] ✅ Parsed hooks from JSON string, count: ${hooks.length}');
          } catch (e) {
            // Enhanced parsing: Handle numbered lists, line-separated, and various formats
            final lines = data.split('\n');
            hooks = [];
            
            for (final line in lines) {
              final cleaned = _cleanHook(line.trim());
              
              // Skip empty lines, very short lines, or lines that look like metadata
              if (cleaned.isEmpty || cleaned.length < 5) continue;
              
              // Skip lines that are just numbers or labels
              if (RegExp(r'^[\d\s\.\)\-•*]+$').hasMatch(cleaned)) continue;
              
              // Skip lines that are clearly not hooks (too long might be description)
              if (cleaned.length > 200) continue;
              
              hooks.add(cleaned);
            }
            
            print('[AI Service] ✅ Extracted ${hooks.length} hooks from string (parsed ${lines.length} lines)');
          }
        } else {
          print('[AI Service] ⚠️ Data is neither List nor String. Type: ${data.runtimeType}');
          if (attempt < maxRetries) {
            print('[AI Service] 🔄 Retrying hook generation...');
            continue;
          }
          throw Exception('Invalid response format: Expected List or String');
        }
        
        if (hooks.isEmpty) {
          if (attempt < maxRetries) {
            print('[AI Service] ⚠️ No hooks generated, retrying...');
            continue;
          }
          throw Exception('No valid hooks generated');
        }
        
        // Remove duplicates and highly similar hooks
        final uniqueHooks = _deduplicateHooks(hooks, similarityThreshold: 0.65);
        print('[AI Service] ✅ After deduplication: ${uniqueHooks.length} unique hooks (from ${hooks.length})');
        
        // CRITICAL: Check if we have enough hooks to meet the requested count
        if (uniqueHooks.length < count) {
          // Not enough hooks - regenerate
          if (attempt < maxRetries) {
            print('[AI Service] ⚠️ Not enough hooks (${uniqueHooks.length}/${count} requested), regenerating...');
            continue;
          } else {
            // Max retries reached - return what we have but log warning
            print('[AI Service] ⚠️ Max retries reached. Got ${uniqueHooks.length} hooks but requested $count');
            if (uniqueHooks.isEmpty) {
              throw Exception('Could not generate requested number of hooks. Please try again.');
            }
            // Return what we have (at least 1 hook)
            return uniqueHooks;
          }
        }
        
        // Check if we have too many duplicates (less than 60% unique)
        if (uniqueHooks.length < hooks.length * 0.6) {
          // Too many duplicates - regenerate
          if (attempt < maxRetries) {
            print('[AI Service] ⚠️ Too many duplicates (${uniqueHooks.length}/${hooks.length} unique), regenerating...');
            continue;
          }
        }
        
        // Take exactly the requested count
        final finalHooks = uniqueHooks.take(count).toList();
        
        // Final validation: Ensure we have exactly the requested count
        if (finalHooks.length < count) {
          if (attempt < maxRetries) {
            print('[AI Service] ⚠️ Final count mismatch (${finalHooks.length}/${count}), regenerating...');
            continue;
          } else {
            print('[AI Service] ⚠️ Final count mismatch but max retries reached. Returning ${finalHooks.length} hooks');
            if (finalHooks.isEmpty) {
              throw Exception('Could not generate requested number of hooks. Please try again.');
            }
            return finalHooks;
          }
        }
        
        print('[AI Service] ✅ Generated exactly ${finalHooks.length} unique hooks (requested: $count)');
        return finalHooks;
      } catch (e) {
        print('[AI Service] ❌ Error generating hooks (attempt $attempt): $e');
        if (attempt >= maxRetries) {
          throw Exception('Failed to generate hooks: ${e.toString()}');
        }
        // Continue to retry
      }
    }
    
    throw Exception('Failed to generate hooks after $maxRetries attempts');
  }

  /// Generate trending content
  Future<Map<String, dynamic>> generateTrends({String? niche, String category = 'All'}) async {
    try {
      // Use new backend API with job-based async pattern
      final apiService = ApiService();
      
      print('[AI Service] 🚀 Creating trends job - Niche: "$niche", Category: $category');
      
      // Create job
      final jobResponse = await apiService.createTrendsJob(niche: niche, category: category);
      final jobId = jobResponse['jobId'] as String;
      
      print('[AI Service] ✅ Trends job created: $jobId');
      
      // Poll for results
      print('[AI Service] 🔄 Starting to poll job status for: $jobId');
      final result = await apiService.pollJobStatus(
        jobId,
        timeout: const Duration(seconds: 60),
      );
      
      print('[AI Service] ✅ Trends job completed, status: ${result['status']}');
      print('[AI Service] 📦 Full response: $result');
      print('[AI Service] 📦 Response data type: ${result['data']?.runtimeType ?? 'null'}');
      print('[AI Service] 📦 Response data: ${result['data']}');
      
      // Extract trends from response
      final data = result['data'];
      
      if (data == null) {
        print('[AI Service] ⚠️ Data is null');
        throw Exception('No data received from trends API');
      }
      
      Map<String, dynamic> trends = {
        'hashtags': <String>[],
        'topics': <String>[],
        'ideas': <String>[],
        'ai_advice': null,
      };
      
      if (data is Map) {
        // Extract hashtags
        if (data['hashtags'] is List) {
          final hashtagsList = (data['hashtags'] as List)
              .map((h) => h.toString().trim())
              .where((h) => h.isNotEmpty)
              .toList();
          trends['hashtags'] = List<String>.from(hashtagsList);
        } else {
          trends['hashtags'] = <String>[];
        }
        
        // Extract topics
        if (data['topics'] is List) {
          final topicsList = (data['topics'] as List)
              .map((t) => t.toString().trim())
              .where((t) => t.isNotEmpty)
              .toList();
          trends['topics'] = List<String>.from(topicsList);
        } else {
          trends['topics'] = <String>[];
        }
        
        // Extract ideas
        if (data['ideas'] is List) {
          final ideasList = (data['ideas'] as List)
              .map((i) => i.toString().trim())
              .where((i) => i.isNotEmpty)
              .toList();
          trends['ideas'] = List<String>.from(ideasList);
        } else {
          trends['ideas'] = <String>[];
        }
        if (data['ai_advice'] is Map) {
          trends['ai_advice'] = Map<String, dynamic>.from(data['ai_advice']);
        }
        
        print('[AI Service] ✅ Extracted trends from Map - hashtags: ${trends['hashtags'].length}, topics: ${trends['topics'].length}, ideas: ${trends['ideas'].length}');
      } else {
        print('[AI Service] ⚠️ Data is not a Map. Type: ${data.runtimeType}');
        throw Exception('Invalid response format: Expected Map');
      }
      
      if (trends['hashtags'].isEmpty && trends['topics'].isEmpty && trends['ideas'].isEmpty) {
        throw Exception('No valid trends generated');
      }
      
      print('[AI Service] ✅ Generated trends successfully');
      return trends;
    } catch (e) {
      print('[AI Service] ❌ Error generating trends: $e');
      throw Exception('Failed to generate trends: ${e.toString()}');
    }
  }

  /// Generate comment reply
  Future<String> generateCommentReply(String comment, {String tone = 'friendly'}) async {
    validatePromptLength(comment, fieldName: 'Comment');
    try {
      // Use new backend API with job-based async pattern
      final apiService = ApiService();
      
      final commentPreview = comment.length > 50 ? '${comment.substring(0, 50)}...' : comment;
      print('[AI Service] 🚀 Creating comment reply job for comment: "$commentPreview", tone: $tone');
      
      // Create job
      final jobResponse = await apiService.createCommentReplyJob(comment: comment, tone: tone);
      final jobId = jobResponse['jobId'] as String;
      
      print('[AI Service] ✅ Comment reply job created: $jobId');
      
      // Poll for results
      print('[AI Service] 🔄 Starting to poll job status for: $jobId');
      final result = await apiService.pollJobStatus(
        jobId,
        timeout: const Duration(seconds: 60),
      );
      
      print('[AI Service] ✅ Comment reply job completed, status: ${result['status']}');
      print('[AI Service] 📦 Full response: $result');
      print('[AI Service] 📦 Response data type: ${result['data']?.runtimeType ?? 'null'}');
      print('[AI Service] 📦 Response data: ${result['data']}');
      
      // Extract reply from response
      final data = result['data'];
      
      if (data == null) {
        print('[AI Service] ⚠️ Data is null');
        throw Exception('No data received from comment reply API');
      }
      
      String reply = '';
      
      if (data is String) {
        reply = data.trim();
        print('[AI Service] ✅ Extracted reply from String, length: ${reply.length}');
      } else if (data is Map) {
        // Check for nested reply field
        if (data['reply'] is String) {
          reply = (data['reply'] as String).trim();
          print('[AI Service] ✅ Extracted reply from Map.reply, length: ${reply.length}');
        } else if (data['text'] is String) {
          reply = (data['text'] as String).trim();
          print('[AI Service] ✅ Extracted reply from Map.text, length: ${reply.length}');
        } else {
          print('[AI Service] ⚠️ Data is Map but no reply/text key found. Keys: ${data.keys}');
          throw Exception('Invalid response format: Map without reply/text key');
        }
      } else {
        print('[AI Service] ⚠️ Data is neither String nor Map. Type: ${data.runtimeType}');
        // Try to convert to string
        reply = data.toString().trim();
        print('[AI Service] ✅ Converted data to string, length: ${reply.length}');
      }
      
      if (reply.isEmpty || reply.length < 5) {
        throw Exception('No valid reply generated');
      }
      
      final replyPreview = reply.length > 50 ? '${reply.substring(0, 50)}...' : reply;
      print('[AI Service] ✅ Generated reply (${reply.length} chars): $replyPreview');
      return reply;
    } catch (e) {
      print('[AI Service] ❌ Error generating comment reply: $e');
      throw Exception('Failed to generate comment reply: ${e.toString()}');
    }
  }

  /// Generate post ideas
  Future<List<String>> generateIdeas(String niche) async {
    validatePromptLength(niche, fieldName: 'Niche');
    try {
      // Use new backend API with job-based async pattern
      final apiService = ApiService();
      
      print('[AI Service] 🚀 Creating post ideas job for niche: "$niche"');
      
      // Create job
      final jobResponse = await apiService.createPostIdeasJob(topic: niche, niche: niche, count: 5);
      final jobId = jobResponse['jobId'] as String;
      
      print('[AI Service] ✅ Post ideas job created: $jobId');
      
      // Poll for results
      print('[AI Service] 🔄 Starting to poll job status for: $jobId');
      final result = await apiService.pollJobStatus(
        jobId,
        timeout: const Duration(seconds: 60),
      );
      
      print('[AI Service] ✅ Post ideas job completed, status: ${result['status']}');
      print('[AI Service] 📦 Full response: $result');
      print('[AI Service] 📦 Response data type: ${result['data']?.runtimeType ?? 'null'}');
      print('[AI Service] 📦 Response data: ${result['data']}');
      
      // Extract ideas from response
      final data = result['data'];
      
      if (data == null) {
        print('[AI Service] ⚠️ Data is null');
        throw Exception('No data received from post ideas API');
      }
      
      List<String> ideas = [];
      
      if (data is List) {
        // Direct array of ideas (each idea might be a Map or String)
        ideas = data.map((item) {
          if (item is Map) {
            // Extract title or description from idea object
            return item['title']?.toString() ?? 
                   item['description']?.toString() ?? 
                   item.toString();
          } else {
            return item.toString();
          }
        }).toList();
        print('[AI Service] ✅ Extracted ${ideas.length} ideas from List');
      } else if (data is Map) {
        // Check for nested ideas array
        if (data['ideas'] is List) {
          ideas = (data['ideas'] as List).map((item) {
            if (item is Map) {
              return item['title']?.toString() ?? 
                     item['description']?.toString() ?? 
                     item.toString();
            } else {
              return item.toString();
            }
          }).toList();
          print('[AI Service] ✅ Extracted ${ideas.length} ideas from Map.ideas');
        } else {
          print('[AI Service] ⚠️ Data is Map but no ideas key found. Keys: ${data.keys}');
          throw Exception('Invalid response format: Map without ideas key');
        }
      } else {
        print('[AI Service] ⚠️ Data is neither List nor Map. Type: ${data.runtimeType}');
        throw Exception('Invalid response format: Expected List or Map, got ${data.runtimeType}');
      }
      
      if (ideas.isEmpty) {
        throw Exception('No post ideas generated');
      }
      
      print('[AI Service] ✅ Generated ${ideas.length} post ideas: ${ideas.take(3).join(", ")}...');
      return ideas;
    } catch (e) {
      print('[AI Service] ❌ Error generating post ideas: $e');
      throw Exception('Failed to generate post ideas: ${e.toString()}');
    }
  }

  /// Generate reel script
  Future<String> generateReelsScript(String topic) async {
    validatePromptLength(topic, fieldName: 'Topic');
    try {
      final result = await _callApi(
        endpoint: 'generateReelScript',
        body: {
          'topic': topic,
          if (_currentUserId != null) 'uid': _currentUserId,
        },
      );

      if (result['ok'] == true) {
        return result['script'] as String? ?? '';
      }
      throw Exception('Failed to generate script');
    } catch (e) {
      throw Exception('AI service unavailable. Please try again later.');
    }
  }

  /// Generate daily viral drop: trend theme, reel concept, 5-step shot plan, 5 hooks, caption, CTA, hashtags, best post time.
  Future<DailyViralDropModel> generateDailyViralDrop({
    required String trend,
    required String niche,
  }) async {
    validatePromptLength(trend, fieldName: 'Trend');
    validatePromptLength(niche, fieldName: 'Niche');
    try {
      final result = await _callApi(
        endpoint: 'generateDailyViralDrop',
        body: {
          'trend': trend,
          'niche': niche,
          if (_currentUserId != null) 'uid': _currentUserId,
        },
      );
      if (result['ok'] == true) {
        return DailyViralDropModel.fromMap(Map<String, dynamic>.from(result));
      }
      throw Exception('Failed to generate daily viral drop');
    } catch (e) {
      return DailyViralDropModel.fromMap(
        _getMockDailyViralDrop(trend, niche),
      );
    }
  }

  /// Generate daily drop (new schema): JSON with trend_theme, virality_score, reel_concept, steps, hooks, caption, hashtags, best_post_time, coach_summary.
  Future<DailyDropModel> generateDailyDrop({
    required String niche,
    required String trend,
  }) async {
    validatePromptLength(niche, fieldName: 'Niche');
    validatePromptLength(trend, fieldName: 'Trend');
    try {
      final result = await _callApi(
        endpoint: 'generateDailyDrop',
        body: {
          'niche': niche,
          'trend': trend,
          if (_currentUserId != null) 'uid': _currentUserId,
        },
      );
      if (result['ok'] == true) {
        final dateKey = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
        final json = Map<String, dynamic>.from(result);
        json['date'] = dateKey;
        json['niche'] = niche;
        return DailyDropModel.fromJson(json);
      }
      throw Exception('Failed to generate daily drop');
    } catch (e) {
      final dateKey = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
      final mock = _getMockDailyDrop(niche, trend);
      mock['date'] = dateKey;
      mock['niche'] = niche;
      return DailyDropModel.fromJson(mock);
    }
  }

  /// Rewrite text with different tone
  Future<String> rewriteText({
    required String text,
    String tone = 'engaging',
  }) async {
    validatePromptLength(text, fieldName: 'Text');
    try {
      final result = await _callApi(
        endpoint: 'rewriteText',
        body: {
          'text': text,
          'tone': tone,
          if (_currentUserId != null) 'uid': _currentUserId,
        },
      );

      if (result['ok'] == true) {
        return result['rewritten'] as String? ?? '';
      }
      throw Exception('Failed to rewrite text');
    } catch (e) {
      // Use mock data as fallback
      return _getMockRewrite(text, tone);
    }
  }

  /// Rewrite text in multiple tones in parallel.
  Future<Map<String, String>> rewriteTextTones(String text) async {
    validatePromptLength(text, fieldName: 'Text');
    const tones = ['simple', 'attractive', 'seo', 'engaging', 'professional'];
    try {
      final futures = tones.map((tone) => _callApi(
        endpoint: 'rewriteText',
        body: {
          'text': text,
          'tone': tone,
          if (_currentUserId != null) 'uid': _currentUserId,
        },
      ));
      final responses = await Future.wait(futures);
      final results = <String, String>{};
      for (var i = 0; i < tones.length; i++) {
        final r = responses[i];
        results[tones[i]] = r['ok'] == true
            ? (r['rewritten'] as String? ?? _getMockRewrite(text, tones[i]))
            : _getMockRewrite(text, tones[i]);
      }
      return results;
    } catch (e) {
      return {
        for (final tone in tones) tone: _getMockRewrite(text, tone),
      };
    }
  }

  /// Generate carousel content
  Future<Map<String, dynamic>> generateCarouselContent(String topic, {int slides = 5}) async {
    validatePromptLength(topic, fieldName: 'Topic');
    try {
      // Use new backend API with job-based async pattern
      final apiService = ApiService();
      
      final topicPreview = topic.length > 50 ? '${topic.substring(0, 50)}...' : topic;
      print('[AI Service] 🚀 Creating carousel job for topic: "$topicPreview", slides: $slides');
      
      // Create job
      final jobResponse = await apiService.createCarouselJob(topic: topic, slides: slides);
      final jobId = jobResponse['jobId'] as String;
      
      print('[AI Service] ✅ Carousel job created: $jobId');
      
      // Poll for results
      print('[AI Service] 🔄 Starting to poll job status for: $jobId');
      final result = await apiService.pollJobStatus(
        jobId,
        timeout: const Duration(seconds: 60),
      );
      
      print('[AI Service] ✅ Carousel job completed, status: ${result['status']}');
      print('[AI Service] 📦 Full response: $result');
      print('[AI Service] 📦 Response data type: ${result['data']?.runtimeType ?? 'null'}');
      print('[AI Service] 📦 Response data: ${result['data']}');
      
      // Extract carousel from response
      final data = result['data'];
      
      if (data == null) {
        print('[AI Service] ⚠️ Data is null');
        throw Exception('No data received from carousel API');
      }
      
      Map<String, dynamic> carousel = {
        'title': '',
        'caption': '',
        'slides': <Map<String, dynamic>>[],
      };
      
      if (data is Map) {
        carousel['title'] = data['title']?.toString() ?? 'Carousel Post';
        carousel['caption'] = data['caption']?.toString() ?? 'Check out this carousel! 💫';
        
        if (data['slides'] is List) {
          final slidesList = (data['slides'] as List)
              .map((slide) {
                if (slide is Map) {
                  return {
                    'slideNumber': slide['slideNumber'] ?? slide['slide_number'] ?? 0,
                    'title': slide['title']?.toString() ?? '',
                    'content': slide['content']?.toString() ?? slide['text']?.toString() ?? '',
                  };
                } else {
                  return {
                    'slideNumber': 0,
                    'title': '',
                    'content': slide.toString(),
                  };
                }
              })
              .where((slide) => slide['content'].toString().isNotEmpty)
              .toList();
          carousel['slides'] = List<Map<String, dynamic>>.from(slidesList);
        } else {
          carousel['slides'] = <Map<String, dynamic>>[];
        }
        
        print('[AI Service] ✅ Extracted carousel from Map - title: "${carousel['title']}", slides: ${carousel['slides'].length}');
      } else {
        print('[AI Service] ⚠️ Data is not a Map. Type: ${data.runtimeType}');
        throw Exception('Invalid response format: Expected Map');
      }
      
      if (carousel['slides'].isEmpty) {
        throw Exception('No valid carousel slides generated');
      }
      
      print('[AI Service] ✅ Generated carousel successfully with ${carousel['slides'].length} slides');
      return carousel;
    } catch (e) {
      print('[AI Service] ❌ Error generating carousel: $e');
      throw Exception('Failed to generate carousel: ${e.toString()}');
    }
  }

  // ========== LEGACY METHODS (for backward compatibility) ==========

  Future<String> generateCaptionOld({
    required String? imageDescription,
    String tone = 'friendly',
    List<String> keywords = const [],
    String? mood,
  }) async {
    final topic = imageDescription ?? 
        (keywords.isNotEmpty ? keywords.join(', ') : 'content');
    return generateCaption(topic: topic, style: 'trending');
  }

  Future<List<String>> analyzeHashtags({
    required String caption,
    String? imageDescription,
  }) async {
    final topic = '$caption $imageDescription';
    return generateHashtags(topic);
  }

  Future<String> detectMood(String? imagePath) async {
    await Future.delayed(const Duration(milliseconds: 400));
    const moods = ['happy', 'chill', 'bold', 'energetic', 'calm', 'creative'];
    return moods[DateTime.now().millisecond % moods.length];
  }

  Future<List<Map<String, dynamic>>> predictBestPostingTimes({
    required String userId,
    Map<String, int>? historicalData,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      {'hour': 9, 'day': 'Monday', 'score': 85},
      {'hour': 12, 'day': 'Wednesday', 'score': 90},
      {'hour': 18, 'day': 'Friday', 'score': 88},
      {'hour': 20, 'day': 'Saturday', 'score': 92},
      {'hour': 14, 'day': 'Thursday', 'score': 87},
    ];
  }

  Future<String> getAITip() async {
    await Future.delayed(const Duration(milliseconds: 250));
    const tips = [
      '💡 Post during peak hours (6-9 PM) for maximum engagement!',
      '📸 Use high-quality images to boost your reach by 40%',
      '🎯 Mix popular and niche hashtags for better discoverability',
      '💬 Engage with your audience in the first hour after posting',
      '✨ Post consistently - 3-5 times per week is optimal',
      '🎨 Use Instagram Stories to drive traffic to your posts',
      '📊 Analyze your top-performing posts and replicate their style',
      '🤝 Collaborate with other creators to expand your reach',
    ];
    return tips[DateTime.now().millisecond % tips.length];
  }

  Future<Map<String, dynamic>> getInstagramStats(String username) async {
    try {
      final result = await _callApi(
        endpoint: 'getInstagramStats',
        body: {'username': username},
      );

      if (result['ok'] == true) {
        return result['profile'] as Map<String, dynamic>? ?? {};
      }
      throw Exception('Failed to fetch Instagram stats');
    } catch (e) {
      throw Exception('AI service unavailable. Please try again later.');
    }
  }
}

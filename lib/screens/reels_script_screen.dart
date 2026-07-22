import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../widgets/ai_ad_banner.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/analytics_service.dart';
import '../services/history_service.dart';
import '../services/voice_service.dart';
import '../services/ai_usage_control_service.dart';
import '../services/shared_ai_content_store.dart';
import '../utils/ai_usage_guard.dart';
import '../utils/app_error_handler.dart';
import '../widgets/ai_credit_badge.dart';
import '../widgets/ai_progressive_loading.dart';
import '../widgets/voice_play_button.dart';
import 'history_screen.dart';

class _ReelQuickTopic {
  const _ReelQuickTopic(this.label, this.text);
  final String label;
  final String text;
}

const List<_ReelQuickTopic> _kReelQuickTopics = [
  _ReelQuickTopic('Viral', 'Viral 30 sec reel with high retention hook and strong CTA'),
  _ReelQuickTopic('Business', 'Business growth reel: 3 practical tips for small founders'),
  _ReelQuickTopic('Story', 'Storytelling reel: failure to comeback journey in 30 seconds'),
  _ReelQuickTopic('Educational', 'Educational reel explaining one concept in simple steps'),
];

class ReelsScriptScreen extends StatefulWidget {
  const ReelsScriptScreen({super.key});

  @override
  State<ReelsScriptScreen> createState() => _ReelsScriptScreenState();
}

class _ReelsScriptScreenState extends State<ReelsScriptScreen> {
  final _userInputController = TextEditingController();
  final _api = ApiService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final HistoryService _historyService = HistoryService();
  bool _isGenerating = false;
  String _loadingMessage = 'AI is writing your script...';
  Map<String, dynamic>? _scriptData;

  @override
  void initState() {
    super.initState();
    AiUsageControlService.instance.refresh();
    final shared = SharedAiContentStore.instance.current;
    if (shared.script.isNotEmpty) {
      _userInputController.text = shared.script.join(' ');
    } else if (shared.idea.trim().isNotEmpty) {
      _userInputController.text = shared.idea;
    } else if (shared.hook.trim().isNotEmpty) {
      _userInputController.text = shared.hook;
    }
  }

  @override
  void dispose() {
    VoiceService().stop();
    _userInputController.dispose();
    super.dispose();
  }

  Future<void> _generateScript({bool regenerate = false}) async {
    if (_userInputController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Describe your reel, or tap a quick idea below.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    VoiceService().stop();
    setState(() {
      _isGenerating = true;
        _loadingMessage = 'AI is writing your script...';
      if (regenerate) {
        _scriptData = null; // Clear previous output on regenerate
      }
    });

    try {
      final userInput = _userInputController.text.trim();
      if (kDebugMode) debugPrint('[Reels Script] Calling API with userInput: "$userInput", regenerate: $regenerate');

      final data = await runWithBackendAiGuard<Map<String, dynamic>>(
        context,
        service: AiUsageControlService.instance,
        onGenerate: () async {
          return await _api.generateReelsScript(
            userInput: userInput,
            regenerate: regenerate,
            onRetry: (message) {
              if (mounted) {
                setState(() {
                  _loadingMessage = message; // "Waking up AI server..."
                });
              }
            },
          );
        },
      );
      if (data == null || !mounted) {
        setState(() => _isGenerating = false);
        return;
      }

      // Safely convert data to Map<String, dynamic>
      final safeData = Map<String, dynamic>.from(data);
      if (kDebugMode) debugPrint('[Reels Script] Received script data: ${safeData.keys}');

      setState(() {
        _scriptData = safeData;
        _isGenerating = false;
      });
      SharedAiContentStore.instance.update(
        idea: userInput,
        hook: safeData['hook']?.toString() ?? '',
        caption: safeData['caption']?.toString() ?? '',
        hashtags: List.from(safeData['hashtags'] as List? ?? []).map((e) => e.toString()).toList(),
        script: List.from(safeData['scene_by_scene'] as List? ?? []).map((e) {
          if (e is Map) return (e['dialogue'] ?? e['visual'] ?? '').toString();
          return e.toString();
        }).where((x) => x.trim().isNotEmpty).toList(),
      );

      AnalyticsService.logAiToolUsed(toolId: 'reel_script');

      // Check for empty data and save to history (using scene_by_scene, not scenes)
      final hook = safeData['hook']?.toString() ?? '';
      final sceneByScene = safeData['scene_by_scene'] as List? ?? [];
      
      // Save to history
      if (hook.isNotEmpty || sceneByScene.isNotEmpty) {
        final scriptOutput = 'Hook: $hook\n\nScenes:\n${sceneByScene.map((s) => s.toString()).join("\n\n")}';
        await _historyService.saveHistory(
          serviceType: 'reels_script',
          input: userInput,
          output: scriptOutput,
          metadata: {
            'hook_length': hook.length,
            'scene_count': sceneByScene.length,
          },
        );
      }
      
      if (hook.isEmpty && sceneByScene.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No script generated. Please try again.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Reels Script] ERROR: ${e.toString()}');

      if (!mounted) return;
      await AppErrorHandler.log('ReelsScript', e);
      final fallback = _buildFallbackScript(_userInputController.text.trim());
      setState(() {
        _scriptData = fallback;
        _isGenerating = false;
      });
      SharedAiContentStore.instance.update(
        idea: _userInputController.text.trim(),
        hook: fallback['hook']?.toString() ?? '',
        caption: fallback['caption']?.toString() ?? '',
        hashtags: List.from(fallback['hashtags'] as List? ?? []).map((e) => e.toString()).toList(),
        script: List.from(fallback['scene_by_scene'] as List? ?? []).map((e) {
          if (e is Map) return (e['dialogue'] ?? '').toString();
          return e.toString();
        }).where((x) => x.trim().isNotEmpty).toList(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Using backup AI script for now.'),
          backgroundColor: Color(0xFF7B2CBF),
        ),
      );
    } finally {
      // CRITICAL: Ensure loading is ALWAYS turned off, even if something unexpected happens
      if (mounted && _isGenerating) {
        if (kDebugMode) debugPrint('[Reels Script] WARNING: Loading still active in finally block - forcing stop');
        setState(() => _isGenerating = false);
      }
    }
  }

  Map<String, dynamic> _buildFallbackScript(String userInput) {
    final safeTopic = userInput.isNotEmpty ? userInput : 'your topic';
    return {
      'hook': 'Stop scrolling: this $safeTopic idea can boost your reach today.',
      'scene_by_scene': [
        {
          'time': '0-3s',
          'visual': 'Close-up intro with strong expression and on-screen headline.',
          'dialogue': 'If you create $safeTopic content, this one tweak changes everything.',
        },
        {
          'time': '3-10s',
          'visual': 'Quick B-roll showing the process/problem.',
          'dialogue': 'Most creators miss this simple structure and lose retention early.',
        },
        {
          'time': '10-20s',
          'visual': 'Show solution steps with text overlays.',
          'dialogue': 'Use a clear hook, one key value point, and a direct call to action.',
        },
      ],
      'cta': 'Save this reel and comment "SCRIPT" if you want part 2.',
      'caption': 'Simple reel script formula for better retention and engagement.',
      'hashtags': ['#reels', '#instagramgrowth', '#contentcreator', '#socialmediatips'],
      'fullScript':
          'Hook: Stop scrolling: this idea can boost your reach today.\n\nScene 1 (0-3s): If you create this content, this one tweak changes everything.\nScene 2 (3-10s): Most creators miss this simple structure and lose retention early.\nScene 3 (10-20s): Use a clear hook, one key value point, and a direct call to action.\n\nCTA: Save this reel and comment "SCRIPT" if you want part 2.',
    };
  }

  String _composeFullScriptCopy() {
    if (_scriptData == null) return '';
    final full = _scriptData!['fullScript']?.toString() ?? '';
    if (full.trim().isNotEmpty) return full;
    final hook = _scriptData!['hook']?.toString() ?? '';
    final scenes = List<Map<String, dynamic>>.from(
      (List.from(_scriptData!['scene_by_scene'] as List? ?? [])).map((scene) {
        if (scene is Map) return Map<String, dynamic>.from(scene);
        return <String, dynamic>{};
      }),
    );
    final cta = _scriptData!['cta']?.toString() ?? '';
    final caption = _scriptData!['caption']?.toString() ?? '';
    final hashtags = List.from(_scriptData!['hashtags'] as List? ?? []).join(' ');
    final sceneText = scenes
        .asMap()
        .entries
        .map((entry) {
          final item = entry.value;
          final time = item['time']?.toString() ?? '';
          final dialogue = item['dialogue']?.toString() ?? '';
          return 'Scene ${entry.key + 1}${time.isNotEmpty ? ' ($time)' : ''}: $dialogue';
        })
        .join('\n');
    return 'Hook: $hook\n\n$sceneText\n\nCTA: $cta\n\nCaption: $caption\n$hashtags';
  }

  Future<void> _saveScript() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login first to save script'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_scriptData == null || _scriptData!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No script to save. Generate a script first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await _firestore.collection('script_history').add({
        'userId': user.uid,
        'userInput': _userInputController.text.trim(),
        'topic': _userInputController.text.trim(), // Keep for backward compatibility
        'scriptData': _scriptData,
        'createdAt': FieldValue.serverTimestamp(),
        'savedAt': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Script saved to history!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Reels Script] Error saving: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save script: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showHistory(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login first to view history'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Script History',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('script_history')
                    .where('userId', isEqualTo: user.uid)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (!snapshot.hasData || docs.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No saved scripts',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Generate and save a script to see it here',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final userInput = data['userInput'] ?? data['topic'] ?? 'Untitled';
                      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF7B2CBF),
                            child: const Icon(Icons.video_library, color: Colors.white),
                          ),
                          title: Text(
                            userInput.length > 50 ? '${userInput.substring(0, 50)}...' : userInput,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            createdAt != null ? DateFormat('MMM dd, yyyy • hh:mm a').format(createdAt) : 'Unknown date',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.visibility, color: Color(0xFF7B2CBF)),
                                onPressed: () {
                                  Navigator.pop(context);
                                  setState(() {
                                    // Load user input (prefer userInput, fallback to topic)
                                    _userInputController.text = data['userInput'] ?? data['topic'] ?? '';
                                    _scriptData = data['scriptData'] as Map<String, dynamic>?;
                                  });
                                },
                                tooltip: 'Load script',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteScriptHistory(doc.id),
                                tooltip: 'Delete',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteScriptHistory(String docId) async {
    try {
      await _firestore.collection('script_history').doc(docId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Script deleted from history'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    await AnalyticsService.logFirstAiResultCopiedOnce(toolId: 'reel_script');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied — paste in Instagram.'),
        backgroundColor: Color(0xFF7B2CBF),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showHowToUseGuide(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: const Text(
                      'How to Use Reels Script Writer',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGuideSection(
                      icon: Icons.info_outline,
                      iconColor: Colors.blue,
                      title: 'What is Reels Script Writer?',
                      content:
                          'Reels Script Writer helps you create complete, professional scripts for Instagram Reels. It generates scene-by-scene scripts with hooks, dialogue, visuals, CTAs, captions, and hashtags. Perfect for creators who want to produce engaging, well-structured Reels that maximize engagement and reach.',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.edit_note,
                      iconColor: const Color(0xFF7B2CBF),
                      title: 'Step 1: Enter Your Topic',
                      content:
                          'Type your Reel topic or idea in the text field. Examples:\n\n• Morning routine\n• Fitness tips\n• Productivity hacks\n• Cooking recipes\n• Travel experiences\n• Business advice\n• Life lessons\n• Any topic you want to create a Reel about\n\nBe specific for better script quality!',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.timer,
                      iconColor: Colors.green,
                      title: 'Step 2: Choose Settings',
                      content:
                          'Select your preferences:\n\n• **Duration:** 15s, 30s, or 60s (choose based on your content)\n• **Tone:** Funny, Motivational, Attitude, Emotional, or Aesthetic\n• **Audience:** Creator, Business, or Personal\n• **Language:** English, Hinglish, or Hindi\n\nThese settings help AI generate a script tailored to your needs!',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.auto_awesome,
                      iconColor: Colors.orange,
                      title: 'Step 3: Generate Script',
                      content:
                          'Click the "Generate Script" button. Our AI will create:\n\n• **Hook:** Attention-grabbing opening line (scroll stopper)\n• **Scene-by-Scene Script:** Detailed scenes with visuals and dialogue\n• **Call-to-Action (CTA):** Engagement-focused ending\n• **Caption:** Ready-to-use Instagram caption\n• **Hashtags:** Relevant hashtags for maximum reach\n\nAll components are optimized for your selected duration and tone!',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.video_library,
                      iconColor: Colors.purple,
                      title: 'Step 4: Use Your Script',
                      content:
                          'Once your script is generated:\n\n• Review the hook and use it as your opening\n• Follow the scene-by-scene breakdown\n• Record visuals as described in each scene\n• Use the dialogue/voiceover for narration\n• End with the provided CTA\n• Copy and use the caption and hashtags\n• Use "Regenerate New Style" for different approaches',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.lightbulb_outline,
                      iconColor: Colors.amber,
                      title: 'Pro Tips',
                      content:
                          '💡 **Best Practices:**\n\n• Use hooks that create curiosity or emotion\n• Follow scene timing to match your duration\n• Record visuals exactly as described\n• Speak dialogue naturally, don\'t sound scripted\n• Use CTAs that encourage saves and shares\n• Test different tones to see what works\n• Regenerate for fresh script variations\n\n💡 **Script Components:**\n\n• **Hook:** First 3 seconds - must stop scrollers\n• **Scenes:** Visual and dialogue breakdown\n• **CTA:** Encourages engagement (Save, Share, Comment)\n• **Caption:** Supports your Reel with context\n• **Hashtags:** Mix of niche and trending tags\n\n💡 **Duration Tips:**\n\n• **15s:** Quick tips, hooks, or teasers\n• **30s:** Tutorials, stories, or explanations\n• **60s:** Detailed guides, transformations, or narratives\n\n💡 **Tone Selection:**\n\n• **Funny:** Light-hearted, entertaining content\n• **Motivational:** Inspiring, uplifting messages\n• **Attitude:** Bold, confident, empowering\n• **Emotional:** Relatable, heartfelt stories\n• **Aesthetic:** Visual, artistic, mood-focused',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.psychology,
                      iconColor: Colors.purple,
                      title: 'How It Works',
                      content:
                          'Our AI Reels Script Writer uses advanced artificial intelligence to:\n\n1. **Analyze Topic:** Understands your content idea and goals\n2. **Structure Script:** Creates scene-by-scene breakdown optimized for duration\n3. **Generate Hook:** Creates scroll-stopping opening lines\n4. **Write Dialogue:** Provides natural, engaging voiceover text\n5. **Suggest Visuals:** Describes what to show in each scene\n6. **Create CTA:** Generates effective call-to-action for engagement\n7. **Optimize Caption:** Writes supporting captions with hashtags\n\nPowered by advanced AI technology that learns from viral Reels to provide scripts that actually drive engagement and growth.',
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (Colors.grey[200] ?? Colors.grey)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      bottomNavigationBar: const AiAdBanner(),
      appBar: AppBar(
        title: const Text('Reels Script Writer'),
        backgroundColor: const Color(0xFF7B2CBF),
        foregroundColor: Colors.white,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        actions: [
          ValueListenableBuilder<AiAccessState?>(
            valueListenable: AiUsageControlService.instance.state,
            builder: (_, state, __) {
              if (state == null || !state.shouldShowCounter) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  state.dailyLimit != null ? '${state.remainingCredits} / ${state.dailyLimit}' : '${state.remainingCredits}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HistoryScreen(
                    serviceType: 'reels_script',
                    serviceName: 'Reels Script History',
                  ),
                ),
              );
            },
            tooltip: 'History',
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHowToUseGuide(context),
            tooltip: 'How to use',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1A1A1A),
                    const Color(0xFF0A0A0A),
                  ]
                : [
                    const Color(0xFFF8F6FF),
                    Colors.white,
                  ],
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: 20,
          ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ValueListenableBuilder<AiAccessState?>(
                  valueListenable: AiUsageControlService.instance.state,
                  builder: (_, state, __) => AiFreeLimitBanner(state: state, onUpgrade: () => Navigator.pushNamed(context, '/premium')),
                ),
                // Input Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7B2CBF).withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Premium free text input
                      TextField(
                        controller: _userInputController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: 'Reel Idea',
                          hintText: 'Describe your reel idea...',
                          prefixIcon: const Icon(Icons.edit_note, color: Color(0xFF7B2CBF)),
                          filled: true,
                          fillColor: const Color(0xFFF8F6FF),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: const Color(0xFF7B2CBF).withOpacity(0.2)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF7B2CBF), width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Suggestion chips',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.grey[800],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _kReelQuickTopics.map((t) {
                          return ActionChip(
                            label: Text(t.label),
                            onPressed: () {
                              setState(() {
                                _userInputController.text = t.text;
                              });
                            },
                            backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
                            side: BorderSide(color: Colors.grey[400]!),
                            labelStyle: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF4A148C),
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // Centered main CTA
                      Center(
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7B2CBF).withValues(alpha: 0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: (_isGenerating || (AiUsageControlService.instance.lastState != null && AiUsageControlService.instance.lastState!.isFree && AiUsageControlService.instance.lastState!.isLimitReached)) ? null : () => _generateScript(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: Text(
                              _isGenerating
                                  ? _loadingMessage
                                  : (AiUsageControlService.instance.lastState != null && AiUsageControlService.instance.lastState!.isFree && AiUsageControlService.instance.lastState!.isLimitReached)
                                      ? 'Upgrade to Premium'
                                      : '✨ Generate Viral Reel Script',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                          ),
                        ),
                      ),
                      
                    ],
                  ),
                ),

                if (_isGenerating) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7B2CBF).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const AiProgressiveLoading(
                      messages: [
                        'Understanding your idea...',
                        'AI is writing your script...',
                        'Finishing your reel script...',
                      ],
                      accentColor: Color(0xFF7B2CBF),
                    ),
                  ),
                ],
                
                // Output Section
                if (_scriptData != null) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Reel Script Studio Output',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _copyToClipboard(_composeFullScriptCopy()),
                          icon: const Icon(Icons.copy_all_rounded, size: 18),
                          label: const Text(
                            'Copy Full Script',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF7B2CBF),
                            side: BorderSide(
                              color: const Color(0xFF7B2CBF).withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _saveScript,
                          icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                          label: const Text(
                            'Save Script',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF7B2CBF),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isGenerating ? null : () => _generateScript(regenerate: true),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text(
                            'Regenerate',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF7B2CBF),
                            side: BorderSide(
                              color: const Color(0xFF7B2CBF).withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Full Script Section (Like ChatGPT)
                  if (_scriptData!['fullScript'] != null && _scriptData!['fullScript'].toString().isNotEmpty) ...[
                    Text(
                      '📝 Complete Script',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF7B2CBF).withOpacity(0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7B2CBF).withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.description, color: Color(0xFF7B2CBF), size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Full Script (Copy All)',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ],
                              ),
                              VoicePlayButton(
                                textToSpeak: _scriptData!['fullScript'].toString(),
                                iconSize: 22,
                                iconColor: const Color(0xFF7B2CBF),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_all, color: Color(0xFF7B2CBF)),
                                onPressed: () => _copyToClipboard(_scriptData!['fullScript'].toString()),
                                tooltip: 'Copy full script',
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: SelectableText(
                              _scriptData!['fullScript'].toString(),
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.8,
                                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => _copyToClipboard(_scriptData!['fullScript'].toString()),
                              icon: const Icon(Icons.copy_all_rounded, size: 22),
                              label: const Text(
                                'Copy full script',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF7B2CBF),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  // Hook Section
                  if (_scriptData!['hook'] != null && _scriptData!['hook'].toString().isNotEmpty) ...[
                    Text(
                      'Hook Card',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7B2CBF).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _scriptData!['hook'].toString(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          VoicePlayButton(
                            textToSpeak: _scriptData!['hook'].toString(),
                            iconSize: 22,
                            iconColor: Colors.white,
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, color: Colors.white),
                            onPressed: () => _copyToClipboard(_scriptData!['hook'].toString()),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Script Scenes Section (using scene_by_scene format)
                  if ((_scriptData!['scene_by_scene'] as List? ?? []).isNotEmpty) ...[
                    Text(
                      'Scene-by-Scene Timeline',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...((_scriptData!['scene_by_scene'] as List? ?? [])).asMap().entries.map((entry) {
                      final index = entry.key;
                      // Safely convert scene to Map<String, dynamic>
                      final sceneRaw = entry.value;
                      final scene = sceneRaw is Map 
                          ? Map<String, dynamic>.from(sceneRaw)
                          : <String, dynamic>{};
                      final timestamp = scene['time']?.toString().trim().isNotEmpty == true
                          ? scene['time'].toString()
                          : '${index * 5}-${(index + 1) * 5}s';
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7B2CBF).withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Scene Header
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7B2CBF).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Scene ${index + 1}',
                                    style: const TextStyle(
                                      color: Color(0xFF7B2CBF),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  timestamp,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white70 : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            // Visual/Shot
                            if (scene['visual'] != null) ...[
                              Text(
                                'Visual:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  scene['visual'].toString(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            
                            // Dialogue/Voiceover
                            if (scene['dialogue'] != null) ...[
                              Text(
                                'Dialogue/Voiceover:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        scene['dialogue'].toString(),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                                        ),
                                      ),
                                    ),
                                    VoicePlayButton(
                                      textToSpeak: scene['dialogue'].toString(),
                                      iconSize: 18,
                                      iconColor: const Color(0xFF7B2CBF),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 18, color: Color(0xFF7B2CBF)),
                                      onPressed: () => _copyToClipboard(scene['dialogue'].toString()),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 24),
                  ],
                  
                  // CTA Section
                  if (_scriptData!['cta'] != null && _scriptData!['cta'].toString().isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7B2CBF).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.flag, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Call to Action',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _scriptData!['cta'].toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              VoicePlayButton(
                                textToSpeak: _scriptData!['cta'].toString(),
                                iconSize: 22,
                                iconColor: Colors.white,
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _copyToClipboard(_scriptData!['cta'].toString()),
                                icon: const Icon(Icons.copy, size: 18),
                                label: const Text('Copy CTA'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF7B2CBF),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Caption & Hashtags Section
                  if (_scriptData!['caption'] != null || _scriptData!['hashtags'] != null) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7B2CBF).withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.description, color: Color(0xFF7B2CBF)),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Caption & Hashtags',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.bookmark_add, color: Color(0xFF7B2CBF)),
                                onPressed: () => _saveScript(),
                                tooltip: 'Save to history',
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_scriptData!['caption'] != null) ...[
                            Text(
                              _scriptData!['caption'].toString(),
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white70 : const Color(0xFF1A1A1A),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if ((_scriptData!['hashtags'] as List? ?? []).isNotEmpty) ...[
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: List.from(_scriptData!['hashtags'] as List? ?? []).map((tag) {
                                return Chip(
                                  label: Text(
                                    tag.toString(),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  backgroundColor: const Color(0xFF7B2CBF).withOpacity(0.1),
                                  side: BorderSide.none,
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              VoicePlayButton(
                                textToSpeak: () {
                                  final caption = _scriptData!['caption']?.toString() ?? '';
                                  final hashtags = List.from(_scriptData!['hashtags'] as List? ?? []).map((t) => t.toString()).join(' ');
                                  return '$caption\n\n$hashtags';
                                }(),
                                iconSize: 22,
                                iconColor: const Color(0xFF7B2CBF),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  final caption = _scriptData!['caption']?.toString() ?? '';
                                  final hashtags = List.from(_scriptData!['hashtags'] as List? ?? []).map((t) => t.toString()).join(' ');
                                  _copyToClipboard('$caption\n\n$hashtags');
                                },
                                icon: const Icon(Icons.copy, size: 18),
                                label: const Text('Copy Caption & Hashtags'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7B2CBF),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF7B2CBF)),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


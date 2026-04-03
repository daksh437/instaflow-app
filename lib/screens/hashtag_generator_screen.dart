import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/ai_service.dart';
import '../services/history_service.dart';
import '../services/ad_service.dart';
import '../services/ai_usage_control_service.dart';
import '../utils/ai_usage_guard.dart';
import '../utils/app_error_handler.dart';
import '../widgets/ai_credit_badge.dart';
import '../widgets/ai_plan_countdown.dart';
import 'history_screen.dart';

class HashtagGeneratorScreen extends StatefulWidget {
  const HashtagGeneratorScreen({super.key});

  @override
  State<HashtagGeneratorScreen> createState() => _HashtagGeneratorScreenState();
}

class _HashtagGeneratorScreenState extends State<HashtagGeneratorScreen> {
  final TextEditingController _inputController = TextEditingController();
  final HistoryService _historyService = HistoryService();
  bool _isGenerating = false;
  List<String> _generatedHashtags = [];

  @override
  void initState() {
    super.initState();
    AiUsageControlService.instance.refresh();
  }

  Future<void> _generateHashtags() async {
    if (_inputController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a topic')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _generatedHashtags = [];
    });
    try {
      final topic = _inputController.text.trim();
      final hashtags = await runWithBackendAiGuard<List<String>>(
        context,
        service: AiUsageControlService.instance,
        onGenerate: () async {
          final aiService = AIService();
          if (kDebugMode) debugPrint('[HashtagGenerator] 🚀 Starting hashtag generation for: "$topic"');
          return await aiService.generateHashtags(topic);
        },
      );
      if (hashtags == null || !mounted) {
        setState(() => _isGenerating = false);
        return;
      }
      if (kDebugMode) debugPrint('[HashtagGenerator] ✅ Received ${hashtags.length} hashtags');

      setState(() {
        _generatedHashtags = hashtags;
        _isGenerating = false;
      });

      if (hashtags.isNotEmpty) {
        await _historyService.saveHistory(
          serviceType: 'hashtag_generator',
          input: topic,
          output: hashtags.join('\n'),
          metadata: {'count': hashtags.length},
        );
        AdService().showInterstitialAd();
        AdService().loadInterstitialAd();
      }
      if (hashtags.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hashtags generated. Please try again.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      if (!mounted) return;
      AppErrorHandler.log('HashtagGenerator', e);
      AppErrorHandler.show(context, e);
    }
  }

  void _copyAll() {
    final allTags = _generatedHashtags.join(' ');
    Clipboard.setData(ClipboardData(text: allTags));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All hashtags copied! ✨'),
        backgroundColor: Color(0xFF7B2CBF),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _copySingle(String hashtag) {
    Clipboard.setData(ClipboardData(text: hashtag));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$hashtag copied!'),
        backgroundColor: const Color(0xFF7B2CBF),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
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
                      'How to Use Hashtag Generator',
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
                      title: 'What is Hashtag Generator?',
                      content:
                          'Hashtag Generator helps you create relevant, high-performing hashtags for your Instagram posts. Generate multiple hashtags based on your content topic, ensuring better reach and discoverability. Perfect for creators who want to maximize their post visibility without spending time researching hashtags.',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.edit_note,
                      iconColor: const Color(0xFF7B2CBF),
                      title: 'Step 1: Describe Your Content',
                      content:
                          'Enter a description of your post topic or content in the text field. Be specific about:\n\n• What your post is about\n• Your niche or industry\n• Key themes or subjects\n• Target audience\n• Content type (e.g., tutorial, inspiration, product)\n\nExample: "Fitness workout routine for beginners at home" or "Delicious chocolate cake recipe"',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.auto_awesome,
                      iconColor: Colors.green,
                      title: 'Step 2: Generate Hashtags',
                      content:
                          'Click the "Generate Hashtags" button. Our AI will:\n\n• Analyze your content description\n• Generate relevant hashtags for your niche\n• Mix popular and niche-specific hashtags\n• Ensure hashtags are trending and effective\n• Provide a variety of hashtag options\n\nYou\'ll receive multiple hashtags optimized for your content!',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.content_copy,
                      iconColor: Colors.orange,
                      title: 'Step 3: Use Your Hashtags',
                      content:
                          'Once hashtags are generated:\n\n• Review all generated hashtags\n• Tap on individual hashtags to copy them\n• Use "Copy All" button to copy all hashtags at once\n• Paste hashtags in your Instagram post caption\n• Use 10-15 hashtags per post for best results\n• Mix generated hashtags with your own',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.lightbulb_outline,
                      iconColor: Colors.amber,
                      title: 'Pro Tips',
                      content:
                          '💡 **Best Practices:**\n\n• Use 10-15 hashtags per post (Instagram limit is 30)\n• Mix popular hashtags (100K+ posts) with niche ones\n• Include location-based hashtags if relevant\n• Use hashtags specific to your niche\n• Avoid banned or spam hashtags\n• Update hashtags regularly based on trends\n• Research competitor hashtags\n\n💡 **Hashtag Strategy:**\n\n• **Popular Hashtags:** High visibility but high competition\n• **Niche Hashtags:** Lower competition, targeted audience\n• **Branded Hashtags:** Your own unique hashtags\n• **Trending Hashtags:** Current popular topics\n• **Location Hashtags:** City or area-specific\n\n💡 **Optimization Tips:**\n\n• Place hashtags at the end of your caption\n• Or add them in the first comment\n• Use line breaks for better readability\n• Test different hashtag combinations\n• Track which hashtags perform best',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.psychology,
                      iconColor: Colors.purple,
                      title: 'How It Works',
                      content:
                          'Our AI Hashtag Generator uses advanced artificial intelligence to:\n\n1. **Analyze Content:** Understands your post topic and niche\n2. **Generate Hashtags:** Creates relevant, high-performing hashtags\n3. **Optimize Mix:** Balances popular and niche hashtags\n4. **Ensure Relevance:** Provides hashtags that match your content\n\nPowered by advanced AI technology that learns from successful Instagram posts to provide hashtags that actually improve reach and engagement.',
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
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('AI Hashtag Generator'),
        backgroundColor: const Color(0xFF7B2CBF),
        foregroundColor: Colors.white,
        elevation: 0,
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
                    serviceType: 'hashtag_generator',
                    serviceName: 'Hashtag Generator History',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueListenableBuilder<AiAccessState?>(
              valueListenable: AiUsageControlService.instance.state,
              builder: (_, state, __) => AiFreeLimitBanner(state: state, onUpgrade: () => Navigator.pushNamed(context, '/premium')),
            ),
            // Input Section
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: (Colors.grey[200] ?? Colors.grey)),
              ),
              child: TextField(
                controller: _inputController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Describe your post topic or content...',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(20),
                  hintStyle: TextStyle(color: Colors.grey[400]),
                ),
                style: const TextStyle(fontSize: 16),
              ),
            ),

            const SizedBox(height: 20),

            // Generate Button
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7B2CBF).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: (_isGenerating || (AiUsageControlService.instance.lastState != null && AiUsageControlService.instance.lastState!.isFree && AiUsageControlService.instance.lastState!.isLimitReached)) ? null : _generateHashtags,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
                child: _isGenerating
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Generating... ✨',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            (AiUsageControlService.instance.lastState != null && AiUsageControlService.instance.lastState!.isFree && AiUsageControlService.instance.lastState!.isLimitReached)
                                ? 'Upgrade to Premium'
                                : 'Generate Hashtags',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            // Loading
            if (_isGenerating) ...[
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B2CBF).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF7B2CBF)),
                    const SizedBox(height: 16),
                    Text(
                      'Finding the best hashtags...',
                      style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ],

            // Generated Hashtags
            if (_generatedHashtags.isNotEmpty) ...[
              const SizedBox(height: 32),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Generated Hashtags',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextButton.icon(
                          onPressed: _copyAll,
                          icon: const Icon(Icons.copy_all, color: Colors.white, size: 18),
                          label: const Text(
                            'Copy All',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          try {
                            await _historyService.saveHistory(
                              serviceType: 'hashtag_generator',
                              input: _inputController.text.trim(),
                              output: _generatedHashtags.join('\n'),
                              metadata: {'count': _generatedHashtags.length},
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Saved to history!'),
                                backgroundColor: Color(0xFF7B2CBF),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            AppErrorHandler.log('HashtagGeneratorSaveHistory', e);
                            AppErrorHandler.show(context, e);
                          }
                        },
                        icon: const Icon(Icons.bookmark_add, color: Color(0xFF7B2CBF)),
                        tooltip: 'Save to history',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Hashtag Bubbles
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: (Colors.grey[200] ?? Colors.grey)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _generatedHashtags.map((hashtag) {
                    return _HashtagBubble(
                      hashtag: hashtag,
                      onTap: () => _copySingle(hashtag),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HashtagBubble extends StatelessWidget {
  const _HashtagBubble({
    required this.hashtag,
    required this.onTap,
  });

  final String hashtag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF7B2CBF).withOpacity(0.1),
              const Color(0xFF9D4EDD).withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: const Color(0xFF7B2CBF).withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                hashtag,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7B2CBF),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.copy,
              size: 14,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}

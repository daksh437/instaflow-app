import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../widgets/ai_ad_banner.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/ai_service.dart';
import '../services/analytics_service.dart';
import '../services/history_service.dart';
import '../utils/share_helper.dart';
import '../services/ai_usage_control_service.dart';
import '../services/analytics_event_service.dart';
import '../services/shared_ai_content_store.dart';
import '../utils/ai_usage_guard.dart';
import '../utils/app_error_handler.dart';
import '../widgets/ai_credit_badge.dart';
import '../widgets/ai_progressive_loading.dart';
import '../models/ai_advice_model.dart';
import 'history_screen.dart';

class HashtagGeneratorScreen extends StatefulWidget {
  const HashtagGeneratorScreen({super.key});

  @override
  State<HashtagGeneratorScreen> createState() => _HashtagGeneratorScreenState();
}

class _HashtagGeneratorScreenState extends State<HashtagGeneratorScreen> {
  final TextEditingController _inputController = TextEditingController();
  final HistoryService _historyService = HistoryService();
  final AnalyticsEventService _analyticsEvent = AnalyticsEventService();
  static const List<String> _toneOptions = ['Viral', 'Educational', 'Bold', 'Minimal'];
  static const List<String> _nicheOptions = ['Business', 'Lifestyle', 'Fitness', 'Fashion'];

  bool _isGenerating = false;
  List<String> _generatedHashtags = [];
  AiAdviceModel? _advice;
  String _selectedTone = 'Viral';
  String _selectedNiche = 'Business';

  @override
  void initState() {
    super.initState();
    AiUsageControlService.instance.refresh();
    final shared = SharedAiContentStore.instance.current;
    if (shared.caption.trim().isNotEmpty || shared.idea.trim().isNotEmpty) {
      _inputController.text = shared.caption.trim().isNotEmpty ? shared.caption : shared.idea;
    }
    if (shared.hashtags.isNotEmpty) {
      _generatedHashtags = List<String>.from(shared.hashtags);
    }
  }

  Future<void> _generateHashtags() async {
    if (_inputController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter your content idea first.'),
          backgroundColor: Colors.orange,
        ),
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
      final result = await runWithBackendAiGuard<Map<String, dynamic>>(
        context,
        service: AiUsageControlService.instance,
        onGenerate: () async {
          final aiService = AIService();
          if (kDebugMode) debugPrint('[HashtagGenerator] 🚀 Starting hashtag generation for: "$topic"');
          return await aiService.generateHashtagsWithAdvice(topic);
        },
      );
      if (result == null || !mounted) {
        setState(() => _isGenerating = false);
        return;
      }
      final hashtags = (result['hashtags'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
      final adviceMap = result['ai_advice'];
      if (kDebugMode) debugPrint('[HashtagGenerator] ✅ Received ${hashtags.length} hashtags');

      setState(() {
        _generatedHashtags = hashtags;
        _isGenerating = false;
        _advice = adviceMap is Map
            ? (() {
                final raw = Map<String, dynamic>.from(adviceMap);
                if (raw['_meta_regenerated'] == true) {
                  unawaited(_analyticsEvent.logAppEvent('ai_advice_regenerated', {'tool': 'hashtags'}));
                }
                if (raw['_meta_low_confidence'] == true) {
                  unawaited(_analyticsEvent.logAppEvent('ai_advice_low_confidence', {'tool': 'hashtags'}));
                }
                final m = AiAdviceModel.fromMap(raw);
                return m.isUsable ? m : null;
              })()
            : null;
      });
      SharedAiContentStore.instance.update(
        idea: topic,
        caption: topic,
        hashtags: hashtags,
      );
      if (_advice != null) {
        unawaited(_analyticsEvent.logAppEvent('ai_advice_rendered', {'tool': 'hashtags'}));
      } else {
        unawaited(_analyticsEvent.logAppEvent('ai_advice_fallback_used', {'tool': 'hashtags'}));
      }

      AnalyticsService.logAiToolUsed(toolId: 'hashtag_generator');

      if (hashtags.isNotEmpty) {
        await _historyService.saveHistory(
          serviceType: 'hashtag_generator',
          input: topic,
          output: hashtags.join('\n'),
          metadata: {'count': hashtags.length},
        );
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

  Future<void> _copyAll() async {
    final allTags = _generatedHashtags.join(' ');
    await Clipboard.setData(ClipboardData(text: allTags));
    await AnalyticsService.logFirstAiResultCopiedOnce(toolId: 'hashtag_generator');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied — paste in Instagram.'),
        backgroundColor: Color(0xFF7B2CBF),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _copySingle(String hashtag) async {
    await Clipboard.setData(ClipboardData(text: hashtag));
    await AnalyticsService.logFirstAiResultCopiedOnce(toolId: 'hashtag_generator');
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

  Future<void> _saveCurrentHashtags() async {
    if (_generatedHashtags.isEmpty) return;
    try {
      await _historyService.saveHistory(
        serviceType: 'hashtag_generator',
        input: _inputController.text.trim(),
        output: _generatedHashtags.join('\n'),
        metadata: {
          'count': _generatedHashtags.length,
          'tone': _selectedTone,
          'niche': _selectedNiche,
        },
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
  }

  int _calculatePerformanceScore() {
    if (_generatedHashtags.isEmpty) return 0;
    final uniqueRatio = _generatedHashtags.toSet().length / _generatedHashtags.length;
    final hashDensity = _generatedHashtags.length >= 15 ? 1.0 : (_generatedHashtags.length / 15);
    final score = ((uniqueRatio * 55) + (hashDensity * 45)).clamp(0, 100);
    return score.round();
  }

  String _reachLabel(int score) {
    if (score >= 75) return 'High';
    if (score >= 45) return 'Medium';
    return 'Low';
  }

  String _competitionLabel(int score) {
    if (score >= 75) return 'Medium';
    if (score >= 45) return 'Low';
    return 'Low';
  }

  List<String> _primaryHashtags() => _generatedHashtags.take(5).toList();

  List<String> _growthHashtags() => _generatedHashtags.skip(5).take(7).toList();

  List<String> _nicheHashtags() => _generatedHashtags.skip(12).toList();

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
                  color: iconColor.withValues(alpha: 0.1),
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
    final score = _calculatePerformanceScore();
    final limitReached = AiUsageControlService.instance.lastState != null &&
        AiUsageControlService.instance.lastState!.isFree &&
        AiUsageControlService.instance.lastState!.isLimitReached;

    return Scaffold(
      bottomNavigationBar: const AiAdBanner(),
      backgroundColor: const Color(0xFFF7F4FF),
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
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueListenableBuilder<AiAccessState?>(
              valueListenable: AiUsageControlService.instance.state,
              builder: (_, state, __) => AiFreeLimitBanner(state: state, onUpgrade: () => Navigator.pushNamed(context, '/premium')),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFF7B2CBF).withValues(alpha: 0.12)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7B2CBF).withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _inputController,
                      minLines: 4,
                      maxLines: 7,
                      decoration: InputDecoration(
                        hintText: 'Enter your content idea...',
                        filled: true,
                        fillColor: const Color(0xFFF8F3FF),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF7B2CBF), width: 1.4),
                        ),
                        contentPadding: const EdgeInsets.all(18),
                        hintStyle: TextStyle(color: Colors.grey[500]),
                      ),
                      style: const TextStyle(fontSize: 16),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Tone',
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _toneOptions
                          .map(
                            (tone) => ChoiceChip(
                              label: Text(tone),
                              selected: _selectedTone == tone,
                              onSelected: (_) => setState(() => _selectedTone = tone),
                              selectedColor: const Color(0xFF7B2CBF).withValues(alpha: 0.16),
                              side: BorderSide(
                                color: const Color(0xFF7B2CBF).withValues(alpha: 0.24),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Niche',
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _nicheOptions
                          .map(
                            (niche) => ChoiceChip(
                              label: Text(niche),
                              selected: _selectedNiche == niche,
                              onSelected: (_) => setState(() => _selectedNiche = niche),
                              selectedColor: const Color(0xFF9D4EDD).withValues(alpha: 0.14),
                              side: BorderSide(
                                color: const Color(0xFF9D4EDD).withValues(alpha: 0.22),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7B2CBF).withValues(alpha: 0.26),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: (_isGenerating || limitReached) ? null : _generateHashtags,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
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
                              'Generating smart hashtags...',
                              style: TextStyle(fontSize: 16, color: Colors.white),
                            ),
                          ],
                        )
                      : Text(
                          limitReached ? 'Upgrade to Premium' : '✨ Generate Smart Hashtags',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.1,
                          ),
                        ),
                ),
              ),
            ),
            if (_isGenerating) ...[
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B2CBF).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const AiProgressiveLoading(
                  messages: [
                    'Reading your topic…',
                    'Generating hashtags…',
                    'Almost ready…',
                  ],
                  accentColor: Color(0xFF7B2CBF),
                ),
              ),
            ],

            if (_generatedHashtags.isNotEmpty) ...[
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF7B2CBF).withValues(alpha: 0.16),
                      const Color(0xFF9D4EDD).withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF7B2CBF).withValues(alpha: 0.18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hashtag Performance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2B1A3F),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricTile(
                            label: 'Score',
                            value: '$score / 100',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MetricTile(
                            label: 'Reach',
                            value: _reachLabel(score),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MetricTile(
                            label: 'Competition',
                            value: _competitionLabel(score),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF7B2CBF).withValues(alpha: 0.14)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _copyAll,
                        icon: const Icon(Icons.copy_all_rounded, size: 18),
                        label: const Text('Copy All'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _generateHashtags,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Regenerate'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saveCurrentHashtags,
                        icon: const Icon(Icons.bookmark_add_rounded, size: 18),
                        label: const Text('Save'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Share',
                      onPressed: () => ShareHelper.shareResult(_generatedHashtags.join(' ')),
                      icon: const Icon(Icons.ios_share_rounded, color: Color(0xFF7B2CBF)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _HashtagGroupCard(
                title: '🎯 Primary',
                subtitle: 'Top 5 strong hashtags',
                hashtags: _primaryHashtags(),
                onTapHashtag: _copySingle,
              ),
              const SizedBox(height: 12),
              _HashtagGroupCard(
                title: '🚀 Growth',
                subtitle: 'Medium competition hashtags',
                hashtags: _growthHashtags(),
                onTapHashtag: _copySingle,
              ),
              const SizedBox(height: 12),
              _HashtagGroupCard(
                title: '🔍 Niche',
                subtitle: 'Low competition hashtags',
                hashtags: _nicheHashtags(),
                onTapHashtag: _copySingle,
              ),
              if (_advice != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF7B2CBF).withValues(alpha: 0.16)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7B2CBF).withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_rounded, color: Color(0xFF7B2CBF), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _advice!.quickWin.isNotEmpty
                              ? _advice!.quickWin
                              : _advice!.diagnosis,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3A2655),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _HashtagGroupCard extends StatelessWidget {
  const _HashtagGroupCard({
    required this.title,
    required this.subtitle,
    required this.hashtags,
    required this.onTapHashtag,
  });

  final String title;
  final String subtitle;
  final List<String> hashtags;
  final Future<void> Function(String hashtag) onTapHashtag;

  @override
  Widget build(BuildContext context) {
    if (hashtags.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF7B2CBF).withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2B1A3F),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: hashtags
                .map(
                  (hashtag) => _HashtagBubble(
                    hashtag: hashtag,
                    onTap: () => onTapHashtag(hashtag),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF4A148C),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HashtagBubble extends StatefulWidget {
  const _HashtagBubble({
    required this.hashtag,
    required this.onTap,
  });

  final String hashtag;
  final Future<void> Function() onTap;

  @override
  State<_HashtagBubble> createState() => _HashtagBubbleState();
}

class _HashtagBubbleState extends State<_HashtagBubble> {
  bool _pressed = false;
  bool _copied = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _handleTap() async {
    setState(() => _pressed = true);
    await widget.onTap();
    if (!mounted) return;
    setState(() {
      _pressed = false;
      _copied = true;
    });
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 850), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.96 : 1,
      duration: const Duration(milliseconds: 120),
      child: GestureDetector(
        onTap: _handleTap,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF7B2CBF).withValues(alpha: 0.1),
                const Color(0xFF9D4EDD).withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: const Color(0xFF7B2CBF).withValues(alpha: 0.3),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  widget.hashtag,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7B2CBF),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                _copied ? Icons.check_circle_rounded : Icons.copy_rounded,
                size: 15,
                color: _copied ? Colors.green : Colors.grey[500],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../widgets/ai_ad_banner.dart';
import 'package:flutter/services.dart';
import '../services/ai_service.dart';
import '../services/analytics_service.dart';
import '../services/ai_usage_control_service.dart';
import '../services/history_service.dart';
import '../utils/ai_usage_guard.dart';
import '../utils/app_error_handler.dart';
import '../widgets/ai_credit_badge.dart';
import '../widgets/ai_plan_countdown.dart';
import '../widgets/ai_progressive_loading.dart';
import 'history_screen.dart';

class _CarouselQuickTopic {
  const _CarouselQuickTopic(this.label, this.text);
  final String label;
  final String text;
}

const List<_CarouselQuickTopic> _kCarouselQuickTopics = [
  _CarouselQuickTopic('Tips', '5 quick tips for Instagram growth in 2025'),
  _CarouselQuickTopic('Fitness', 'Beginner home workout mistakes to avoid'),
  _CarouselQuickTopic('Food', 'Easy healthy breakfast ideas under 10 minutes'),
  _CarouselQuickTopic('Business', '3 habits every small business owner needs'),
];

class CarouselWriterScreen extends StatefulWidget {
  const CarouselWriterScreen({super.key});

  @override
  State<CarouselWriterScreen> createState() => _CarouselWriterScreenState();
}

class _CarouselWriterScreenState extends State<CarouselWriterScreen> {
  final TextEditingController _topicController = TextEditingController();
  final AIService _aiService = AIService();
  final HistoryService _historyService = HistoryService();
  bool _isGenerating = false;
  Map<String, dynamic>? _carouselData;
  int _slideCount = 5;

  @override
  void initState() {
    super.initState();
    AiUsageControlService.instance.refresh();
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _generateCarousel() async {
    if (_topicController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a topic or tap a quick idea below.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _carouselData = null;
    });

    try {
      final topic = _topicController.text.trim();
      final topicPreview = topic.length > 50 ? '${topic.substring(0, 50)}...' : topic;
      if (kDebugMode) debugPrint('[CarouselWriter] 🚀 Starting carousel generation for topic: "$topicPreview", slides: $_slideCount');

      final carousel = await runWithBackendAiGuard<Map<String, dynamic>>(
        context,
        service: AiUsageControlService.instance,
        onGenerate: () => _aiService.generateCarouselContent(topic, slides: _slideCount),
      );
      if (carousel == null) {
        setState(() => _isGenerating = false);
        return;
      }
      
      if (kDebugMode) debugPrint('[CarouselWriter] ✅ Received carousel - title: "${carousel['title']}", slides: ${carousel['slides'].length}');
      
      setState(() {
        _carouselData = carousel;
        _isGenerating = false;
      });

      AnalyticsService.logAiToolUsed(toolId: 'carousel_writer');

      // Save to history
      if (carousel.isNotEmpty) {
        final carouselOutput = 'Title: ${carousel['title']}\n\nSlides:\n${(carousel['slides'] as List).map((s) => 'Slide ${(carousel['slides'] as List).indexOf(s) + 1}: ${s['text']}').join('\n\n')}';
        await _historyService.saveHistory(
          serviceType: 'carousel_writer',
          input: topic,
          output: carouselOutput,
          metadata: {'slide_count': _slideCount, 'title': carousel['title']},
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[CarouselWriter] ❌ Error: $e');
      setState(() => _isGenerating = false);
      if (!mounted) return;
      await AppErrorHandler.log('CarouselWriter', e);
      if (!mounted) return;
      AppErrorHandler.show(context, e);
    }
  }

  String _fullCarouselPlainText() {
    final data = _carouselData;
    if (data == null) return '';
    final title = data['title']?.toString() ?? '';
    final caption = data['caption']?.toString() ?? '';
    final slides = data['slides'] as List<dynamic>? ?? [];
    final buf = StringBuffer()
      ..writeln(title)
      ..writeln()
      ..writeln(caption)
      ..writeln();
    for (var i = 0; i < slides.length; i++) {
      final s = slides[i] as Map<String, dynamic>;
      final body = s['content']?.toString() ?? s['text']?.toString() ?? '';
      buf.writeln('Slide ${i + 1}: ${s['title'] ?? ''}');
      buf.writeln(body);
      buf.writeln();
    }
    return buf.toString().trim();
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    await AnalyticsService.logFirstAiResultCopiedOnce(toolId: 'carousel_writer');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied — paste in Instagram.'),
        backgroundColor: Color(0xFF7B2CBF),
        behavior: SnackBarBehavior.floating,
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
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.help_outline, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'How to Use AI Carousel Writer',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF1A1A1A)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _GuideSection(
                      icon: Icons.lightbulb_outline,
                      title: 'What is AI Carousel Writer?',
                      content: 'AI Carousel Writer uses advanced AI to create engaging Instagram carousel posts. Simply enter your topic, and the AI will generate a complete carousel with title, caption, and multiple slides.',
                    ),
                    
                    const SizedBox(height: 24),
                    
                    _GuideSection(
                      icon: Icons.edit_note,
                      title: 'Step 1: Enter Your Topic',
                      content: 'Type your carousel topic or theme in the input field. Be specific for better results.\n\nExamples:\n• "5 fitness tips for beginners"\n• "Instagram growth strategies"\n• "Healthy breakfast ideas"\n• "Productivity hacks for creators"',
                    ),
                    
                    const SizedBox(height: 24),
                    
                    _GuideSection(
                      icon: Icons.slideshow,
                      title: 'Step 2: Select Number of Slides',
                      content: 'Choose how many slides you want in your carousel (3-10 slides).\n\n• 3-5 slides: Quick tips or short lists\n• 6-8 slides: Detailed guides or step-by-step\n• 9-10 slides: Comprehensive content or tutorials',
                    ),
                    
                    const SizedBox(height: 24),
                    
                    _GuideSection(
                      icon: Icons.auto_awesome,
                      title: 'Step 3: Generate Content',
                      content: 'Click the "Generate Carousel" button. The AI will create:\n\n✅ A catchy title for your carousel\n✅ An engaging Instagram caption with hashtags\n✅ Multiple slides with titles and content\n\nEach slide will have clear, engaging text optimized for Instagram.',
                    ),
                    
                    const SizedBox(height: 24),
                    
                    _GuideSection(
                      icon: Icons.copy_all,
                      title: 'Step 4: Copy & Use',
                      content: 'Once generated, you can:\n\n• Copy the title\n• Copy the caption (includes hashtags)\n• Copy individual slides\n• Use the content directly in your Instagram carousel posts',
                    ),
                    
                    const SizedBox(height: 24),
                    
                    _GuideSection(
                      icon: Icons.tips_and_updates,
                      title: 'Pro Tips',
                      content: '💡 Be specific with your topic for better results\n💡 Use 5-7 slides for optimal engagement\n💡 Edit the generated content to match your brand voice\n💡 Add your own images to each slide\n💡 Use the caption hashtags for better reach\n💡 Regenerate if you want different content',
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF7B2CBF).withOpacity(0.1),
                            const Color(0xFF9D4EDD).withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF7B2CBF).withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline, color: Color(0xFF7B2CBF), size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'How It Works',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF7B2CBF),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'The AI analyzes your topic and creates a structured carousel post. Each slide is designed to:\n\n• Grab attention with compelling titles\n• Provide valuable, actionable content\n• Flow logically from one slide to the next\n• Keep readers engaged until the end\n• Include relevant hashtags for discovery',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.6,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const AiAdBanner(),
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('AI Carousel Writer'),
        backgroundColor: const Color(0xFF7B2CBF),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
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
                    serviceType: 'carousel_writer',
                    serviceName: 'Carousel Writer History',
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
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: (Colors.grey[200] ?? Colors.grey)),
              ),
              child: TextField(
                controller: _topicController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter your carousel topic or theme...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(20),
                ),
                style: const TextStyle(fontSize: 16, height: 1.5),
                onChanged: (_) => setState(() {}),
              ),
            ),

            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Quick ideas',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _kCarouselQuickTopics.map((t) {
                return ActionChip(
                  label: Text(t.label),
                  onPressed: () {
                    setState(() {
                      _topicController.text = t.text;
                    });
                  },
                  backgroundColor: Colors.grey[100],
                  side: BorderSide(color: Colors.grey[300]!),
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4A148C),
                    fontWeight: FontWeight.w500,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Slide count selector
            Row(
              children: [
                const Text(
                  'Number of slides:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 20),
                        onPressed: _slideCount > 3
                            ? () => setState(() => _slideCount--)
                            : null,
                        color: const Color(0xFF7B2CBF),
                      ),
                      Text(
                        '$_slideCount',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 20),
                        onPressed: _slideCount < 10
                            ? () => setState(() => _slideCount++)
                            : null,
                        color: const Color(0xFF7B2CBF),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            ValueListenableBuilder<AiAccessState?>(
              valueListenable: AiUsageControlService.instance.state,
              builder: (_, state, __) {
                final blocked = state != null && state.isFree && state.isLimitReached;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7B2CBF).withOpacity(0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: (_isGenerating || blocked) ? null : _generateCarousel,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: _isGenerating
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Building your carousel…',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(blocked ? Icons.workspace_premium : Icons.view_carousel, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    blocked ? 'Upgrade to Premium' : 'Generate Carousel',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    if (blocked && state?.resetAtUtc != null && state!.resetAtUtc!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      AiPlanCountdown(resetAtUtc: state.resetAtUtc, prefix: 'New free credits in '),
                    ],
                  ],
                );
              },
            ),

            if (_isGenerating) ...[
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B2CBF).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const AiProgressiveLoading(
                  messages: [
                    'Planning slides…',
                    'Writing your carousel…',
                    'Polishing copy…',
                  ],
                  accentColor: Color(0xFF7B2CBF),
                ),
              ),
            ],

            if (_carouselData != null) ...[
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _copyToClipboard(_fullCarouselPlainText()),
                  icon: const Icon(Icons.copy_all_rounded, size: 22),
                  label: const Text(
                    'Copy full carousel',
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
              const SizedBox(height: 16),
              
              // Save Button
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextButton.icon(
                      onPressed: () async {
                        try {
                          final carouselOutput = 'Title: ${_carouselData!['title']}\n\nCaption: ${_carouselData!['caption']}\n\nSlides:\n${(_carouselData!['slides'] as List).asMap().entries.map((e) => 'Slide ${e.key + 1}:\nTitle: ${e.value['title'] ?? ''}\nContent: ${e.value['content'] ?? e.value['text'] ?? ''}').join('\n\n')}';
                          await _historyService.saveHistory(
                            serviceType: 'carousel_writer',
                            input: _topicController.text.trim(),
                            output: carouselOutput,
                            metadata: {
                              'slide_count': _slideCount,
                              'title': _carouselData!['title'],
                              'has_caption': _carouselData!['caption'] != null && _carouselData!['caption'].toString().isNotEmpty,
                            },
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Saved to history! ✨'),
                              backgroundColor: Color(0xFF7B2CBF),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error saving: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.bookmark_add, color: Colors.white, size: 18),
                      label: const Text(
                        'Save to History',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Title and Caption
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: (Colors.grey[200] ?? Colors.grey)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Title',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.bookmark_add, color: Color(0xFF7B2CBF)),
                              onPressed: () async {
                                try {
                                  final carouselOutput = 'Title: ${_carouselData!['title']}\n\nCaption: ${_carouselData!['caption']}\n\nSlides:\n${(_carouselData!['slides'] as List).asMap().entries.map((e) => 'Slide ${e.key + 1}: ${e.value['title']}\n${e.value['content']}').join('\n\n')}';
                                  await _historyService.saveHistory(
                                    serviceType: 'carousel_writer',
                                    input: _topicController.text.trim(),
                                    output: carouselOutput,
                                    metadata: {'slide_count': _slideCount, 'title': _carouselData!['title']},
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
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error saving: $e')),
                                  );
                                }
                              },
                              tooltip: 'Save to history',
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, color: Color(0xFF7B2CBF)),
                              onPressed: () => _copyToClipboard(_carouselData!['title'] ?? ''),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _carouselData!['title'] ?? '',
                      style: const TextStyle(fontSize: 16, color: Color(0xFF1A1A1A)),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Caption',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, color: Color(0xFF7B2CBF)),
                          onPressed: () => _copyToClipboard(_carouselData!['caption'] ?? ''),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _carouselData!['caption'] ?? '',
                      style: const TextStyle(fontSize: 16, color: Color(0xFF1A1A1A), height: 1.5),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Text(
                'Carousel Slides',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 16),

              // Slides
              ...(_carouselData!['slides'] as List<dynamic>).asMap().entries.map((entry) {
                final index = entry.key;
                final slide = entry.value as Map<String, dynamic>;
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: (Colors.grey[200] ?? Colors.grey)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Slide ${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, color: Color(0xFF7B2CBF)),
                            onPressed: () => _copyToClipboard('${slide['title']}\n\n${slide['content']}'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (slide['title'] != null && slide['title'].toString().isNotEmpty)
                        Text(
                          slide['title'].toString(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      if (slide['title'] != null && slide['title'].toString().isNotEmpty)
                        const SizedBox(height: 8),
                      SelectableText(
                        slide['content']?.toString() ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;

  const _GuideSection({
    required this.icon,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (Colors.grey[200] ?? Colors.grey)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
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
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }
}

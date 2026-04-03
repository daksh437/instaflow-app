import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ai_service.dart';
import '../services/ai_usage_control_service.dart';
import '../services/history_service.dart';
import '../utils/ai_usage_guard.dart';
import '../utils/app_error_handler.dart';
import '../services/voice_service.dart';
import '../widgets/ai_credit_badge.dart';
import '../widgets/ai_plan_countdown.dart';
import '../widgets/ai_progressive_loading.dart';
import '../widgets/voice_play_button.dart';
import 'history_screen.dart';

class ViralHookScreen extends StatefulWidget {
  const ViralHookScreen({super.key});

  @override
  State<ViralHookScreen> createState() => _ViralHookScreenState();
}

class _ViralHookScreenState extends State<ViralHookScreen> {
  final TextEditingController _topicController = TextEditingController();
  final AIService _aiService = AIService();
  final HistoryService _historyService = HistoryService();
  bool _isGenerating = false;
  List<String> _hooks = [];
  int _hookCount = 5;

  @override
  void initState() {
    super.initState();
    AiUsageControlService.instance.refresh();
  }

  @override
  void dispose() {
    VoiceService().stop();
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _generateHooks() async {
    if (_topicController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a topic'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    VoiceService().stop();
    setState(() {
      _isGenerating = true;
      _hooks = [];
    });

    try {
      final topic = _topicController.text.trim();
      final topicPreview = topic.length > 50 ? '${topic.substring(0, 50)}...' : topic;
      if (kDebugMode) debugPrint('[ViralHook] 🚀 Starting hook generation for topic: "$topicPreview", count: $_hookCount');

      final hooks = await runWithBackendAiGuard<List<String>>(
        context,
        onGenerate: () => _aiService.generateHooks(topic, count: _hookCount),
        service: AiUsageControlService.instance,
      );
      if (hooks == null) {
        setState(() => _isGenerating = false);
        return;
      }
      
      if (kDebugMode) debugPrint('[ViralHook] ✅ Received ${hooks.length} hooks (requested: $_hookCount)');
      
      // Validate count match
      if (hooks.length != _hookCount) {
        if (kDebugMode) debugPrint('[ViralHook] ⚠️ Count mismatch: Got ${hooks.length}, requested $_hookCount');
        if (!mounted) return;
        
        // Show warning if count doesn't match
        if (hooks.isEmpty) {
          // No hooks at all - error already thrown by service
          return;
        } else if (hooks.length < _hookCount) {
          // Fewer hooks than requested
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Generated ${hooks.length} hooks (requested $_hookCount). Please try again for more.',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
      
      setState(() {
        _hooks = hooks;
        _isGenerating = false;
      });

      // Save to history
      if (hooks.isNotEmpty) {
        await _historyService.saveHistory(
          serviceType: 'viral_hook',
          input: topic,
          output: hooks.join('\n'),
          metadata: {'count': hooks.length, 'requested_count': _hookCount},
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ViralHook] ❌ Error: $e');
      setState(() {
        _isGenerating = false;
        _hooks = []; // Clear hooks on error
      });
      if (!mounted) return;
      
      AppErrorHandler.log('ViralHookGenerate', e);
      AppErrorHandler.show(context, e);
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Hook copied!'),
        backgroundColor: Color(0xFF7B2CBF),
        duration: Duration(seconds: 1),
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
                      'How to Use Viral Hook Creator',
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
                      title: 'What is Viral Hook Creator?',
                      content:
                          'Viral Hook Creator helps you generate attention-grabbing opening lines for your Instagram Reels, posts, and stories. These hooks are designed to stop scrollers in their tracks and increase engagement. Perfect for creators who want to maximize their content\'s reach and impact.',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.edit_note,
                      iconColor: const Color(0xFF7B2CBF),
                      title: 'Step 1: Enter Your Topic',
                      content:
                          'Type your topic or niche in the text field. Examples:\n\n• Fitness and workouts\n• Cooking and recipes\n• Travel destinations\n• Motivation and mindset\n• Beauty tips\n• Business advice\n• Any topic you want to create content about',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.numbers,
                      iconColor: Colors.green,
                      title: 'Step 2: Choose Hook Count',
                      content:
                          'Select how many hooks you want to generate (3-10). More hooks give you more options to choose from:\n\n• Use +/- buttons to adjust count\n• Minimum: 3 hooks\n• Maximum: 10 hooks\n• Recommended: 5-7 hooks for variety',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.flash_on,
                      iconColor: Colors.orange,
                      title: 'Step 3: Generate Hooks',
                      content:
                          'Click the "Generate Hooks" button. Our AI will:\n\n• Analyze your topic\n• Create scroll-stopping opening lines\n• Generate multiple unique hook variations\n• Ensure each hook is attention-grabbing\n• Provide hooks optimized for engagement',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.content_copy,
                      iconColor: Colors.purple,
                      title: 'Step 4: Use Your Hooks',
                      content:
                          'Once hooks are generated:\n\n• Review all generated hooks\n• Click the copy icon to copy any hook\n• Use hooks as opening lines in your Reels\n• Test different hooks to see what works best\n• Combine hooks with your content',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.lightbulb_outline,
                      iconColor: Colors.amber,
                      title: 'Pro Tips',
                      content:
                          '💡 **Best Practices:**\n\n• Use hooks that create curiosity or emotion\n• Test different hooks to find what resonates\n• Match hook tone to your content style\n• Keep hooks short and punchy (5-10 words)\n• Use hooks that ask questions or make bold statements\n• Combine hooks with strong visuals\n\n💡 **When to Use:**\n\n• Starting new Reels or videos\n• Creating engaging story openings\n• Writing post captions that need attention\n• Testing what hooks work for your audience\n• Building a library of proven hooks',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.psychology,
                      iconColor: Colors.purple,
                      title: 'How It Works',
                      content:
                          'Our AI Hook Creator uses advanced artificial intelligence to:\n\n1. **Analyze Topic:** Understands your niche and content type\n2. **Generate Hooks:** Creates multiple unique, attention-grabbing hooks\n3. **Optimize Engagement:** Ensures hooks are designed to stop scrollers\n4. **Ensure Variety:** Provides different hook styles and approaches\n\nPowered by advanced AI technology that learns from viral content patterns to provide hooks that actually work.',
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Viral Hook Creator'),
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
                    serviceType: 'viral_hook',
                    serviceName: 'Viral Hook History',
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
                  hintText: 'Enter your topic or niche (e.g., fitness, motivation, cooking...)',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(20),
                ),
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),

            const SizedBox(height: 16),

            // Hook count selector
            Row(
              children: [
                const Text(
                  'Number of hooks:',
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
                        onPressed: _hookCount > 3
                            ? () => setState(() => _hookCount--)
                            : null,
                        color: const Color(0xFF7B2CBF),
                      ),
                      Text(
                        '$_hookCount',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 20),
                        onPressed: _hookCount < 10
                            ? () => setState(() => _hookCount++)
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
                        onPressed: (_isGenerating || blocked) ? null : _generateHooks,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: _isGenerating
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(blocked ? Icons.workspace_premium : Icons.flash_on, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    blocked ? 'Upgrade to Premium' : 'Generate Hooks',
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
                  messages: ['Analyzing…', 'Generating hooks…', 'Optimizing output…'],
                  accentColor: Color(0xFF7B2CBF),
                ),
              ),
            ],

            if (_hooks.isNotEmpty) ...[
              const SizedBox(height: 32),
              const Text(
                'Generated Hooks',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 16),

              ..._hooks.asMap().entries.map((entry) {
                final index = entry.key;
                final hook = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
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
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SelectableText(
                            hook,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.6,
                              color: Color(0xFF1A1A1A),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.bookmark_add, color: Color(0xFF7B2CBF)),
                              onPressed: () async {
                                try {
                                  await _historyService.saveHistory(
                                    serviceType: 'viral_hook',
                                    input: _topicController.text.trim(),
                                    output: hook,
                                    metadata: {'hook_index': index + 1},
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
                                  AppErrorHandler.log('ViralHookSaveHistory', e);
                                  AppErrorHandler.show(context, e);
                                }
                              },
                              tooltip: 'Save to history',
                            ),
                            VoicePlayButton(
                              textToSpeak: hook,
                              iconSize: 20,
                              iconColor: const Color(0xFF7B2CBF),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, color: Color(0xFF7B2CBF)),
                              onPressed: () => _copyToClipboard(hook),
                              tooltip: 'Copy hook',
                            ),
                          ],
                        ),
                      ],
                    ),
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


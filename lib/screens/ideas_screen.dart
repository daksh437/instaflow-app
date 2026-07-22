import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../widgets/ai_ad_banner.dart';
import 'package:flutter/services.dart';
import '../services/ai_service.dart';
import '../services/analytics_service.dart';
import '../services/ai_usage_control_service.dart';
import '../services/history_service.dart';
import '../services/voice_service.dart';
import '../utils/ai_usage_guard.dart';
import '../utils/app_error_handler.dart';
import '../widgets/ai_credit_badge.dart';
import '../widgets/ai_plan_countdown.dart';
import '../widgets/ai_progressive_loading.dart';
import '../widgets/voice_play_button.dart';
import 'history_screen.dart';

class _IdeasQuickTopic {
  const _IdeasQuickTopic(this.label, this.text);
  final String label;
  final String text;
}

const List<_IdeasQuickTopic> _kIdeasQuickTopics = [
  _IdeasQuickTopic('Fitness', 'Fitness & home workouts for busy professionals'),
  _IdeasQuickTopic('Food', 'Easy Indian recipes for beginners'),
  _IdeasQuickTopic('Business', 'Small business tips & Instagram growth'),
  _IdeasQuickTopic('Lifestyle', 'Minimal lifestyle & productivity for students'),
];

class IdeasScreen extends StatefulWidget {
  const IdeasScreen({super.key});

  @override
  State<IdeasScreen> createState() => _IdeasScreenState();
}

class _IdeasScreenState extends State<IdeasScreen> {
  final TextEditingController _inputController = TextEditingController();
  final AIService _aiService = AIService();
  final HistoryService _historyService = HistoryService();
  bool _isGenerating = false;
  List<String> _ideas = [];

  @override
  void initState() {
    super.initState();
    AiUsageControlService.instance.refresh();
  }

  Future<void> _generateIdeas() async {
    if (_inputController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter your niche or tap a quick idea below.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    VoiceService().stop();
    setState(() {
      _isGenerating = true;
      _ideas = [];
    });

    try {
      final niche = _inputController.text.trim();
      if (kDebugMode) debugPrint('[IdeasScreen] 🚀 Starting post ideas generation for niche: "$niche"');

      final ideas = await runWithBackendAiGuard<List<String>>(
        context,
        service: AiUsageControlService.instance,
        onGenerate: () => _aiService.generateIdeas(niche),
      );
      if (ideas == null) {
        setState(() => _isGenerating = false);
        return;
      }

      if (kDebugMode) debugPrint('[IdeasScreen] ✅ Received ${ideas.length} post ideas');

      setState(() {
        _ideas = ideas;
        _isGenerating = false;
      });

      AnalyticsService.logAiToolUsed(toolId: 'ideas');

      // Save to history
      if (ideas.isNotEmpty) {
        await _historyService.saveHistory(
          serviceType: 'ideas',
          input: niche,
          output: ideas.join('\n'),
          metadata: {'count': ideas.length},
        );
      }
      
      if (ideas.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No post ideas generated. Please try again.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[IdeasScreen] ❌ Error: $e');
      setState(() => _isGenerating = false);
      if (!mounted) return;
      await AppErrorHandler.log('IdeasScreen', e);
      if (!mounted) return;
      AppErrorHandler.show(context, e);
    }
  }

  Future<void> _copyIdea(String idea) async {
    await Clipboard.setData(ClipboardData(text: idea));
    await AnalyticsService.logFirstAiResultCopiedOnce(toolId: 'ideas');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied — paste in Instagram.'),
        backgroundColor: Color(0xFF7B2CBF),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _copyAllIdeas() async {
    if (_ideas.isEmpty) return;
    final text = _ideas.join('\n\n');
    await Clipboard.setData(ClipboardData(text: text));
    await AnalyticsService.logFirstAiResultCopiedOnce(toolId: 'ideas');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied — paste in Instagram.'),
        backgroundColor: Color(0xFF7B2CBF),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    VoiceService().stop();
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const AiAdBanner(),
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Post Ideas Generator'),
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
                    serviceType: 'ideas',
                    serviceName: 'Post Ideas History',
                  ),
                ),
              );
            },
            tooltip: 'History',
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
                controller: _inputController,
                decoration: InputDecoration(
                  hintText: 'Enter your niche or content type...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(20),
                ),
                style: const TextStyle(fontSize: 16),
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
              children: _kIdeasQuickTopics.map((t) {
                return ActionChip(
                  label: Text(t.label),
                  onPressed: () {
                    setState(() {
                      _inputController.text = t.text;
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

            const SizedBox(height: 24),

            ValueListenableBuilder<AiAccessState?>(
              valueListenable: AiUsageControlService.instance.state,
              builder: (_, state, __) {
                final blocked = state != null && state.isFree && state.isLimitReached;
                final resetAtUtc = state?.resetAtUtc;
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
                        onPressed: (_isGenerating || blocked) ? null : _generateIdeas,
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
                                    'Generating ideas…',
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
                                  Icon(blocked ? Icons.workspace_premium : Icons.auto_awesome, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    blocked ? 'Upgrade to Premium' : 'Generate Ideas',
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
                    if (blocked && resetAtUtc != null && resetAtUtc.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      AiPlanCountdown(resetAtUtc: resetAtUtc, prefix: 'New free credits in '),
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
                    'Understanding your niche…',
                    'Brainstorming ideas…',
                    'Almost ready…',
                  ],
                  accentColor: Color(0xFF7B2CBF),
                ),
              ),
            ],

            if (_ideas.isNotEmpty) ...[
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Post Ideas (${_ideas.length})',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _copyAllIdeas,
                  icon: const Icon(Icons.copy_all_rounded, size: 22),
                  label: const Text(
                    'Copy all ideas',
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
              const SizedBox(height: 20),

              ...List.generate(_ideas.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: (Colors.grey[200] ?? Colors.grey)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        _ideas[index],
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.bookmark_add, size: 20),
                            color: const Color(0xFF7B2CBF),
                            onPressed: () async {
                              try {
                                await _historyService.saveHistory(
                                  serviceType: 'ideas',
                                  input: _inputController.text.trim(),
                                  output: _ideas[index],
                                  metadata: {'idea_index': index + 1},
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Saved to history!'),
                                    backgroundColor: Color(0xFF7B2CBF),
                                  ),
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error saving: $e')),
                                );
                              }
                            },
                            tooltip: 'Save to history',
                          ),
                          VoicePlayButton(
                            textToSpeak: _ideas[index],
                            iconSize: 20,
                            iconColor: const Color(0xFF7B2CBF),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 20),
                            color: const Color(0xFF7B2CBF),
                            onPressed: () => _copyIdea(_ideas[index]),
                          ),
                        ],
                      ),
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

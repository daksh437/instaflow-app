import 'package:flutter/material.dart';
import '../widgets/ai_ad_banner.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/ai_service.dart';
import '../services/history_service.dart';
import '../services/ai_usage_control_service.dart';
import '../utils/ai_usage_guard.dart';
import '../services/voice_service.dart';
import '../widgets/ai_credit_badge.dart';
import '../widgets/ai_plan_countdown.dart';
import '../widgets/voice_play_button.dart';
import '../widgets/ai_voice_play_button.dart';
import 'history_screen.dart';

class ReelScriptScreen extends StatefulWidget {
  const ReelScriptScreen({super.key});

  @override
  State<ReelScriptScreen> createState() => _ReelScriptScreenState();
}

class _ReelScriptScreenState extends State<ReelScriptScreen> {
  final TextEditingController _inputController = TextEditingController();
  final AIService _aiService = AIService();
  final HistoryService _historyService = HistoryService();
  bool _isGenerating = false;
  String? _script;

  String _buildFallbackScript(String topic) {
    final safeTopic = topic.isNotEmpty ? topic : 'your topic';
    return '''HOOK (0-3s):
"Stop scrolling! This $safeTopic framework can increase reel retention fast."

BODY (3-12s):
"Most creators miss this:
1. Open with one bold line
2. Give one clear actionable tip
3. End with a direct CTA
Try this structure in your next reel."

CTA (12-15s):
"Save this and comment 'SCRIPT' for part 2.

#reels #instagramgrowth #contentcreator #$safeTopic"''';
  }

  @override
  void initState() {
    super.initState();
    AiUsageControlService.instance.refresh();
  }

  Future<void> _generateScript() async {
    if (_inputController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a topic')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    try {
      final result = await runWithBackendAiGuard<bool>(
        context,
        service: AiUsageControlService.instance,
        onGenerate: () async {
        setState(() {
          _isGenerating = true;
          _script = null;
        });
        VoiceService().stop();

        try {
          await AiUsageControlService.instance.refresh(force: true);
          final isPro = AiUsageControlService.instance.lastState?.isPremium == true;

          final topic = _inputController.text.trim();
          
          if (isPro) {
            // Advanced script with Hook + CTA (Pro only)
            final script = await _aiService.generateReelsScript(topic);
            setState(() {
              _script = script;
              _isGenerating = false;
            });
            
            // Save to history
            if (script.isNotEmpty) {
              await _historyService.saveHistory(
                serviceType: 'reel_script',
                input: topic,
                output: script,
                metadata: {'plan': 'pro'},
              );
            }
          } else {
            // Basic script (Basic plan or trial)
            await Future.delayed(const Duration(seconds: 2));
            final basicScript = '''HOOK (0-3s):
"Stop scrolling! This $topic hack changed everything for me..."

BODY (3-12s):
"Here's what I learned:
1. Start with [first tip]
2. Then [second tip]
3. Finally [third tip]
Watch how it works..."

CTA (12-15s):
"Save this reel and try it! Let me know how it goes in the comments 👇

#${topic.replaceAll(' ', '')} #reels #tips #viral''';
            setState(() {
              _script = basicScript;
              _isGenerating = false;
            });
            
            // Save to history
            if (basicScript.isNotEmpty) {
              await _historyService.saveHistory(
                serviceType: 'reel_script',
                input: topic,
                output: basicScript,
                metadata: {'plan': 'basic'},
              );
            }
          }
          return true;
        } catch (e) {
          if (!mounted) return false;
          final topic = _inputController.text.trim();
          setState(() {
            _script = _buildFallbackScript(topic);
            _isGenerating = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('AI is busy right now. Showing backup script.'),
              backgroundColor: Color(0xFF7B2CBF),
              duration: Duration(seconds: 2),
            ),
          );
          return true;
        }
      },
      );
      if (result != true) {
        final topic = _inputController.text.trim();
        setState(() {
          _script = _buildFallbackScript(topic);
          _isGenerating = false;
        });
        return;
      }
    } catch (e) {
      if (!mounted) return;
      final topic = _inputController.text.trim();
      setState(() {
        _script = _buildFallbackScript(topic);
        _isGenerating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network issue. Showing backup script.'),
          backgroundColor: Color(0xFF7B2CBF),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _copyToClipboard() {
    if (_script != null) {
      Clipboard.setData(ClipboardData(text: _script ?? ''));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Script copied!'),
          backgroundColor: Color(0xFF7B2CBF),
          duration: Duration(seconds: 1),
        ),
      );
    }
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
        title: const Text('Reel Script Generator'),
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
                    serviceType: 'reel_script',
                    serviceName: 'Reel Script History',
                  ),
                ),
              );
            },
            tooltip: 'History',
          ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
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
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter your reel topic or idea...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(20),
                ),
                style: const TextStyle(fontSize: 16),
              ),
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
                        onPressed: (_isGenerating || blocked) ? null : _generateScript,
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
                                  Icon(blocked ? Icons.workspace_premium : Icons.auto_awesome, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    blocked ? 'Upgrade to Premium' : 'Generate Script',
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
                child: Column(
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF7B2CBF)),
                    const SizedBox(height: 16),
                    Text(
                      'Writing your reel script... ✨',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_script != null) ...[
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Your Reel Script',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AIVoicePlayButton(
                          textToSpeak: _script ?? '',
                          iconSize: 20,
                          iconColor: const Color(0xFF7B2CBF),
                        ),
                        ElevatedButton.icon(
                        onPressed: _copyToClipboard,
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Copy'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7B2CBF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: (Colors.grey[200] ?? Colors.grey)),
                ),
                padding: const EdgeInsets.all(24),
                child: SelectableText(
                  _script ?? '',
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.8,
                    color: Color(0xFF1A1A1A),
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

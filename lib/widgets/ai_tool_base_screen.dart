import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ai_service.dart';
import '../services/ai_usage_control_service.dart';
import '../services/analytics_service.dart';
import '../services/history_service.dart';
import '../services/voice_service.dart';
import '../utils/ai_usage_guard.dart';
import '../utils/app_error_handler.dart';
import '../screens/history_screen.dart';
import 'ai_progressive_loading.dart';
import 'voice_play_button.dart';
import 'ai_unified_components.dart';

final Map<String, String> _lastAiResultByTool = <String, String>{};

/// Optional preset for [AIToolBaseScreen.quickIdeas] chips.
class AiToolQuickIdea {
  const AiToolQuickIdea({required this.label, required this.text});
  final String label;
  final String text;
}

class AIToolBaseScreen extends StatefulWidget {
  const AIToolBaseScreen({
    super.key,
    required this.title,
    required this.hintText,
    required this.onGenerate,
    this.icon = Icons.auto_awesome,
    this.serviceType,
    this.analyticsToolId,
    this.quickIdeas,
    this.emptyFieldSnackText = 'Type or tap a quick idea below.',
    this.generatingButtonLabel = 'Generating magic... ✨',
    this.progressiveLoadingMessages,
    this.prominentCopy = false,
  });

  final String title;
  final String hintText;
  final Future<String> Function(String) onGenerate;
  final IconData icon;
  final String? serviceType;
  /// When set, logs [AnalyticsService.logAiToolUsed] on success and copy analytics.
  final String? analyticsToolId;
  final List<AiToolQuickIdea>? quickIdeas;
  final String emptyFieldSnackText;
  final String generatingButtonLabel;
  final List<String>? progressiveLoadingMessages;
  /// Full-width copy button under the output text (hide small Copy chip when true).
  final bool prominentCopy;

  @override
  State<AIToolBaseScreen> createState() => _AIToolBaseScreenState();
}

class _AIToolBaseScreenState extends State<AIToolBaseScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final HistoryService _historyService = HistoryService();
  bool _isGenerating = false;
  List<String> _generatedOutputs = [];
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    AiUsageControlService.instance.refresh();
    final key = widget.serviceType ?? widget.title;
    final cached = _lastAiResultByTool[key];
    if (cached != null && cached.trim().isNotEmpty) {
      _generatedOutputs = [cached];
    }
  }

  @override
  void dispose() {
    VoiceService().stop();
    _inputController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_inputController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.emptyFieldSnackText),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final result = await runWithBackendAiGuard<String>(
        context,
        onGenerate: () async {
          setState(() => _isGenerating = true);
          VoiceService().stop();
          try {
            final inputText = _inputController.text;
            final output = await widget.onGenerate(inputText);
            await AiUsageControlService.instance.refresh();
            if (!mounted) return output;
            setState(() {
              _generatedOutputs.insert(0, output);
              _isGenerating = false;
            });
            final key = widget.serviceType ?? widget.title;
            _lastAiResultByTool[key] = output;
            final tid = widget.analyticsToolId;
            if (tid != null && output.isNotEmpty) {
              AnalyticsService.logAiToolUsed(toolId: tid);
            }
            final serviceType = widget.serviceType;
            if (serviceType != null && output.isNotEmpty) {
              await _historyService.saveHistory(
                serviceType: serviceType,
                input: inputText,
                output: output,
              );
              if (!mounted) return output;
            }
            return output;
          } catch (e) {
            setState(() => _isGenerating = false);
            rethrow;
          }
        },
        limitReachedMessage: 'This AI feature requires a premium subscription. Upgrade now to unlock all AI tools!',
        service: AiUsageControlService.instance,
      );
      if (result == null && mounted) setState(() => _isGenerating = false);
    } catch (e) {
      if (!mounted) return;
      await AppErrorHandler.log('AIToolBaseScreen', e);
      final fallback = _buildFallbackOutput(_inputController.text.trim());
      setState(() {
        _isGenerating = false;
        if (fallback.isNotEmpty) {
          _generatedOutputs.insert(0, fallback);
          final key = widget.serviceType ?? widget.title;
          _lastAiResultByTool[key] = fallback;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI is taking longer than usual, showing best available result.'),
          backgroundColor: Color(0xFF7B2CBF),
        ),
      );
    }
  }

  String _buildFallbackOutput(String input) {
    final topic = input.isNotEmpty ? input : 'your topic';
    return 'Starter output for $topic:\n\n'
        '1) Strong hook line to stop scrolling.\n'
        '2) One clear value point for audience.\n'
        '3) Action-oriented CTA.\n\n'
        'Use this as a baseline and regenerate for a refined version.';
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    final tid = widget.analyticsToolId;
    if (tid != null) {
      await AnalyticsService.logFirstAiResultCopiedOnce(toolId: tid);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied — paste in Instagram.'),
        backgroundColor: Color(0xFF7B2CBF),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _regenerate(String currentText) async {
    VoiceService().stop();
    setState(() => _isGenerating = true);
    try {
      final output = await widget.onGenerate(_inputController.text);
      final index = _generatedOutputs.indexOf(currentText);
      if (index != -1) {
        setState(() {
          _generatedOutputs[index] = output;
          _isGenerating = false;
        });
      }
    } catch (e) {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _makeShort(String text) async {
    setState(() => _isGenerating = true);
    try {
      final aiService = AIService();
      final short = await aiService.rewriteText(text: text, tone: 'simple');
      final index = _generatedOutputs.indexOf(text);
      if (index != -1) {
        setState(() {
          _generatedOutputs[index] = short;
          _isGenerating = false;
        });
      } else {
        setState(() => _isGenerating = false);
      }
    } catch (e) {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _makeLong(String text) async {
    setState(() => _isGenerating = true);
    try {
      final aiService = AIService();
      final long = await aiService.rewriteText(text: text, tone: 'engaging');
      final index = _generatedOutputs.indexOf(text);
      if (index != -1) {
        setState(() {
          _generatedOutputs[index] = long;
          _isGenerating = false;
        });
      } else {
        setState(() => _isGenerating = false);
      }
    } catch (e) {
      setState(() => _isGenerating = false);
    }
  }

  void _addEmojis(String text) {
    final emojis = ['✨', '💫', '🔥', '💯', '🎯', '🚀'];
    final emojiText = '$text ${emojis.join(' ')}';
    final index = _generatedOutputs.indexOf(text);
    if (index != -1) {
      setState(() {
        _generatedOutputs[index] = emojiText;
      });
    }
  }

  void _addHashtags(String text) {
    final hashtags = '#instagram #instagood #photooftheday #love #beautiful';
    final hashtagText = '$text\n\n$hashtags';
    final index = _generatedOutputs.indexOf(text);
    if (index != -1) {
      setState(() {
        _generatedOutputs[index] = hashtagText;
      });
    }
  }

  Future<void> _createAnotherStyle(String text) async {
    setState(() => _isGenerating = true);
    await Future.delayed(const Duration(seconds: 1));
    final style = '[NEW STYLE] $text\n\nThis is a different style variation of your content.';
    setState(() {
      _generatedOutputs.insert(0, style);
      _isGenerating = false;
    });
  }

  Future<void> _boostGenerate() async {
    final base = _inputController.text.trim();
    if (base.isEmpty || _isGenerating) return;
    final boosted = '$base\n\nMake it more viral. Strengthen hook, emotion, clarity and CTA.';
    _inputController.text = boosted;
    _inputController.selection = TextSelection.collapsed(offset: boosted.length);
    await _generate();
    if (!mounted) return;
    _inputController.text = base;
    _inputController.selection = TextSelection.collapsed(offset: base.length);
  }

  void _openSmartLink(String route) {
    if (!mounted) return;
    Navigator.pushNamed(context, route);
  }

  String? _smartLinkRouteForPrimaryAction() {
    final st = (widget.serviceType ?? '').toLowerCase();
    if (st.contains('reel') || st.contains('script')) return '/schedule-post';
    if (st.contains('caption')) return '/hashtags';
    if (st.contains('idea')) return '/reels-script-writer';
    return null;
  }

  String? _smartLinkRouteForSecondaryAction() {
    final st = (widget.serviceType ?? '').toLowerCase();
    if (st.contains('caption')) return '/hashtags';
    if (st.contains('idea')) return '/reels-script-writer';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFF7B2CBF),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          ValueListenableBuilder<AiAccessState?>(
            valueListenable: AiUsageControlService.instance.state,
            builder: (context, state, _) {
              if (state == null || !state.shouldShowCounter) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  state.dailyLimit != null ? '${state.remainingCredits} / ${state.dailyLimit}' : '${state.remainingCredits}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: 'Report problem',
            onPressed: () => Navigator.pushNamed(context, '/feedback'),
          ),
          if (widget.serviceType != null)
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HistoryScreen(
                      serviceType: widget.serviceType,
                      serviceName: '${widget.title} History',
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
            AiInputCard(
              controller: _inputController,
              hintText: widget.hintText,
              quickIdeas: (widget.quickIdeas ?? const [])
                  .map((q) => AiSuggestionChip(label: q.label, text: q.text))
                  .toList(),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 16),

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
                      color: const Color(0xFF7B2CBF).withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: AiTapScale(
                  child: ElevatedButton(
                    onPressed: _isGenerating ? null : _generate,
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
                      _isGenerating ? widget.generatingButtonLabel : '✨ Generate',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            AiTapScale(
              child: OutlinedButton.icon(
                onPressed: _isGenerating ? null : _boostGenerate,
                icon: const Icon(Icons.flash_on_rounded),
                label: const Text('✨ Make it more viral'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7B2CBF),
                  side: BorderSide(color: const Color(0xFF7B2CBF).withValues(alpha: 0.35)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            // Loading Animation - progressive text + progress bar
            if (_isGenerating) ...[
              const SizedBox(height: 24),
              AiLoadingState(
                messages: widget.progressiveLoadingMessages ??
                    const [
                      'Analyzing your input...',
                      'Generating high-quality output...',
                      'Optimizing for engagement...',
                    ],
              ),
            ],
            if (!_isGenerating && _generatedOutputs.isEmpty) ...[
              const SizedBox(height: 24),
              const AiEmptyState(
                title: 'No output yet',
                subtitle: 'Generate once and your premium AI result cards will appear here.',
              ),
            ],

            // Generated Outputs
            if (_generatedOutputs.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Generated Results',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_generatedOutputs.length} result${_generatedOutputs.length > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Output Cards
            ..._generatedOutputs.map((output) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: AiResultCard(
                    title: 'AI Result',
                    mainResult: output,
                    actions: AiActionBar(
                      onCopy: () => _copyToClipboard(output),
                      onRegenerate: () => _regenerate(output),
                      onSchedule: _smartLinkRouteForPrimaryAction() != null
                          ? () => _openSmartLink(_smartLinkRouteForPrimaryAction()!)
                          : null,
                      onShare: _smartLinkRouteForSecondaryAction() != null
                          ? () => _openSmartLink(_smartLinkRouteForSecondaryAction()!)
                          : null,
                      onSave: widget.serviceType != null
                          ? () async {
                              try {
                                final st = widget.serviceType;
                                if (st == null) return;
                                await _historyService.saveHistory(
                                  serviceType: st,
                                  input: _inputController.text,
                                  output: output,
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
                                AppErrorHandler.log('AIToolBaseSaveHistory', e);
                              }
                            }
                          : null,
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _OutputCard extends StatelessWidget {
  const _OutputCard({
    required this.output,
    this.prominentCopy = false,
    required this.onCopy,
    required this.onRegenerate,
    required this.onMakeShort,
    required this.onMakeLong,
    required this.onAddEmojis,
    required this.onAddHashtags,
    required this.onCreateAnotherStyle,
    this.onSave,
    this.serviceType,
  });

  final String output;
  final bool prominentCopy;
  final VoidCallback onCopy;
  final VoidCallback onRegenerate;
  final VoidCallback onMakeShort;
  final VoidCallback onMakeLong;
  final VoidCallback onAddEmojis;
  final VoidCallback onAddHashtags;
  final VoidCallback onCreateAnotherStyle;
  final VoidCallback? onSave;
  final String? serviceType;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Output Text
              SelectableText(
                output,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: Color(0xFF1A1A1A),
                  fontWeight: FontWeight.w400,
                ),
              ),
            if (prominentCopy) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy, size: 20),
                  label: const Text('Copy reply'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7B2CBF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
              // Action Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                VoicePlayButton(textToSpeak: output, iconSize: 18, iconColor: const Color(0xFF7B2CBF)),
                if (onSave != null && serviceType != null)
                  _ActionButton(
                    icon: Icons.bookmark_add,
                    label: 'Save',
                    onPressed: onSave!,
                  ),
                if (!prominentCopy)
                  _ActionButton(
                    icon: Icons.copy,
                    label: 'Copy',
                    onPressed: onCopy,
                  ),
                _ActionButton(
                  icon: Icons.refresh,
                  label: 'Regenerate',
                  onPressed: onRegenerate,
                ),
                _ActionButton(
                  icon: Icons.short_text,
                  label: 'Make Short',
                  onPressed: onMakeShort,
                ),
                _ActionButton(
                  icon: Icons.text_fields,
                  label: 'Make Long',
                  onPressed: onMakeLong,
                ),
                _ActionButton(
                  icon: Icons.sentiment_satisfied,
                  label: 'Add Emojis',
                  onPressed: onAddEmojis,
                ),
                _ActionButton(
                  icon: Icons.tag,
                  label: 'Add Hashtags',
                  onPressed: onAddHashtags,
                ),
                _ActionButton(
                  icon: Icons.style,
                  label: 'Another Style',
                  onPressed: onCreateAnotherStyle,
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7B2CBF).withOpacity(0.1),
            const Color(0xFF9D4EDD).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF7B2CBF).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16, color: const Color(0xFF7B2CBF)),
        label: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF7B2CBF),
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: const Color(0xFF7B2CBF),
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}


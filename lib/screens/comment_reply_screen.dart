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

class _CommentQuickIdea {
  const _CommentQuickIdea(this.label, this.text);
  final String label;
  final String text;
}

const List<_CommentQuickIdea> _kCommentQuickIdeas = [
  _CommentQuickIdea('Love this', 'Love this post! Where can I get this?'),
  _CommentQuickIdea('Price?', 'How much is this? DM details please 🙏'),
  _CommentQuickIdea('Collab', 'Amazing content! Would love to collab.'),
  _CommentQuickIdea('Question', 'Can you make a tutorial on this?'),
];

class CommentReplyScreen extends StatefulWidget {
  const CommentReplyScreen({super.key});

  @override
  State<CommentReplyScreen> createState() => _CommentReplyScreenState();
}

class _CommentReplyScreenState extends State<CommentReplyScreen> {
  final TextEditingController _inputController = TextEditingController();
  final AIService _aiService = AIService();
  final HistoryService _historyService = HistoryService();
  bool _isGenerating = false;
  String? _generatedReply;

  @override
  void initState() {
    super.initState();
    AiUsageControlService.instance.refresh();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _generateReply() async {
    if (_inputController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paste a comment, or tap a quick idea below.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _generatedReply = null;
    });

    try {
      final comment = _inputController.text.trim();
      final commentPreview = comment.length > 50 ? '${comment.substring(0, 50)}...' : comment;
      if (kDebugMode) debugPrint('[CommentReply] 🚀 Starting reply generation for comment: "$commentPreview"');

      final reply = await runWithBackendAiGuard<String>(
        context,
        service: AiUsageControlService.instance,
        onGenerate: () => _aiService.generateCommentReply(comment),
      );
      if (reply == null) {
        setState(() => _isGenerating = false);
        return;
      }
      
      if (kDebugMode) debugPrint('[CommentReply] ✅ Received reply: ${reply.length} chars');
      
      setState(() {
        _generatedReply = reply;
        _isGenerating = false;
      });

      AnalyticsService.logAiToolUsed(toolId: 'comment_reply');

      // Save to history
      if (reply.isNotEmpty) {
        await _historyService.saveHistory(
          serviceType: 'comment_reply',
          input: comment,
          output: reply,
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[CommentReply] ❌ Error: $e');
      setState(() => _isGenerating = false);
      if (!mounted) return;
      await AppErrorHandler.log('CommentReply', e);
      if (!mounted) return;
      AppErrorHandler.show(context, e);
    }
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    await AnalyticsService.logFirstAiResultCopiedOnce(toolId: 'comment_reply');
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
                      'How to Use AI Comment Reply',
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
                      title: 'What is AI Comment Reply?',
                      content:
                          'AI Comment Reply helps you generate professional, engaging, and contextually appropriate replies to Instagram comments using advanced AI. Perfect for creators who want to maintain an active presence without spending hours crafting responses.',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.edit_note,
                      iconColor: const Color(0xFF7B2CBF),
                      title: 'Step 1: Paste the Comment',
                      content:
                          'Copy the comment you want to reply to from Instagram and paste it into the text field. You can paste:\n\n• Questions from followers\n• Compliments or feedback\n• Requests or suggestions\n• Any comment that needs a response',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.smart_toy,
                      iconColor: Colors.green,
                      title: 'Step 2: Generate AI Reply',
                      content:
                          'Click the "Generate Reply" button. Our AI will:\n\n• Analyze the comment context\n• Understand the tone and intent\n• Generate a professional, friendly reply\n• Match your brand voice\n• Keep responses authentic and engaging',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.content_copy,
                      iconColor: Colors.orange,
                      title: 'Step 3: Copy & Use',
                      content:
                          'Once the reply is generated:\n\n• Review the AI-generated reply\n• Click the copy icon to copy it\n• Paste it directly into Instagram\n• Edit if needed to add personal touch',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.lightbulb_outline,
                      iconColor: Colors.amber,
                      title: 'Pro Tips',
                      content:
                          '💡 **Best Practices:**\n\n• Use for high-volume comment sections\n• Personalize AI replies with your own touch\n• Mix AI replies with manual responses\n• Review before posting to ensure authenticity\n• Use for common questions and compliments\n\n💡 **When to Use:**\n\n• Responding to frequently asked questions\n• Thanking followers for compliments\n• Engaging with positive feedback\n• Maintaining consistent brand voice\n• Saving time on repetitive responses',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.psychology,
                      iconColor: Colors.purple,
                      title: 'How It Works',
                      content:
                          'Our AI Comment Reply uses advanced artificial intelligence to:\n\n1. **Analyze Context:** Understands the comment\'s meaning, tone, and intent\n2. **Generate Response:** Creates a contextually appropriate reply\n3. **Optimize Tone:** Matches friendly, professional, or casual tones\n4. **Ensure Quality:** Produces natural, human-like responses\n\nPowered by advanced AI technology that learns from millions of social media interactions to provide the best possible replies.',
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
      bottomNavigationBar: const AiAdBanner(),
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('AI Comment Reply'),
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
                    serviceType: 'comment_reply',
                    serviceName: 'Comment Reply History',
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
                controller: _inputController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Paste the comment you want to reply to...',
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
              children: _kCommentQuickIdeas.map((t) {
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
                        onPressed: (_isGenerating || blocked) ? null : _generateReply,
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
                                    'Writing your reply…',
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
                                  Icon(blocked ? Icons.workspace_premium : Icons.comment_outlined, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    blocked ? 'Upgrade to Premium' : 'Generate Reply',
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
                    'Reading the comment…',
                    'Writing your reply…',
                    'Almost ready…',
                  ],
                  accentColor: Color(0xFF7B2CBF),
                ),
              ),
            ],

            if (_generatedReply != null) ...[
              const SizedBox(height: 32),
              const Text(
                'Generated Reply',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 16),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
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
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'AI Reply',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, color: Color(0xFF7B2CBF)),
                            onPressed: () => _copyToClipboard(_generatedReply ?? ''),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SelectableText(
                        _generatedReply ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _copyToClipboard(_generatedReply ?? ''),
                          icon: const Icon(Icons.copy_all_rounded, size: 22),
                          label: const Text(
                            'Copy reply',
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
              ),
            ],
          ],
        ),
      ),
    );
  }
}


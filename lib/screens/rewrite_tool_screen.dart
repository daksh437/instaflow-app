import 'package:flutter/material.dart';
import '../widgets/ai_ad_banner.dart';
import 'package:flutter/services.dart';
import '../services/ai_service.dart';
import '../services/analytics_service.dart';
import '../services/history_service.dart';
import '../services/ai_usage_control_service.dart';
import '../utils/app_error_handler.dart';
import '../utils/ai_usage_guard.dart';
import '../widgets/ai_progressive_loading.dart';
import 'history_screen.dart';

class _RewriteQuickTopic {
  const _RewriteQuickTopic(this.label, this.text);
  final String label;
  final String text;
}

const List<_RewriteQuickTopic> _kRewriteQuickTopics = [
  _RewriteQuickTopic('Short', 'Check out our new drop — link in bio. Limited time only!'),
  _RewriteQuickTopic('Long', 'We started this brand in a small room with one idea: make quality affordable. Today thank you for 10k followers — your support means everything.'),
  _RewriteQuickTopic('Offer', 'Sale ends Sunday! 30% off sitewide. Use code SAVE30 at checkout.'),
  _RewriteQuickTopic('Casual', 'POV: you finally found the skincare routine that actually works 😌'),
];

class RewriteToolScreen extends StatefulWidget {
  const RewriteToolScreen({super.key});

  @override
  State<RewriteToolScreen> createState() => _RewriteToolScreenState();
}

class _RewriteToolScreenState extends State<RewriteToolScreen> {
  final TextEditingController _inputController = TextEditingController();
  final AIService _aiService = AIService();
  final HistoryService _historyService = HistoryService();
  bool _isGenerating = false;
  Map<String, String>? _generatedRewrites;
  String? _selectedTone;

  final Map<String, String> _tones = {
    'simple': 'Simple',
    'attractive': 'Attractive',
    'seo': 'SEO Optimized',
    'engaging': 'Engaging',
    'professional': 'Professional',
  };

  Future<void> _generateAllTones() async {
    if (_inputController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paste text or tap a quick idea below.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _generatedRewrites = null;
      _selectedTone = null;
    });

    try {
      final inputText = _inputController.text.trim();
      // Guard enforces freemium (trial/premium unlimited, free 2/day) and shows
      // an interstitial ad after each output for non-premium users.
      final rewrites = await runWithBackendAiGuard<Map<String, String>>(
        context,
        service: AiUsageControlService.instance,
        onGenerate: () => _aiService.rewriteTextTones(inputText),
      );
      if (rewrites == null) {
        if (mounted) setState(() => _isGenerating = false);
        return; // limit reached / not logged in — guard already handled the UI
      }
      if (!mounted) return;
      setState(() {
        _generatedRewrites = rewrites;
        _selectedTone = rewrites.keys.first;
        _isGenerating = false;
      });

      AnalyticsService.logAiToolUsed(toolId: 'rewrite_tool');

      // Save to history
      if (rewrites.isNotEmpty) {
        final allRewrites = rewrites.entries.map((e) => '${e.key}: ${e.value}').join('\n\n');
        await _historyService.saveHistory(
          serviceType: 'rewrite_tool',
          input: inputText,
          output: allRewrites,
          metadata: {'tones': rewrites.keys.toList()},
        );
        if (!mounted) return;
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      if (!mounted) return;
      await AppErrorHandler.log('RewriteTool', e);
      if (!mounted) return;
      AppErrorHandler.show(context, e);
    }
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    await AnalyticsService.logFirstAiResultCopiedOnce(toolId: 'rewrite_tool');
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
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const AiAdBanner(),
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('AI Smart Rewrite'),
        backgroundColor: const Color(0xFF7B2CBF),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HistoryScreen(
                    serviceType: 'rewrite_tool',
                    serviceName: 'Rewrite Tool History',
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
            TextField(
              controller: _inputController,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'Paste your text to rewrite in multiple tones...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: (Colors.grey[300] ?? Colors.grey)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: (Colors.grey[300] ?? Colors.grey)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFF7B2CBF), width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.all(20),
              ),
              style: const TextStyle(fontSize: 16, height: 1.5),
              onChanged: (_) => setState(() {}),
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
              children: _kRewriteQuickTopics.map((t) {
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
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7B2CBF).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _generateAllTones,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                          SizedBox(width: 12),
                          Text('Rewriting…'),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.text_fields, size: 20),
                          SizedBox(width: 8),
                          Text('Generate All Tones', style: TextStyle(fontSize: 16)),
                        ],
                      ),
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
                  messages: ['Reading your text…', 'Rewriting in 5 tones…', 'Polishing variations…'],
                  accentColor: Color(0xFF7B2CBF),
                ),
              ),
            ],

            if (_generatedRewrites != null && _generatedRewrites!.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Rewritten Versions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: (_generatedRewrites ?? {}).entries.map((entry) {
                    final isSelected = _selectedTone == entry.key;
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(_tones[entry.key] ?? entry.key),
                        onSelected: (selected) {
                          setState(() => _selectedTone = entry.key);
                        },
                        selectedColor: const Color(0xFF7B2CBF).withOpacity(0.2),
                        checkmarkColor: const Color(0xFF7B2CBF),
                        labelStyle: TextStyle(
                          color: isSelected ? const Color(0xFF7B2CBF) : Colors.grey[700],
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 16),

              if (_selectedTone != null && (_generatedRewrites ?? {}).containsKey(_selectedTone))
                Card(
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
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _tones[_selectedTone] ?? _selectedTone ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy),
                                onPressed: () => _copyToClipboard((_generatedRewrites ?? {})[_selectedTone] ?? ''),
                                color: const Color(0xFF7B2CBF),
                                tooltip: 'Copy',
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SelectableText(
                            (_generatedRewrites ?? {})[_selectedTone] ?? '',
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.6,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => _copyToClipboard((_generatedRewrites ?? {})[_selectedTone] ?? ''),
                              icon: const Icon(Icons.copy, size: 20),
                              label: const Text('Copy this tone'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF7B2CBF),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
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

import 'package:flutter/material.dart';
import '../widgets/ai_ad_banner.dart';
import '../services/api_service.dart';
import '../services/history_service.dart';
import '../services/shared_ai_content_store.dart';
import '../services/ai_usage_control_service.dart';
import '../models/shared_ai_content.dart';
import '../utils/ai_usage_guard.dart';
import '../widgets/ai_unified_components.dart';

class AIContentEngineScreen extends StatefulWidget {
  const AIContentEngineScreen({super.key});

  @override
  State<AIContentEngineScreen> createState() => _AIContentEngineScreenState();
}

class _AIContentEngineScreenState extends State<AIContentEngineScreen> {
  final _api = ApiService();
  final _history = HistoryService();
  final _nicheController = TextEditingController();
  bool _loading = false;
  String _goal = 'engagement';
  Map<String, dynamic>? _result;

  static const _goals = ['growth', 'sales', 'engagement'];
  static const _ideas = [
    AiSuggestionChip(label: 'SaaS', text: 'SaaS founders building Instagram brand'),
    AiSuggestionChip(label: 'Coach', text: 'Fitness coach personal brand'),
    AiSuggestionChip(label: 'Store', text: 'D2C skincare store in India'),
    AiSuggestionChip(label: 'Agency', text: 'Social media marketing agency'),
  ];

  SharedAiContent _toSharedContent(Map<String, dynamic> r) {
    return SharedAiContent(
      idea: (r['idea'] ?? '').toString(),
      hook: (r['hook'] ?? '').toString(),
      caption: (r['caption'] ?? '').toString(),
      hashtags: List.from(r['hashtags'] as List? ?? []).map((e) => e.toString()).toList(),
      script: List.from(r['script'] as List? ?? []).map((e) => e.toString()).toList(),
    );
  }

  @override
  void dispose() {
    _nicheController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_nicheController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter niche to generate content engine')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      // Guard enforces freemium (trial/premium unlimited, free 2/day) and shows
      // an interstitial ad after each output for non-premium users.
      final data = await runWithBackendAiGuard<Map<String, dynamic>>(
        context,
        service: AiUsageControlService.instance,
        onGenerate: () => _api.generateContentEngine(
          niche: _nicheController.text.trim(),
          goal: _goal,
        ),
      );
      if (data == null) {
        if (mounted) setState(() => _loading = false);
        return; // limit reached / not logged in — guard already handled the UI
      }
      if (!mounted) return;
      setState(() => _result = data);
      SharedAiContentStore.instance.setContent(_toSharedContent(data));
      final output = [
        'Idea: ${data['idea'] ?? ''}',
        'Hook: ${data['hook'] ?? ''}',
        'Caption: ${data['caption'] ?? ''}',
      ].join('\n\n');
      await _history.saveHistory(
        serviceType: 'content_engine',
        input: _nicheController.text.trim(),
        output: output,
        metadata: {'goal': _goal},
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _result = {
          'idea': 'Practical 3-post weekly plan for this niche.',
          'hook': 'Stop scrolling: copy this growth format.',
          'script': [
            'Call out audience pain point.',
            'Share 1 actionable framework.',
            'Give CTA for save/comment.',
          ],
          'caption': 'Simple repeatable framework to grow consistently. Save this.',
          'hashtags': ['#instagramgrowth', '#contentstrategy', '#reels'],
          'best_time': '7:30 PM',
          'score': {
            'overall': 74,
            'hook': 'Medium',
            'retention': 'Medium',
            'viral_chance': 'Medium',
          },
        };
      });
      SharedAiContentStore.instance.setContent(_toSharedContent(_result!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI is taking longer than usual, showing best available result'),
          backgroundColor: Color(0xFF7B2CBF),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copyAll() async {
    final r = _result;
    if (r == null) return;
    final script = List.from(r['script'] as List? ?? []).join('\n');
    final hashtags = List.from(r['hashtags'] as List? ?? []).join(' ');
    final text = 'Idea: ${r['idea']}\n\nHook: ${r['hook']}\n\nScript:\n$script\n\nCaption:\n${r['caption']}\n\nHashtags:\n$hashtags';
    await _history.saveHistory(
      serviceType: 'content_engine',
      input: _nicheController.text.trim(),
      output: text,
      metadata: {'goal': _goal, 'copy_all': true},
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied & saved to history'), backgroundColor: Color(0xFF7B2CBF)),
    );
  }

  void _useCaption() {
    final r = _result;
    if (r == null) return;
    SharedAiContentStore.instance.setContent(_toSharedContent(r));
    Navigator.pushNamed(context, '/schedule-post');
  }

  void _useScript() {
    final r = _result;
    if (r == null) return;
    SharedAiContentStore.instance.setContent(_toSharedContent(r));
    Navigator.pushNamed(context, '/reels-script-writer');
  }

  void _useHashtags() {
    final r = _result;
    if (r == null) return;
    SharedAiContentStore.instance.setContent(_toSharedContent(r));
    Navigator.pushNamed(context, '/hashtags');
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return Scaffold(
      bottomNavigationBar: const AiAdBanner(),
      appBar: AppBar(
        title: const Text('AI Content Engine'),
        backgroundColor: const Color(0xFF7B2CBF),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AiInputCard(
              controller: _nicheController,
              hintText: 'Enter niche (e.g. fitness coaches, D2C beauty, SaaS founders)',
              quickIdeas: _ideas,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: _goals.map((g) {
                return ChoiceChip(
                  label: Text(g),
                  selected: _goal == g,
                  onSelected: (_) => setState(() => _goal = g),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)]),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ElevatedButton(
                  onPressed: _loading ? null : _generate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('✨ Run AI Content Engine', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ),
            if (_loading) ...[
              const SizedBox(height: 16),
              const AiLoadingState(),
            ],
            if (r != null) ...[
              const SizedBox(height: 16),
              AiResultCard(
                title: 'Idea',
                mainResult: '${r['idea'] ?? ''}',
                actions: AiActionBar(
                  onCopy: _copyAll,
                  onRegenerate: _generate,
                  onShare: _useScript,
                ),
              ),
              const SizedBox(height: 12),
              AiResultCard(
                title: 'Hook',
                mainResult: '${r['hook'] ?? ''}',
                actions: AiActionBar(
                  onCopy: _copyAll,
                  onRegenerate: _generate,
                ),
              ),
              const SizedBox(height: 12),
              AiResultCard(
                title: 'Script',
                mainResult: List.from(r['script'] as List? ?? []).map((e) => e.toString()).join('\n'),
                actions: AiActionBar(
                  onCopy: _copyAll,
                  onSave: _copyAll,
                  onRegenerate: _generate,
                  onSchedule: _useScript,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _useScript,
                  icon: const Icon(Icons.movie_creation_outlined),
                  label: const Text('Use Script'),
                ),
              ),
              const SizedBox(height: 12),
              AiResultCard(
                title: 'Caption',
                mainResult: '${r['caption'] ?? ''}',
                actions: AiActionBar(
                  onCopy: _copyAll,
                  onSave: _copyAll,
                  onRegenerate: _generate,
                  onSchedule: _useCaption,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _useCaption,
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Use Caption'),
                ),
              ),
              const SizedBox(height: 12),
              AiResultCard(
                title: 'Hashtags',
                mainResult: List.from(r['hashtags'] as List? ?? []).join(' '),
                actions: AiActionBar(
                  onCopy: _copyAll,
                  onSave: _copyAll,
                  onRegenerate: _generate,
                  onSchedule: _useCaption,
                  onShare: _useHashtags,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _useHashtags,
                  icon: const Icon(Icons.tag_rounded),
                  label: const Text('Use Hashtags'),
                ),
              ),
              const SizedBox(height: 12),
              AiResultCard(
                title: 'Score',
                mainResult:
                    'Overall: ${(r['score']?['overall'] ?? 0)}\nHook: ${(r['score']?['hook'] ?? '-')}\nRetention: ${(r['score']?['retention'] ?? '-')}\nViral Chance: ${(r['score']?['viral_chance'] ?? '-')}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

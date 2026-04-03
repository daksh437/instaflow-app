import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/ai_usage_control_service.dart';
import '../services/history_service.dart';
import '../utils/ai_usage_guard.dart';
import '../widgets/ai_credit_badge.dart';
import 'history_screen.dart';

class NicheAnalysisScreen extends StatefulWidget {
  const NicheAnalysisScreen({super.key});

  @override
  State<NicheAnalysisScreen> createState() => _NicheAnalysisScreenState();
}

class _NicheAnalysisScreenState extends State<NicheAnalysisScreen> {
  final _topicController = TextEditingController();
  final _api = ApiService();
  final HistoryService _historyService = HistoryService();
  Map<String, dynamic> _analysis = {};
  bool _isAnalyzing = false;
  String _loadingMessage = 'Analyzing niche...';

  @override
  void initState() {
    super.initState();
    AiUsageControlService.instance.refresh();
  }

  Future<void> _analyzeNiche() async {
    if (_topicController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a niche/topic'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final result = await runWithBackendAiGuard<Map<String, dynamic>>(
        context,
        onGenerate: () async {
          setState(() {
            _isAnalyzing = true;
            _loadingMessage = 'Analyzing niche...';
          });
          try {
            final analysis = await _api.analyzeNiche(
              _topicController.text.trim(),
              onRetry: (message) {
                if (mounted) setState(() => _loadingMessage = message);
              },
            );
            await AiUsageControlService.instance.refresh();
            if (!mounted) return analysis;
            setState(() {
              _analysis = analysis;
              _isAnalyzing = false;
            });
            if (analysis.isNotEmpty) {
              final analysisOutput = '30-Day Trend Forecast: ${analysis['trend_forecast_30_days'] ?? ''}\n\nViral Patterns: ${analysis['top_5_viral_patterns'] ?? ''}\n\nReel Formats: ${analysis['best_3_reel_formats'] ?? ''}\n\nHashtag Clusters: ${analysis['hashtag_clusters'] ?? ''}\n\nUntapped Ideas: ${analysis['untapped_content_ideas'] ?? ''}\n\nPsychological Triggers: ${analysis['psychological_triggers'] ?? ''}\n\nCommon Mistakes: ${analysis['common_mistakes'] ?? ''}';
              await _historyService.saveHistory(
                serviceType: 'niche_analysis',
                input: _topicController.text.trim(),
                output: analysisOutput,
                metadata: {'has_data': analysis.isNotEmpty},
              );
            }
            return analysis;
          } catch (e) {
            setState(() => _isAnalyzing = false);
            rethrow;
          }
        },
        service: AiUsageControlService.instance,
      );
      if (result == null && mounted) setState(() => _isAnalyzing = false);
    } catch (e) {
      _handleError(e);
    }
  }

  void _handleError(Object e) {
    if (!mounted) return;
    setState(() => _isAnalyzing = false);
    String errorMessage = 'AI service not responding. Please check your connection and try again.';
    if (e.toString().contains('CONNECTION_ERROR')) {
      errorMessage = 'Cannot connect to backend. Make sure server is running.';
    } else if (e.toString().contains('TIMEOUT_ERROR')) {
      errorMessage = 'Request timed out. Please try again.';
    } else if (e.toString().contains('Invalid JSON')) {
      errorMessage = 'Invalid response from server. Please try again.';
    } else if (e.toString().contains('AI generation failed')) {
      errorMessage = 'AI generation failed. Please try again.';
    } else if (!e.toString().contains('DailyLimitReached')) {
      errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('Error: ', '');
    }
    if (!e.toString().contains('DailyLimitReached')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
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
                      'How to Use Niche Analysis',
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
                      title: 'What is Niche Analysis?',
                      content:
                          'Niche Analysis provides deep insights into your Instagram niche, including trending patterns, viral content formats, hashtag strategies, and psychological triggers. It helps you understand what works in your niche, identify opportunities, and avoid common mistakes. Perfect for creators who want to make data-driven content decisions.',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.edit_note,
                      iconColor: const Color(0xFF7B2CBF),
                      title: 'Step 1: Enter Your Niche',
                      content:
                          'Type your niche or topic in the text field. Examples:\n\n• Fitness and wellness\n• Travel and adventure\n• Food and cooking\n• Technology and gadgets\n• Fashion and style\n• Business and entrepreneurship\n• Education and learning\n• Any niche you want to analyze\n\nBe specific for more accurate insights!',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.auto_awesome,
                      iconColor: Colors.green,
                      title: 'Step 2: Analyze Niche',
                      content:
                          'Click the "Analyze Niche" button. Our AI will generate:\n\n• **30-Day Trend Forecast:** What\'s trending and what will trend\n• **Top 5 Viral Patterns:** Most successful content patterns in your niche\n• **Best 3 Reel Formats:** Optimal Reel formats for maximum engagement\n• **Hashtag Clusters:** Low, mid, and high competition hashtags\n• **Untapped Content Ideas:** Fresh ideas that aren\'t oversaturated\n• **Psychological Triggers:** Emotional triggers that drive engagement\n• **Common Mistakes:** What to avoid in your niche\n\nAll insights are based on current trends and patterns!',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.trending_up,
                      iconColor: Colors.orange,
                      title: 'Step 3: Use the Insights',
                      content:
                          'Once analysis is complete:\n\n• Review trend forecasts to plan ahead\n• Implement viral patterns in your content\n• Use recommended Reel formats for better reach\n• Apply hashtag clusters strategically\n• Create content from untapped ideas\n• Leverage psychological triggers for engagement\n• Avoid common mistakes highlighted\n• Track which insights work best for you',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.lightbulb_outline,
                      iconColor: Colors.amber,
                      title: 'Pro Tips',
                      content:
                          '💡 **Best Practices:**\n\n• Run analysis monthly to stay updated with trends\n• Focus on untapped ideas for unique content\n• Mix viral patterns with your unique style\n• Use psychological triggers naturally\n• Test different Reel formats to see what works\n• Balance hashtag clusters (low, mid, high competition)\n• Learn from common mistakes to avoid pitfalls\n\n💡 **Analysis Components:**\n\n• **Trend Forecast:** Plan content around upcoming trends\n• **Viral Patterns:** Understand what makes content go viral\n• **Reel Formats:** Use proven formats for better performance\n• **Hashtag Clusters:** Optimize reach with strategic hashtags\n• **Untapped Ideas:** Stand out with fresh content angles\n• **Psychological Triggers:** Drive engagement through emotions\n• **Common Mistakes:** Avoid what others are doing wrong\n\n💡 **Implementation Tips:**\n\n• Start with one insight at a time\n• Track performance of different patterns\n• A/B test different formats and triggers\n• Monitor trend forecasts regularly\n• Combine multiple insights for maximum impact\n• Stay authentic while using data-driven strategies',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.psychology,
                      iconColor: Colors.purple,
                      title: 'How It Works',
                      content:
                          'Our AI Niche Analysis uses advanced artificial intelligence to:\n\n1. **Analyze Trends:** Studies current and upcoming trends in your niche\n2. **Identify Patterns:** Discovers viral content patterns that work\n3. **Format Analysis:** Determines best-performing content formats\n4. **Hashtag Research:** Categorizes hashtags by competition level\n5. **Opportunity Detection:** Finds untapped content opportunities\n6. **Psychology Insights:** Identifies emotional triggers that drive engagement\n7. **Mistake Analysis:** Highlights common pitfalls to avoid\n\nPowered by advanced AI technology that learns from successful Instagram content to provide insights that actually help you grow.',
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
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Niche Analysis'),
        backgroundColor: const Color(0xFF7B2CBF),
        foregroundColor: Colors.white,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
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
                    serviceType: 'niche_analysis',
                    serviceName: 'Niche Analysis History',
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF8F6FF),
              Colors.white,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: MediaQuery.of(context).padding.top + 20,
            bottom: 20,
          ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ValueListenableBuilder<AiAccessState?>(
                  valueListenable: AiUsageControlService.instance.state,
                  builder: (_, state, __) => AiFreeLimitBanner(state: state, onUpgrade: () => Navigator.pushNamed(context, '/premium')),
                ),
                // Input Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7B2CBF).withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _topicController,
                        decoration: InputDecoration(
                          labelText: 'Niche/Topic',
                          hintText: 'e.g., Fitness, Travel, Food, Tech',
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF7B2CBF)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF7B2CBF), width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: (_isAnalyzing || (AiUsageControlService.instance.lastState != null && AiUsageControlService.instance.lastState!.isFree && AiUsageControlService.instance.lastState!.isLimitReached)) ? null : _analyzeNiche,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7B2CBF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isAnalyzing
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _loadingMessage,
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              )
                            : const Text(
                                'Analyze Niche',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Results Section
                if (_analysis.isNotEmpty) ...[
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
                              final analysisOutput = 'Trend Forecast: ${_analysis['trend_forecast_30_days'] ?? ''}\n\nViral Patterns: ${_analysis['top_5_viral_patterns'] ?? ''}\n\nReel Formats: ${_analysis['best_3_reel_formats'] ?? ''}\n\nHashtag Clusters: ${_analysis['hashtag_clusters'] ?? ''}\n\nUntapped Ideas: ${_analysis['untapped_content_ideas'] ?? ''}\n\nPsychological Triggers: ${_analysis['psychological_triggers'] ?? ''}\n\nCommon Mistakes: ${_analysis['common_mistakes'] ?? ''}';
                              await _historyService.saveHistory(
                                serviceType: 'niche_analysis',
                                input: _topicController.text.trim(),
                                output: analysisOutput,
                                metadata: {'has_data': _analysis.isNotEmpty},
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
                  // Trend Forecast
                  if (_analysis['trend_forecast_30_days'] != null) ...[
                    _buildSectionCard('30-Day Trend Forecast', _analysis['trend_forecast_30_days']),
                    const SizedBox(height: 16),
                  ],
                  // Viral Patterns
                  if (_analysis['top_5_viral_patterns'] != null) ...[
                    _buildViralPatternsCard(_analysis['top_5_viral_patterns']),
                    const SizedBox(height: 16),
                  ],
                  // Reel Formats
                  if (_analysis['best_3_reel_formats'] != null) ...[
                    _buildReelFormatsCard(_analysis['best_3_reel_formats']),
                    const SizedBox(height: 16),
                  ],
                  // Hashtag Clusters
                  if (_analysis['hashtag_clusters'] != null) ...[
                    _buildHashtagClustersCard(_analysis['hashtag_clusters']),
                    const SizedBox(height: 16),
                  ],
                  // Untapped Ideas
                  if (_analysis['untapped_content_ideas'] != null) ...[
                    _buildListCard('Untapped Content Ideas', _analysis['untapped_content_ideas']),
                    const SizedBox(height: 16),
                  ],
                  // Psychological Triggers
                  if (_analysis['psychological_triggers'] != null) ...[
                    _buildTriggersCard(_analysis['psychological_triggers']),
                    const SizedBox(height: 16),
                  ],
                  // Common Mistakes
                  if (_analysis['common_mistakes'] != null) ...[
                    _buildMistakesCard(_analysis['common_mistakes']),
                  ],
                ],
              ],
            ),
          ),
        ),
    );
  }

  Widget _buildSectionCard(String title, dynamic content) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B2CBF).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7B2CBF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (content is Map)
            ...content.entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key.toString().replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7B2CBF),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          entry.value.toString(),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF1A1A1A),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ))
          else
            Text(
              content.toString(),
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1A1A1A),
                height: 1.5,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildViralPatternsCard(dynamic patterns) {
    if (patterns == null || !(patterns is List)) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B2CBF).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Top 5 Viral Patterns',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7B2CBF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...(patterns as List).asMap().entries.map((entry) {
            final pattern = entry.value;
            final index = entry.key + 1;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF7B2CBF).withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF7B2CBF).withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '#$index',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (pattern is Map && pattern['pattern'] != null)
                        Expanded(
                          child: Text(
                            pattern['pattern'].toString(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (pattern is Map) ...[
                    if (pattern['reason'] != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        pattern['reason'].toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildReelFormatsCard(dynamic formats) {
    if (formats == null || !(formats is List)) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B2CBF).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Best 3 Reel Formats',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7B2CBF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...(formats as List).asMap().entries.map((entry) {
            final format = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF7B2CBF).withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF7B2CBF).withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (format is Map && format['format'] != null) ...[
                    Text(
                      format['format'].toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7B2CBF),
                      ),
                    ),
                    if (format['description'] != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        format['description'].toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                    if (format['expected_performance'] != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.trending_up, size: 14, color: Colors.green),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                format['expected_performance'].toString(),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green[800],
                                  fontWeight: FontWeight.w500,
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
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHashtagClustersCard(dynamic clusters) {
    if (clusters == null || !(clusters is Map)) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B2CBF).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Hashtag Clusters',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7B2CBF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (clusters['low_competition'] != null) ...[
            _buildHashtagSection('Low Competition', clusters['low_competition'], Colors.green),
            const SizedBox(height: 12),
          ],
          if (clusters['mid_competition'] != null) ...[
            _buildHashtagSection('Mid Competition', clusters['mid_competition'], Colors.orange),
            const SizedBox(height: 12),
          ],
          if (clusters['high_competition'] != null) ...[
            _buildHashtagSection('High Competition', clusters['high_competition'], Colors.red),
          ],
        ],
      ),
    );
  }

  Widget _buildHashtagSection(String title, dynamic tags, MaterialColor color) {
    if (tags == null || !(tags is List)) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color[800],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: (tags as List).map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: color.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  tag.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    color: color[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )).toList(),
        ),
      ],
    );
  }

  Widget _buildListCard(String title, dynamic items) {
    if (items == null || !(items is List)) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B2CBF).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7B2CBF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...(items as List).map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 16, color: Color(0xFF7B2CBF)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.toString(),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildTriggersCard(dynamic triggers) {
    if (triggers == null || !(triggers is List)) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B2CBF).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Psychological Triggers',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7B2CBF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...(triggers as List).map((trigger) {
            if (trigger is! Map) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF7B2CBF).withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF7B2CBF).withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (trigger['trigger'] != null) ...[
                    Text(
                      trigger['trigger'].toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7B2CBF),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (trigger['application'] != null) ...[
                    Text(
                      'How to use: ${trigger['application']}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (trigger['effectiveness'] != null) ...[
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        trigger['effectiveness'].toString(),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMistakesCard(dynamic mistakes) {
    if (mistakes == null || !(mistakes is List)) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.red, Colors.orange],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Common Mistakes to Avoid',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...(mistakes as List).map((mistake) {
            if (mistake is! Map) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (mistake['mistake'] != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.warning, size: 16, color: Colors.red),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            mistake['mistake'].toString(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (mistake['impact'] != null) ...[
                    Text(
                      'Impact: ${mistake['impact']}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (mistake['solution'] != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle, size: 14, color: Colors.green),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Solution: ${mistake['solution']}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green[800],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}


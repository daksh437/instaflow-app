import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/history_service.dart';
import '../services/ai_usage_control_service.dart';
import '../utils/ai_usage_guard.dart';
import '../widgets/ai_credit_badge.dart';
import '../widgets/ai_plan_countdown.dart';
import 'history_screen.dart';

class AIStrategyScreen extends StatefulWidget {
  const AIStrategyScreen({super.key});

  @override
  State<AIStrategyScreen> createState() => _AIStrategyScreenState();
}

class _AIStrategyScreenState extends State<AIStrategyScreen> {
  final _nicheController = TextEditingController();
  final _api = ApiService();
  final HistoryService _historyService = HistoryService();
  Map<String, dynamic> _strategy = {};
  bool _isGenerating = false;
  String _loadingMessage = 'Generating strategy...';

  @override
  void initState() {
    super.initState();
    AiUsageControlService.instance.refresh();
  }

  Future<void> _generateStrategy() async {
    if (_nicheController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a niche'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _loadingMessage = 'Generating strategy...'; // Reset loading message
    });
    try {
      final strategy = await runWithBackendAiGuard<Map<String, dynamic>>(
        context,
        service: AiUsageControlService.instance,
        onGenerate: () async {
          return await _api.generateStrategy(
            _nicheController.text.trim(),
            onRetry: (message) {
              if (mounted) {
                setState(() {
                  _loadingMessage = message; // "Waking up AI server..."
                });
              }
            },
          );
        },
      );
      if (strategy == null || !mounted) {
        setState(() => _isGenerating = false);
        return;
      }

      setState(() {
        _strategy = strategy;
        _isGenerating = false; // Stop loading on success
      });

      // Save to history
      if (strategy.isNotEmpty) {
        final strategyOutput = strategy.entries.map((e) => '${e.key}: ${e.value}').join('\n\n');
        await _historyService.saveHistory(
          serviceType: 'ai_strategy',
          input: _nicheController.text.trim(),
          output: strategyOutput,
          metadata: {'has_data': strategy.isNotEmpty},
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[AI Strategy] ERROR: ${e.toString()}');
      
      if (!mounted) return;
      
      // CRITICAL: Always stop loading in catch block
      setState(() => _isGenerating = false);
      
      String errorMessage = 'AI service not responding. Please check your connection and try again.';
      
      if (e.toString().contains('CONNECTION_ERROR')) {
        errorMessage = 'Cannot connect to backend. Make sure server is running.';
      } else if (e.toString().contains('TIMEOUT_ERROR')) {
        errorMessage = 'Request timed out. Please try again.';
      } else if (e.toString().contains('Invalid JSON')) {
        errorMessage = 'Invalid response from server. Please try again.';
      } else if (e.toString().contains('AI generation failed')) {
        errorMessage = 'AI generation failed. Please try again.';
      } else {
        errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('Error: ', '');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      // CRITICAL: Ensure loading is ALWAYS turned off, even if something unexpected happens
      if (mounted && _isGenerating) {
        if (kDebugMode) debugPrint('[AI Strategy] WARNING: Loading still active in finally block - forcing stop');
        setState(() => _isGenerating = false);
      }
    }
  }

  Widget _buildStrategyCard(String title, dynamic content) {
    if (content == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                        if (entry.value is List)
                          ...(entry.value as List).map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 4, left: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.circle, size: 6, color: Color(0xFF7B2CBF)),
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
                              ))
                        else
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
            else if (content is List)
              ...content.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.circle, size: 6, color: Color(0xFF7B2CBF)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.toString(),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF1A1A1A),
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
      ),
    );
  }

  Widget _buildViralIdeasCard(dynamic ideas) {
    if (ideas == null || !(ideas is List)) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                  '10 Viral Content Ideas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7B2CBF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...(ideas as List).asMap().entries.map((entry) {
              final idea = entry.value;
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
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (idea is Map) ...[
                      if (idea['hook'] != null) ...[
                        Row(
                          children: [
                            const Icon(Icons.bolt, size: 14, color: Color(0xFF7B2CBF)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                idea['hook'].toString(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF7B2CBF),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      if (idea['angle'] != null) ...[
                        Text(
                          'Angle: ${idea['angle']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (idea['expected_engagement_reason'] != null) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.trending_up, size: 14, color: Colors.green),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Why it works: ${idea['expected_engagement_reason']}',
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
                    ] else
                      Text(
                        idea.toString(),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildHashtagStrategyCard(dynamic hashtagStrategy) {
    if (hashtagStrategy == null || !(hashtagStrategy is Map)) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                  'Hashtag Strategy',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7B2CBF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (hashtagStrategy['low_competition_tags'] != null) ...[
              _buildHashtagSection('Low Competition (10)', hashtagStrategy['low_competition_tags'], Colors.green),
              const SizedBox(height: 12),
            ],
            if (hashtagStrategy['mid_competition_tags'] != null) ...[
              _buildHashtagSection('Mid Competition (10)', hashtagStrategy['mid_competition_tags'], Colors.orange),
              const SizedBox(height: 12),
            ],
            if (hashtagStrategy['high_competition_tags'] != null) ...[
              _buildHashtagSection('High Competition (10)', hashtagStrategy['high_competition_tags'], Colors.red),
            ],
          ],
        ),
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
                      'How to Use AI Growth Strategy',
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
                      title: 'What is AI Growth Strategy?',
                      content:
                          'AI Growth Strategy helps you create a comprehensive, data-driven growth plan for your Instagram account. It analyzes your niche and generates actionable strategies including audience insights, content ideas, hashtag strategies, and engagement tactics. Perfect for creators and businesses who want to grow their Instagram presence systematically.',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.edit_note,
                      iconColor: const Color(0xFF7B2CBF),
                      title: 'Step 1: Enter Your Niche',
                      content:
                          'Type your niche or industry in the text field. Examples:\n\n• Fitness and wellness\n• Travel and lifestyle\n• Food and recipes\n• Business and entrepreneurship\n• Fashion and beauty\n• Technology and gadgets\n• Education and learning\n• Any niche you want to grow in\n\nBe specific for more targeted strategies!',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.auto_awesome,
                      iconColor: Colors.green,
                      title: 'Step 2: Generate Strategy',
                      content:
                          'Click the "Generate Strategy" button. Our AI will create:\n\n• **Audience Profile:** Detailed analysis of your target audience\n• **Growth Plan:** Step-by-step growth strategies\n• **Viral Content Ideas:** 10 high-potential content ideas with hooks and angles\n• **Analytics Insights:** Key metrics to track and optimize\n• **Hashtag Strategy:** Low, mid, and high competition hashtags\n• **CTA Strategy:** Effective call-to-action techniques\n\nAll strategies are tailored to your niche!',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.trending_up,
                      iconColor: Colors.orange,
                      title: 'Step 3: Review & Implement',
                      content:
                          'Once your strategy is generated:\n\n• Review each section carefully\n• Understand your target audience profile\n• Implement the growth plan step by step\n• Use viral content ideas for your posts\n• Apply hashtag strategy to maximize reach\n• Track analytics insights regularly\n• Test different CTAs to see what works\n• Adjust strategy based on results',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.lightbulb_outline,
                      iconColor: Colors.amber,
                      title: 'Pro Tips',
                      content:
                          '💡 **Best Practices:**\n\n• Generate a new strategy monthly to stay updated\n• Focus on one growth tactic at a time\n• Track your progress using the analytics insights\n• Test viral content ideas and see what resonates\n• Mix low and high competition hashtags\n• Use A/B testing for different CTAs\n• Engage with your audience based on the profile\n\n💡 **Strategy Components:**\n\n• **Audience Profile:** Who your content should target\n• **Growth Plan:** Actionable steps to grow your account\n• **Viral Ideas:** Content ideas with hooks and engagement reasons\n• **Hashtag Strategy:** Optimized hashtag mix for reach\n• **CTA Strategy:** Ways to drive engagement and actions\n• **Analytics Insights:** Metrics that matter for growth\n\n💡 **Implementation Tips:**\n\n• Start with the easiest tactics first\n• Set realistic goals based on the growth plan\n• Create content calendar using viral ideas\n• Monitor hashtag performance and adjust\n• Track engagement rates and optimize\n• Be consistent with posting schedule',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.psychology,
                      iconColor: Colors.purple,
                      title: 'How It Works',
                      content:
                          'Our AI Growth Strategy uses advanced artificial intelligence to:\n\n1. **Analyze Niche:** Understands your industry, competition, and opportunities\n2. **Generate Strategies:** Creates comprehensive growth plans tailored to your niche\n3. **Content Ideas:** Provides viral-worthy content ideas with engagement angles\n4. **Hashtag Optimization:** Suggests optimal hashtag mix for maximum reach\n5. **Engagement Tactics:** Recommends CTAs and engagement strategies\n6. **Analytics Focus:** Identifies key metrics to track for growth\n\nPowered by advanced AI technology that learns from successful Instagram growth patterns to provide strategies that actually work.',
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
    _nicheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Growth Strategy'),
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
                    serviceType: 'ai_strategy',
                    serviceName: 'AI Growth Strategy History',
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
                        controller: _nicheController,
                        decoration: InputDecoration(
                          labelText: 'Niche',
                          hintText: 'e.g., Fitness, Travel, Food, Tech',
                          prefixIcon: const Icon(Icons.trending_up, color: Color(0xFF7B2CBF)),
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
                        onPressed: (_isGenerating || (AiUsageControlService.instance.lastState != null && AiUsageControlService.instance.lastState!.isFree && AiUsageControlService.instance.lastState!.isLimitReached)) ? null : _generateStrategy,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7B2CBF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isGenerating
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
                            : Text(
                                (AiUsageControlService.instance.lastState != null && AiUsageControlService.instance.lastState!.isFree && AiUsageControlService.instance.lastState!.isLimitReached)
                                    ? 'Upgrade to Premium'
                                    : 'Generate Strategy',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Results Section
                if (_strategy.isNotEmpty) ...[
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
                              final strategyOutput = _strategy.entries.map((e) => '${e.key}: ${e.value}').join('\n\n');
                              await _historyService.saveHistory(
                                serviceType: 'ai_strategy',
                                input: _nicheController.text.trim(),
                                output: strategyOutput,
                                metadata: {'has_data': _strategy.isNotEmpty},
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
                  // Audience Profile
                  if (_strategy['audience_profile'] != null) ...[
                    _buildStrategyCard('Audience Profile', _strategy['audience_profile']),
                  ],
                  // Growth Plan
                  if (_strategy['growth_plan'] != null) ...[
                    _buildStrategyCard('Growth Plan', _strategy['growth_plan']),
                  ],
                  // Viral Content Ideas
                  if (_strategy['viral_content_ideas'] != null) ...[
                    _buildViralIdeasCard(_strategy['viral_content_ideas']),
                  ],
                  // Analytics Insights
                  if (_strategy['analytics_insights'] != null) ...[
                    _buildStrategyCard('Analytics Insights', _strategy['analytics_insights']),
                  ],
                  // Hashtag Strategy
                  if (_strategy['hashtag_strategy'] != null) ...[
                    _buildHashtagStrategyCard(_strategy['hashtag_strategy']),
                  ],
                  // CTA Strategy
                  if (_strategy['cta_strategy'] != null) ...[
                    _buildStrategyCard('CTA Strategy', _strategy['cta_strategy']),
                  ],
                  // Backward compatibility with old format
                  if (_strategy['overview'] != null) ...[
                    _buildStrategyCard('Overview', _strategy['overview']),
                  ],
                  if (_strategy['posting_cadence'] != null) ...[
                    _buildStrategyCard('Posting Cadence', _strategy['posting_cadence']),
                  ],
                  if (_strategy['post_ideas'] != null) ...[
                    _buildStrategyCard('Post Ideas', _strategy['post_ideas']),
                  ],
                  if (_strategy['target_audience'] != null) ...[
                    _buildStrategyCard('Target Audience', _strategy['target_audience']),
                  ],
                  if (_strategy['kpis'] != null) ...[
                    _buildStrategyCard('KPIs', _strategy['kpis']),
                  ],
                  if (_strategy['ab_tests'] != null) ...[
                    _buildStrategyCard('A/B Tests', _strategy['ab_tests']),
                  ],
                ],
              ],
            ),
          ),
        ),
    );
  }
}

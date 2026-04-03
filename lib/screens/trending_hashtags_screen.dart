import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ai_service.dart';
import '../services/ai_usage_control_service.dart';
import '../services/history_service.dart';
import '../utils/ai_usage_guard.dart';
import '../widgets/ai_credit_badge.dart';
import '../widgets/ai_plan_countdown.dart';
import 'history_screen.dart';

class TrendingHashtagsScreen extends StatefulWidget {
  const TrendingHashtagsScreen({super.key});

  @override
  State<TrendingHashtagsScreen> createState() => _TrendingHashtagsScreenState();
}

class _TrendingHashtagsScreenState extends State<TrendingHashtagsScreen> {
  final AIService _aiService = AIService();
  final HistoryService _historyService = HistoryService();
  List<String> _trendingHashtags = [];
  List<String> _trendingTopics = [];
  List<String> _trendingIdeas = [];
  final Map<String, List<String>> _nicheHashtags = {};
  String _selectedCategory = 'All';
  bool _isLoading = false;
  bool _hasLoaded = false;

  final List<String> _categories = ['All', 'Fashion', 'Food', 'Travel', 'Fitness', 'Beauty', 'Photography'];

  @override
  void initState() {
    super.initState();
    AiUsageControlService.instance.refresh();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadTrendsWithGuard();
    });
  }

  Future<void> _loadTrendsWithGuard() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final trends = await runWithBackendAiGuard<Map<String, dynamic>>(
        context,
        service: AiUsageControlService.instance,
        onGenerate: () => _aiService.generateTrends(
          niche: _selectedCategory == 'All' ? null : _selectedCategory,
          category: _selectedCategory,
        ),
      );
      if (trends == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      if (!mounted) return;
    if (kDebugMode) debugPrint('[TrendFinder] ✅ Received trends - hashtags: ${trends['hashtags'].length}, topics: ${trends['topics'].length}, ideas: ${trends['ideas'].length}');
    setState(() {
      _trendingHashtags = List<String>.from(trends['hashtags'] ?? []);
      _trendingTopics = List<String>.from(trends['topics'] ?? []);
      _trendingIdeas = List<String>.from(trends['ideas'] ?? []);
      if (_selectedCategory != 'All') {
        _nicheHashtags[_selectedCategory] = _trendingHashtags;
      }
      _isLoading = false;
      _hasLoaded = true;
    });

    if (_trendingHashtags.isNotEmpty || _trendingTopics.isNotEmpty || _trendingIdeas.isNotEmpty) {
      final output = 'Hashtags: ${_trendingHashtags.join(", ")}\n\nTopics: ${_trendingTopics.join(", ")}\n\nIdeas: ${_trendingIdeas.join(", ")}';
      await _historyService.saveHistory(
        serviceType: 'trending_hashtags',
        input: _selectedCategory,
        output: output,
        metadata: {
          'category': _selectedCategory,
          'hashtag_count': _trendingHashtags.length,
          'topic_count': _trendingTopics.length,
          'idea_count': _trendingIdeas.length,
        },
      );
    }
    } catch (e) {
      if (kDebugMode) debugPrint('[TrendFinder] ❌ Error loading trends: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading trends: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _refreshTrends() async {
    await _loadTrendsWithGuard();
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard!'),
        backgroundColor: Color(0xFF7B2CBF),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _copyAll() {
    final allTags = _trendingHashtags.join(' ');
    _copyToClipboard(allTags);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Trend Finder'),
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
                    serviceType: 'trending_hashtags',
                    serviceName: 'Trending Hashtags History',
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _refreshTrends,
            tooltip: 'Refresh Trends',
          ),
        ],
      ),
      body: Column(
        children: [
          ValueListenableBuilder<AiAccessState?>(
            valueListenable: AiUsageControlService.instance.state,
            builder: (_, state, __) => AiFreeLimitBanner(state: state, onUpgrade: () => Navigator.pushNamed(context, '/premium')),
          ),
          // Category Filter
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: ListView(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _CategoryChip(
                  label: 'All',
                  isSelected: _selectedCategory == 'All',
                  onTap: () => _onCategoryChanged('All'),
                ),
                ..._nicheHashtags.keys.map((category) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _CategoryChip(
                        label: category,
                        isSelected: _selectedCategory == category,
                        onTap: () => setState(() => _selectedCategory = category),
                      ),
                    )),
              ],
            ),
          ),

          // Content List
          Expanded(
            child: _isLoading && !_hasLoaded
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: Color(0xFF7B2CBF)),
                        const SizedBox(height: 16),
                        Text(
                          'Finding latest trends... ✨',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Trending Hashtags Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: const Text(
                                '🔥 Trending Hashtags',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_trendingHashtags.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: TextButton.icon(
                                  onPressed: _copyAll,
                                  icon: const Icon(Icons.copy_all, size: 16),
                                  label: const Text('Copy All', style: TextStyle(fontSize: 13)),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF7B2CBF),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Hashtag Bubbles
                        if (_trendingHashtags.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: Text(
                                'No trending hashtags found. Pull to refresh!',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: _trendingHashtags
                                .map((hashtag) => _HashtagBubble(
                                      hashtag: hashtag,
                                      onTap: () => _copyToClipboard(hashtag),
                                    ))
                                .toList(),
                          ),

                        // Trending Topics Section
                        if (_trendingTopics.isNotEmpty) ...[
                          const SizedBox(height: 32),
                          const Text(
                            '📈 Trending Topics',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ..._trendingTopics.map((topic) => Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: (Colors.grey[200] ?? Colors.grey)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.trending_up, color: Color(0xFF7B2CBF), size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        topic,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF1A1A1A),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        ],

                        // Content Ideas Section
                        if (_trendingIdeas.isNotEmpty) ...[
                          const SizedBox(height: 32),
                          const Text(
                            '💡 Content Ideas',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ..._trendingIdeas.map((idea) => Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: (Colors.grey[200] ?? Colors.grey)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.lightbulb_outline, color: Color(0xFF7B2CBF), size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        idea,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF1A1A1A),
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        ],

                        const SizedBox(height: 32),

                        // Tips Section
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
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF7B2CBF),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.lightbulb_outline,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Pro Tips',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const _TipItem(text: 'Use 10-15 hashtags per post for best results'),
                              const _TipItem(text: 'Mix popular and niche hashtags'),
                              const _TipItem(text: 'Update hashtags regularly for trending topics'),
                              const _TipItem(text: 'Research hashtags specific to your niche'),
                            ],
                          ),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onCategoryChanged(String category) {
    setState(() {
      _selectedCategory = category;
      _hasLoaded = false;
    });
    _loadTrendsWithGuard();
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
                      'How to Use Trend Finder',
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
                      icon: Icons.trending_up,
                      title: 'What is Trend Finder?',
                      content: 'Trend Finder uses advanced AI to discover what\'s currently trending on Instagram. It shows you real-time trending hashtags, topics, and content ideas that are popular right now.',
                    ),
                    
                    const SizedBox(height: 24),
                    
                    _GuideSection(
                      icon: Icons.category,
                      title: 'Step 1: Select a Category',
                      content: 'Choose a category that matches your niche:\n\n• All: General trending content across all niches\n• Fashion: Latest fashion trends and hashtags\n• Food: Trending food content and recipes\n• Travel: Popular travel destinations and tips\n• Fitness: Current fitness trends and workouts\n• Beauty: Latest beauty trends and tips\n• Photography: Trending photography styles',
                    ),
                    
                    const SizedBox(height: 24),
                    
                    _GuideSection(
                      icon: Icons.auto_awesome,
                      title: 'Step 2: View Trending Content',
                      content: 'Once you select a category, the AI automatically loads:\n\n✅ Trending Hashtags: Currently popular hashtags in your niche\n✅ Trending Topics: What people are talking about right now\n✅ Content Ideas: Fresh content ideas based on current trends\n\nAll content is generated using real AI based on current trends!',
                    ),
                    
                    const SizedBox(height: 24),
                    
                    _GuideSection(
                      icon: Icons.copy_all,
                      title: 'Step 3: Use the Trends',
                      content: 'You can:\n\n• Copy individual hashtags by tapping on them\n• Copy all hashtags at once using "Copy All" button\n• Use trending topics as inspiration for your posts\n• Implement content ideas in your Instagram strategy\n• Refresh to get the latest trends anytime',
                    ),
                    
                    const SizedBox(height: 24),
                    
                    _GuideSection(
                      icon: Icons.refresh,
                      title: 'Step 4: Refresh for Latest Trends',
                      content: 'Click the refresh button (↻) in the top-right corner to get the most up-to-date trends. The AI generates fresh content every time you refresh, so you always have the latest trending information.',
                    ),
                    
                    const SizedBox(height: 24),
                    
                    _GuideSection(
                      icon: Icons.tips_and_updates,
                      title: 'Pro Tips',
                      content: '💡 Refresh regularly to stay updated with latest trends\n💡 Use trending hashtags in your posts for better reach\n💡 Combine trending topics with your unique perspective\n💡 Mix trending and niche-specific hashtags\n💡 Use content ideas as inspiration, add your own twist\n💡 Track which trends work best for your audience',
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
                            'The AI analyzes current Instagram trends and social media culture to provide you with:\n\n• Real-time trending hashtags that are actually being used\n• Current topics that are engaging audiences\n• Fresh content ideas based on what\'s working now\n\nAll trends are generated fresh using advanced AI technology, so you get authentic, current information every time!',
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
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                )
              : null,
          color: isSelected ? null : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? null
              : Border.all(color: (Colors.grey[300] ?? Colors.grey)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _HashtagBubble extends StatelessWidget {
  const _HashtagBubble({
    required this.hashtag,
    required this.onTap,
  });

  final String hashtag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: const Color(0xFF7B2CBF).withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hashtag,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7B2CBF),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.copy,
              size: 14,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}

class _TipItem extends StatelessWidget {
  const _TipItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6, right: 12),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFF7B2CBF),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
          ),
        ],
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


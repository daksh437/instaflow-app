import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/history_service.dart';
import '../services/ai_usage_control_service.dart';
import '../utils/ai_usage_guard.dart';
import '../utils/premium_guard.dart';
import '../widgets/ai_credit_badge.dart';
import '../widgets/ai_plan_countdown.dart';
import '../widgets/ai_voice_play_button.dart';
import 'history_screen.dart';

class AICalendarScreen extends StatefulWidget {
  const AICalendarScreen({super.key});

  @override
  State<AICalendarScreen> createState() => _AICalendarScreenState();
}

class _AICalendarScreenState extends State<AICalendarScreen> {
  final _topicController = TextEditingController();
  final _api = ApiService();
  final HistoryService _historyService = HistoryService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<dynamic> _calendarItems = [];
  bool _isGenerating = false;
  String _loadingMessage = 'Generating calendar...';

  @override
  void initState() {
    super.initState();
    AiUsageControlService.instance.refresh();
  }

  Future<void> _generateCalendar() async {
    if (_topicController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a topic'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _loadingMessage = 'Generating calendar...'; // Reset loading message
    });
    try {
      final items = await runWithBackendAiGuard<List<dynamic>>(
        context,
        service: AiUsageControlService.instance,
        onGenerate: () async {
          return await _api.generateCalendar(
            _topicController.text.trim(),
            days: 7,
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
      if (items == null || !mounted) {
        setState(() => _isGenerating = false);
        return;
      }

      setState(() {
        _calendarItems = items;
        _isGenerating = false; // Stop loading on success
      });

      // Save to history
      if (items.isNotEmpty) {
        final calendarOutput = items.map((item) {
          return 'Day ${item['day'] ?? ''}: ${item['title'] ?? ''}\n${item['caption'] ?? ''}\nHashtags: ${item['hashtags']?.join(' ') ?? ''}';
        }).join('\n\n');
        await _historyService.saveHistory(
          serviceType: 'ai_calendar',
          input: _topicController.text.trim(),
          output: calendarOutput,
          metadata: {'days': items.length},
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[AI Calendar] ERROR: ${e.toString()}');
      
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
        if (kDebugMode) debugPrint('[AI Calendar] WARNING: Loading still active in finally block - forcing stop');
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _saveCalendar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login first to save calendar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_calendarItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No calendar to save. Generate a calendar first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Save to HistoryService for consistency
      final calendarOutput = _calendarItems.map((item) {
        final dayOfWeek = item['day_of_week']?.toString() ?? item['day']?.toString() ?? 'Day';
        final title = item['title']?.toString() ?? '';
        final caption = item['caption']?.toString() ?? '';
        final hashtags = (item['hashtag_set'] ?? item['hashtags'] ?? []).join(' ');
        return 'Day $dayOfWeek: $title\n$caption\nHashtags: $hashtags';
      }).join('\n\n');
      
      await _historyService.saveHistory(
        serviceType: 'ai_calendar',
        input: _topicController.text.trim(),
        output: calendarOutput,
        metadata: {'days': _calendarItems.length},
      );

      // Also save to calendar_history collection for legacy support
      await _firestore.collection('calendar_history').add({
        'userId': user.uid,
        'topic': _topicController.text.trim(),
        'calendarItems': _calendarItems,
        'createdAt': FieldValue.serverTimestamp(),
        'savedAt': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Calendar saved to history! ✨'),
          backgroundColor: Color(0xFF7B2CBF),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[AI Calendar] Error saving: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save calendar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showHistory(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login first to view history'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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
                children: [
                  const Text(
                    'Calendar History',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
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
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('calendar_history')
                    .where('userId', isEqualTo: user.uid)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (!snapshot.hasData || docs.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No saved calendars',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Generate and save a calendar to see it here',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final topic = data['topic'] ?? 'Untitled';
                      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                      final calendarItems = data['calendarItems'] as List? ?? [];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF7B2CBF),
                            child: const Icon(Icons.calendar_month, color: Colors.white),
                          ),
                          title: Text(
                            topic,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${calendarItems.length} days • ${createdAt != null ? DateFormat('MMM dd, yyyy • hh:mm a').format(createdAt) : 'Unknown date'}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.visibility, color: Color(0xFF7B2CBF)),
                                onPressed: () {
                                  Navigator.pop(context);
                                  setState(() {
                                    _topicController.text = topic;
                                    _calendarItems = calendarItems;
                                  });
                                },
                                tooltip: 'Load calendar',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteCalendarHistory(doc.id),
                                tooltip: 'Delete',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteCalendarHistory(String docId) async {
    try {
      await _firestore.collection('calendar_history').doc(docId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Calendar deleted from history'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _scheduleToCalendar(dynamic item) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final title = item['caption']?.toString() ?? 'InstaFlow Post';
      final description = item['content_brief']?.toString() ?? item['creative_brief']?.toString() ?? '';
      final bestTime = item['best_posting_time']?.toString() ?? item['best_time']?.toString() ?? '';

      // Parse best_time or use current time + 1 day
      DateTime startTime;
      if (bestTime.isNotEmpty) {
        // Try to parse time (e.g., "6 PM IST")
        startTime = DateTime.now().add(const Duration(days: 1));
        startTime = DateTime(startTime.year, startTime.month, startTime.day, 18, 0);
      } else {
        startTime = DateTime.now().add(const Duration(days: 1));
      }

      final endTime = startTime.add(const Duration(minutes: 30));

      final success = await _api.scheduleEvent(
        title: title,
        description: description.isNotEmpty ? description : 'Scheduled via InstaFlow',
        startDateTime: startTime.toUtc().toIso8601String(),
        endDateTime: endTime.toUtc().toIso8601String(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Added to Google Calendar!' : 'Failed to add to calendar'),
          backgroundColor: success ? const Color(0xFF7B2CBF) : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      // Don't show error if it's a connection/timeout issue (phone disconnected)
      if (e.toString().contains('CONNECTION_ERROR') || 
          e.toString().contains('TIMEOUT_ERROR')) {
        return; // Silently fail when phone is disconnected
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot schedule event: ${e.toString().replaceAll('Exception: ', '')}'),
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
                      'How to Use AI Calendar Generator',
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
                      title: 'What is AI Calendar Generator?',
                      content:
                          'AI Calendar Generator helps you create a complete 7-day content calendar for your Instagram account. It generates daily post ideas, captions, hashtags, and posting times based on your niche or topic. Perfect for creators who want to plan their content in advance and maintain consistency.',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.edit_note,
                      iconColor: const Color(0xFF7B2CBF),
                      title: 'Step 1: Enter Your Topic',
                      content:
                          'Type your niche or topic in the text field. Examples:\n\n• Fitness and workouts\n• Travel and adventures\n• Food and recipes\n• Business and entrepreneurship\n• Fashion and style\n• Beauty and skincare\n• Any niche you want to create content about\n\nBe specific for better results!',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.auto_awesome,
                      iconColor: Colors.green,
                      title: 'Step 2: Generate Calendar',
                      content:
                          'Click the "Generate 7-Day Calendar" button. Our AI will:\n\n• Create 7 unique post ideas (one for each day)\n• Generate captions for each post\n• Suggest relevant hashtags\n• Recommend best posting times\n• Include hooks and viral angles\n• Add CTAs (Call-to-Action) for engagement\n\nAll content is tailored to your niche!',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.calendar_month,
                      iconColor: Colors.orange,
                      title: 'Step 3: Review & Schedule',
                      content:
                          'Once your calendar is generated:\n\n• Review each day\'s content plan\n• Check captions, hashtags, and posting times\n• Use the calendar icon to add posts to Google Calendar\n• Plan your content creation schedule\n• Use the generated ideas as inspiration\n• Customize captions before posting',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.lightbulb_outline,
                      iconColor: Colors.amber,
                      title: 'Pro Tips',
                      content:
                          '💡 **Best Practices:**\n\n• Generate a new calendar each week for fresh ideas\n• Mix the AI suggestions with your own content\n• Use the recommended posting times for better engagement\n• Customize captions to match your voice\n• Save hashtag sets for reuse\n• Plan content creation in advance\n\n💡 **Calendar Features:**\n\n• **Daily Posts:** Unique content ideas for each day\n• **Captions:** Ready-to-use Instagram captions\n• **Hashtags:** Relevant hashtag sets for each post\n• **Posting Times:** Optimal times for maximum reach\n• **Hooks:** Attention-grabbing opening lines\n• **CTAs:** Engagement-focused call-to-actions\n\n💡 **Scheduling Tips:**\n\n• Add posts to Google Calendar for reminders\n• Batch create content on weekends\n• Schedule posts using Instagram\'s scheduling feature\n• Track which content performs best',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.psychology,
                      iconColor: Colors.purple,
                      title: 'How It Works',
                      content:
                          'Our AI Calendar Generator uses advanced artificial intelligence to:\n\n1. **Analyze Topic:** Understands your niche and content goals\n2. **Generate Ideas:** Creates 7 unique, engaging post ideas\n3. **Create Content:** Generates captions, hashtags, and CTAs for each post\n4. **Optimize Timing:** Suggests best posting times based on engagement patterns\n5. **Ensure Variety:** Provides diverse content types and angles\n\nPowered by advanced AI technology that learns from successful Instagram content strategies to provide calendars that actually work.',
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
        title: const Text('AI Calendar Generator'),
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
                    serviceType: 'ai_calendar',
                    serviceName: 'AI Calendar History',
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
            top: 20,
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
                          labelText: 'Topic',
                          hintText: 'e.g., Fitness, Travel, Food',
                          prefixIcon: const Icon(Icons.calendar_month, color: Color(0xFF7B2CBF)),
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
                        onPressed: (_isGenerating || (AiUsageControlService.instance.lastState != null && AiUsageControlService.instance.lastState!.isFree && AiUsageControlService.instance.lastState!.isLimitReached)) ? null : _generateCalendar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7B2CBF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isGenerating
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                (AiUsageControlService.instance.lastState != null && AiUsageControlService.instance.lastState!.isFree && AiUsageControlService.instance.lastState!.isLimitReached)
                                    ? 'Upgrade to Premium'
                                    : 'Generate 7-Day Calendar',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Results Section
                if (_calendarItems.isNotEmpty) ...[
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
                      const Expanded(
                        child: Text(
                          '7-Day Content Calendar',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.bookmark_add, color: Color(0xFF7B2CBF)),
                        onPressed: () => _saveCalendar(),
                        tooltip: 'Save to history',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._calendarItems.asMap().entries.map((entry) {
                    final item = entry.value as Map<String, dynamic>;
                    // Support both old and new field names
                    final dayOfWeek = item['day_of_week']?.toString() ?? item['day']?.toString() ?? 'Day';
                    final contentType = item['content_type']?.toString() ?? item['post_type']?.toString() ?? 'Post';
                    final hashtags = item['hashtag_set'] ?? item['hashtags'] ?? [];
                    final bestTime = item['best_posting_time']?.toString() ?? item['best_time']?.toString();
                    final hook = item['hook']?.toString();
                    final viralAngle = item['viral_angle']?.toString();
                    final cta = item['cta']?.toString();
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
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
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      dayOfWeek,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF7B2CBF).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      contentType.toUpperCase(),
                                      style: const TextStyle(
                                        color: Color(0xFF7B2CBF),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                AIVoicePlayButton(
                                  textToSpeak: (hook != null && hook.isNotEmpty ? '$hook. ' : '') + (item['caption']?.toString() ?? ''),
                                  cacheKey: 'cal_${entry.key}_${item['caption']?.hashCode ?? 0}',
                                  iconSize: 20,
                                  iconColor: const Color(0xFF7B2CBF),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.event, color: Color(0xFF7B2CBF)),
                                  onPressed: () => _scheduleToCalendar(item),
                                  tooltip: 'Add to Google Calendar',
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(8),
                                ),
                              ],
                            ),
                            if (hook != null && hook.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7B2CBF).withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFF7B2CBF).withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.bolt, size: 16, color: Color(0xFF7B2CBF)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        hook,
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
                              ),
                            ],
                            const SizedBox(height: 12),
                            Text(
                              item['caption']?.toString() ?? '',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            if (hashtags is List && hashtags.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: (hashtags as List)
                                    .map((tag) => Text(
                                          tag.toString(),
                                          style: const TextStyle(
                                            color: Color(0xFF7B2CBF),
                                            fontSize: 11,
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ],
                            if (bestTime != null && bestTime.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.access_time, size: 16, color: Color(0xFF7B2CBF)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Best time: $bestTime',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF7B2CBF),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (item['content_brief'] != null || item['creative_brief'] != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.lightbulb_outline, size: 16, color: Color(0xFF7B2CBF)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      item['content_brief']?.toString() ?? item['creative_brief']?.toString() ?? '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (viralAngle != null && viralAngle.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: (Colors.green[200] ?? Colors.green),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.trending_up, size: 16, color: Colors.green),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        viralAngle,
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
                            if (cta != null && cta.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7B2CBF).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.arrow_forward, size: 14, color: Color(0xFF7B2CBF)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        cta,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF7B2CBF),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
    );
  }
}

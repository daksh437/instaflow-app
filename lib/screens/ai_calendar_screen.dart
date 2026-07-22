import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../widgets/ai_ad_banner.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';
import '../services/history_service.dart';
import '../services/ai_usage_control_service.dart';
import '../services/google_cloud_tts_service.dart';
import '../services/speech_input_service.dart';
import '../services/retention_service.dart';
import '../services/analytics_event_service.dart';
import '../models/ai_advice_model.dart';
import '../utils/ai_usage_guard.dart';
import '../widgets/ai_credit_badge.dart';
import '../widgets/ai_voice_play_button.dart';
import '../widgets/ai_coach_card.dart';
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
  final SpeechInputService _speechInput = SpeechInputService.instance;
  final AnalyticsEventService _analytics = AnalyticsEventService();
  List<dynamic> _calendarItems = [];
  bool _isGenerating = false;
  bool _isListening = false;
  String _loadingMessage = 'Generating calendar...';
  AiAdviceModel? _advice;
  static const String _friendlyError = 'Something went wrong, try again';

  /// 7, 14, or 30 — sent to API (backend clamps 1–30).
  int _horizonDays = 7;
  /// Optional: Professional, Casual, Funny — null = backend default.
  String? _tone;
  /// Optional: engagement, followers, sales — null = backend default.
  String? _goal;

  @override
  void initState() {
    super.initState();
    AiUsageControlService.instance.refresh();
  }

  Future<void> _generateCalendar() async {
    if (_isListening) return;
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
      _calendarItems = []; // Prevent stale 7-day UI while new job is running
    });
    try {
      final items = await runWithBackendAiGuard<List<dynamic>>(
        context,
        service: AiUsageControlService.instance,
        onGenerate: () async {
          return await _api.generateCalendar(
            _topicController.text.trim(),
            days: _horizonDays,
            tone: _tone,
            goal: _goal,
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
        _advice = _extractAdvice(items);
      });
      if (_advice != null) {
        unawaited(_analytics.logAppEvent('ai_advice_rendered', {'tool': 'ai_calendar'}));
      } else {
        unawaited(_analytics.logAppEvent('ai_advice_fallback_used', {'tool': 'ai_calendar'}));
      }
      unawaited(
        RetentionService.instance.markToolUsed(
          tool: 'ai_calendar',
          inputSnippet: _topicController.text.trim(),
        ),
      );
      unawaited(RetentionService.instance.completeMissionTask('calendar_generate'));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Generated ${items.length} days'),
          backgroundColor: const Color(0xFF7B2CBF),
          duration: const Duration(seconds: 2),
        ),
      );

      // Save to history
      if (items.isNotEmpty) {
        final calendarOutput = items.map((item) {
          return 'Day ${item['day'] ?? ''}: ${item['title'] ?? ''}\n${item['caption'] ?? ''}\nHashtags: ${item['hashtags']?.join(' ') ?? ''}';
        }).join('\n\n');
        await _historyService.saveHistory(
          serviceType: 'ai_calendar',
          input: _topicController.text.trim(),
          output: calendarOutput,
          metadata: {
            'days': items.length,
            'horizonDays': _horizonDays,
            if (_tone != null) 'tone': _tone,
            if (_goal != null) 'goal': _goal,
          },
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
        metadata: {
          'days': _calendarItems.length,
          'horizonDays': _horizonDays,
          if (_tone != null) 'tone': _tone,
          if (_goal != null) 'goal': _goal,
        },
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

  Future<void> _saveAndOpenSchedule() async {
    await _saveCalendar();
    unawaited(_analytics.logAppEvent('workflow_saved_draft', {'tool': 'ai_calendar'}));
    unawaited(_analytics.logAppEvent('workflow_scheduled', {'tool': 'ai_calendar'}));
    if (!mounted) return;
    Navigator.pushNamed(context, '/schedule-post');
  }

  AiAdviceModel? _extractAdvice(List<dynamic> items) {
    if (items.isEmpty) return null;
    final first = items.first;
    if (first is Map && first['ai_advice'] is Map) {
      final raw = Map<String, dynamic>.from(first['ai_advice']);
      if (raw['_meta_regenerated'] == true) {
        unawaited(_analytics.logAppEvent('ai_advice_regenerated', {'tool': 'ai_calendar'}));
      }
      if (raw['_meta_low_confidence'] == true) {
        unawaited(_analytics.logAppEvent('ai_advice_low_confidence', {'tool': 'ai_calendar'}));
      }
      final model = AiAdviceModel.fromMap(raw);
      return model.isUsable ? model : null;
    }
    return null;
  }

  void _applyAdvice() {
    final advice = _advice;
    if (advice == null) return;
    if (advice.quickWin.toLowerCase().contains('engagement')) {
      setState(() => _goal = 'engagement');
    }
    if (advice.quickWin.toLowerCase().contains('professional')) {
      setState(() => _tone = 'Professional');
    }
    unawaited(_analytics.logAppEvent('ai_advice_applied', {'tool': 'ai_calendar'}));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Applied AI suggestion to calendar settings.')),
    );
  }

  String _hashtagsToString(dynamic hashtags) {
    if (hashtags is List) {
      return hashtags.map((e) => e.toString()).join(' ');
    }
    return hashtags?.toString() ?? '';
  }

  Future<void> _startVoiceInput() async {
    if (_isGenerating || _isListening) return;
    setState(() => _isListening = true);
    try {
      final transcript = await _speechInput.listenOnce();
      if (!mounted) return;
      if (transcript != null && transcript.isNotEmpty) {
        _topicController.text = transcript;
        _topicController.selection = TextSelection.collapsed(offset: transcript.length);
      }
    } on SpeechInputException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.orange),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(_friendlyError), backgroundColor: Colors.orange),
      );
    } finally {
      if (mounted) setState(() => _isListening = false);
    }
  }

  String _formatDayPlainText(Map<String, dynamic> item) {
    final day = item['day_of_week']?.toString() ?? item['day']?.toString() ?? 'Day';
    final title = item['title']?.toString();
    final hook = item['hook']?.toString();
    final cap = item['caption']?.toString() ?? '';
    final tags = _hashtagsToString(item['hashtag_set'] ?? item['hashtags']);
    final buffer = StringBuffer(day);
    if (title != null && title.isNotEmpty) buffer.writeln('\n$title');
    if (hook != null && hook.isNotEmpty) buffer.writeln('\n$hook');
    if (cap.isNotEmpty) buffer.writeln('\n$cap');
    if (tags.isNotEmpty) buffer.writeln('\n$tags');
    return buffer.toString().trim();
  }

  String _fullCalendarPlainText() {
    final topic = _topicController.text.trim();
    final header = StringBuffer('InstaFlow — Content calendar\nTopic: $topic\n$_horizonDays days\n---\n');
    for (final raw in _calendarItems) {
      final item = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
      header.writeln(_formatDayPlainText(item));
      header.writeln('');
    }
    return header.toString().trim();
  }

  Future<void> _copyDayToClipboard(Map<String, dynamic> item) async {
    await Clipboard.setData(ClipboardData(text: _formatDayPlainText(item)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard'), backgroundColor: Color(0xFF7B2CBF)),
    );
  }

  Future<void> _copyFullCalendar() async {
    await Clipboard.setData(ClipboardData(text: _fullCalendarPlainText()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Full calendar copied'), backgroundColor: Color(0xFF7B2CBF)),
    );
  }

  Future<void> _shareCalendar() async {
    await Share.share(_fullCalendarPlainText(), subject: 'Instagram content calendar — ${_topicController.text.trim()}');
  }

  // Google Calendar export needs Google OAuth verification (sensitive
  // `calendar` scope, blocked on Google's review) and the in-app scheduler is
  // still gated — so copy this day's plan to the clipboard for now, ready to
  // paste straight into Instagram or a reminder.
  Future<void> _scheduleToCalendar(dynamic item) async {
    if (!mounted) return;
    final text = _calendarItemToText(item);
    if (text.isEmpty) return;
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📋 Copied! Paste it into Instagram or your reminder'),
          backgroundColor: Color(0xFF7B2CBF),
        ),
      );
    } catch (_) {}
  }

  String _calendarItemToText(dynamic item) {
    if (item is Map) {
      final parts = <String>[];
      for (final key in ['day', 'date', 'title', 'idea', 'caption', 'content', 'hook', 'hashtags']) {
        final v = item[key];
        if (v != null && v.toString().trim().isNotEmpty) parts.add(v.toString().trim());
      }
      if (parts.isNotEmpty) return parts.join('\n');
    }
    return item?.toString() ?? '';
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
    _speechInput.stop();
    GoogleCloudTtsService.instance.stop();
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const AiAdBanner(),
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
                          suffixIcon: IconButton(
                            onPressed: (_isGenerating || _isListening) ? null : _startVoiceInput,
                            tooltip: _isListening ? 'Listening...' : 'Speak topic',
                            icon: Icon(
                              _isListening ? Icons.mic : Icons.mic_none_rounded,
                              color: _isListening ? const Color(0xFF9D4EDD) : const Color(0xFF7B2CBF),
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF7B2CBF), width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Length',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [7, 14, 30].map((d) {
                          final selected = _horizonDays == d;
                          return ChoiceChip(
                            label: Text('$d days'),
                            selected: selected,
                            onSelected: _isGenerating
                                ? null
                                : (_) => setState(() => _horizonDays = d),
                            selectedColor: const Color(0xFF7B2CBF).withOpacity(0.28),
                            labelStyle: TextStyle(
                              color: selected ? const Color(0xFF7B2CBF) : Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Tone',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('Auto'),
                            selected: _tone == null,
                            onSelected: _isGenerating ? null : (_) => setState(() => _tone = null),
                            selectedColor: const Color(0xFF7B2CBF).withOpacity(0.28),
                          ),
                          FilterChip(
                            label: const Text('Professional'),
                            selected: _tone == 'Professional',
                            onSelected: _isGenerating ? null : (_) => setState(() => _tone = 'Professional'),
                            selectedColor: const Color(0xFF7B2CBF).withOpacity(0.28),
                          ),
                          FilterChip(
                            label: const Text('Casual'),
                            selected: _tone == 'Casual',
                            onSelected: _isGenerating ? null : (_) => setState(() => _tone = 'Casual'),
                            selectedColor: const Color(0xFF7B2CBF).withOpacity(0.28),
                          ),
                          FilterChip(
                            label: const Text('Funny'),
                            selected: _tone == 'Funny',
                            onSelected: _isGenerating ? null : (_) => setState(() => _tone = 'Funny'),
                            selectedColor: const Color(0xFF7B2CBF).withOpacity(0.28),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Goal',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('Auto'),
                            selected: _goal == null,
                            onSelected: _isGenerating ? null : (_) => setState(() => _goal = null),
                            selectedColor: const Color(0xFF7B2CBF).withOpacity(0.28),
                          ),
                          FilterChip(
                            label: const Text('Engagement'),
                            selected: _goal == 'engagement',
                            onSelected: _isGenerating ? null : (_) => setState(() => _goal = 'engagement'),
                            selectedColor: const Color(0xFF7B2CBF).withOpacity(0.28),
                          ),
                          FilterChip(
                            label: const Text('Followers'),
                            selected: _goal == 'followers',
                            onSelected: _isGenerating ? null : (_) => setState(() => _goal = 'followers'),
                            selectedColor: const Color(0xFF7B2CBF).withOpacity(0.28),
                          ),
                          FilterChip(
                            label: const Text('Sales'),
                            selected: _goal == 'sales',
                            onSelected: _isGenerating ? null : (_) => setState(() => _goal = 'sales'),
                            selectedColor: const Color(0xFF7B2CBF).withOpacity(0.28),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: (_isGenerating || _isListening || (AiUsageControlService.instance.lastState != null && AiUsageControlService.instance.lastState!.isFree && AiUsageControlService.instance.lastState!.isLimitReached)) ? null : _generateCalendar,
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
                                    : 'Generate $_horizonDays-Day Calendar',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                      if (_isGenerating) ...[
                        const SizedBox(height: 12),
                        Text(
                          _loadingMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                      ],
                      if (_isListening) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Listening... speak now',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Results Section
                if (_calendarItems.isNotEmpty) ...[
                  if (_advice != null)
                    AiCoachCard(
                      advice: _advice!,
                      onApply: _applyAdvice,
                    ),
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
                      Expanded(
                        child: Text(
                          '$_horizonDays-Day Content Calendar (${_calendarItems.length} generated)',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_all_outlined, color: Color(0xFF7B2CBF)),
                        onPressed: _copyFullCalendar,
                        tooltip: 'Copy full calendar',
                      ),
                      IconButton(
                        icon: const Icon(Icons.share_outlined, color: Color(0xFF7B2CBF)),
                        onPressed: _shareCalendar,
                        tooltip: 'Share calendar',
                      ),
                      IconButton(
                        icon: const Icon(Icons.schedule_send_outlined, color: Color(0xFF7B2CBF)),
                        onPressed: _saveAndOpenSchedule,
                        tooltip: 'Save & schedule',
                      ),
                      AIVoicePlayButton(
                        textToSpeak: _fullCalendarPlainText(),
                        cacheKey: 'cal_full_${_fullCalendarPlainText().hashCode}',
                        iconSize: 20,
                        iconColor: const Color(0xFF7B2CBF),
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
                    final item = Map<String, dynamic>.from(entry.value as Map);
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
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, color: Color(0xFF7B2CBF)),
                                  onPressed: () => _copyDayToClipboard(item),
                                  tooltip: 'Copy day',
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(8),
                                ),
                                AIVoicePlayButton(
                                  textToSpeak: [
                                    if (hook != null && hook.isNotEmpty) hook,
                                    item['caption']?.toString() ?? '',
                                    if (_hashtagsToString(hashtags).isNotEmpty) 'Hashtags: ${_hashtagsToString(hashtags)}',
                                  ].where((e) => e.isNotEmpty).join('. '),
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
                                children: hashtags
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

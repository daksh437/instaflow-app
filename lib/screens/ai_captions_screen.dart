import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import '../services/ai_usage_control_service.dart';
import '../services/history_service.dart';
import '../utils/ai_usage_guard.dart';
import 'history_screen.dart';
import '../widgets/ai_credit_badge.dart';

class AICaptionsScreen extends StatefulWidget {
  const AICaptionsScreen({super.key});

  @override
  State<AICaptionsScreen> createState() => _AICaptionsScreenState();
}

class _AICaptionsScreenState extends State<AICaptionsScreen> {
  final _captionRequestController = TextEditingController();
  final _api = ApiService();
  final HistoryService _historyService = HistoryService();
  List<dynamic> _captions = [];
  bool _isGenerating = false;
  String _loadingMessage = 'Generating captions...';

  @override
  void initState() {
    super.initState();
    AiUsageControlService.instance.refresh();
  }

  Future<void> _generateCaptions({bool regenerate = false}) async {
    if (_captionRequestController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe what kind of caption you want'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final captionsResult = await runWithBackendAiGuard<List<dynamic>>(
      context,
      onGenerate: () async {
        final callTimestamp = DateTime.now().millisecondsSinceEpoch;
        final userInput = _captionRequestController.text.trim();
        if (kDebugMode) debugPrint('[AI Captions] 🎬 BUTTON PRESSED #$callTimestamp - regenerate=$regenerate');
        setState(() {
          _isGenerating = true;
          _loadingMessage = 'Creating your captions...';
          if (regenerate) _captions = [];
        });
        try {
          final captions = await _api.generateCaptions(
            userInput,
            regenerate: regenerate,
            onRetry: (status) {
              if (mounted) {
                setState(() {
                  if (status == 'done' || status == 'completed') _loadingMessage = 'Almost done...';
                  else _loadingMessage = 'Processing...';
                });
              }
            },
          );
          await AiUsageControlService.instance.refresh();
          if (!mounted) return captions;
          setState(() {
            _captions = captions;
            _isGenerating = false;
          });
          if (captions.isNotEmpty) {
            final captionsOutput = captions.map((c) => c.toString()).join('\n\n');
            await _historyService.saveHistory(
              serviceType: 'ai_captions',
              input: userInput,
              output: captionsOutput,
              metadata: {'count': captions.length},
            );
          }
          if (captions.isEmpty && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No captions generated. Please try again.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return captions;
        } catch (e) {
          setState(() => _isGenerating = false);
          rethrow;
        }
      },
      service: AiUsageControlService.instance,
    );

      if (captionsResult == null && mounted) setState(() => _isGenerating = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      String msg = 'AI service not responding. Please try again.';
      if (e.toString().contains('CONNECTION_ERROR')) msg = 'Cannot connect to backend.';
      else if (e.toString().contains('TIMEOUT_ERROR')) msg = 'Request timed out.';
      else if (!e.toString().contains('DailyLimitReached')) msg = e.toString().replaceAll('Exception: ', '');
      if (!e.toString().contains('DailyLimitReached')) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red, duration: const Duration(seconds: 5)));
      }
    }
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard!'),
        backgroundColor: Color(0xFF7B2CBF),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showHowToUseGuide() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 28,
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
                              'AI Caption – How to Use',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF7B2CBF)),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create perfect Instagram captions in 3 easy steps:',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF666666),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Step 1
                _buildGuideStep(
                  stepNumber: 'Step 1',
                  title: 'Enter Topic',
                  content: 'Write your post idea (e.g. Gym, Travel, Moon, Business mindset).\n\nClear topics give better captions.',
                ),
                const SizedBox(height: 20),
                
                // Step 2
                _buildGuideStep(
                  stepNumber: 'Step 2',
                  title: 'Choose Mood / Tone',
                  content: '• Funny → playful & light captions\n• Attitude → bold & confident captions\n• Aesthetic → soft & poetic captions\n• Motivational → inspiring captions\n• Romantic → emotional captions',
                ),
                const SizedBox(height: 20),
                
                // Step 3
                _buildGuideStep(
                  stepNumber: 'Step 3',
                  title: 'Select Audience',
                  content: '• Personal → casual diary-style captions\n• Creator → engagement focused (Save / Share)\n• Business → professional & value-driven',
                ),
                const SizedBox(height: 20),
                
                // Optional
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF7B2CBF).withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Optional:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7B2CBF),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Choose Language (English / Hinglish / Hindi)',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Generate Caption
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Generate Caption:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tap "Generate Caption" to get 5 unique captions with hashtags.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Regenerate
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9D4EDD).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF9D4EDD).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.refresh, color: Color(0xFF9D4EDD), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Regenerate:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF9D4EDD),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tap "Regenerate New Style" to get fresh captions every time.\n\nCaptions are never repeated.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuideStep({required String stepNumber, required String title, required String content}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF7B2CBF).withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B2CBF).withOpacity(0.05),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  stepNumber,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
              height: 1.5,
            ),
            softWrap: true,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _captionRequestController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Captions'),
        backgroundColor: const Color(0xFF7B2CBF),
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
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HistoryScreen(
                    serviceType: 'ai_captions',
                    serviceName: 'AI Captions History',
                  ),
                ),
              );
            },
            tooltip: 'History',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: _showHowToUseGuide,
            tooltip: 'How to Use',
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
                        controller: _captionRequestController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'Describe your caption',
                          hintText: 'e.g., "motivational caption for gym reel in English" or "funny food caption in Hindi"',
                          prefixIcon: const Icon(Icons.edit_note, color: Color(0xFF7B2CBF)),
                          filled: true,
                          fillColor: const Color(0xFFF8F6FF),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: const Color(0xFF7B2CBF).withOpacity(0.2)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF7B2CBF), width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          helperText: 'AI will understand tone, language, and audience automatically',
                          helperMaxLines: 2,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF7B2CBF).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: (_isGenerating || (AiUsageControlService.instance.lastState != null && AiUsageControlService.instance.lastState!.isFree && AiUsageControlService.instance.lastState!.isLimitReached)) ? null : _generateCaptions,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
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
                                        Flexible(
                                          child: Text(
                                            _loadingMessage,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      (AiUsageControlService.instance.lastState != null && AiUsageControlService.instance.lastState!.isFree && AiUsageControlService.instance.lastState!.isLimitReached)
                                          ? 'Upgrade to Premium'
                                          : 'Generate Captions',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                              ),
                            ),
                          ),
                          if (_captions.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF9D4EDD), Color(0xFF7B2CBF)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF9D4EDD).withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: (_isGenerating || (AiUsageControlService.instance.lastState != null && AiUsageControlService.instance.lastState!.isFree && AiUsageControlService.instance.lastState!.isLimitReached)) ? null : () => _generateCaptions(regenerate: true),
                                icon: const Icon(Icons.refresh, size: 20),
                                label: const Text('Regenerate'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Results Section
                if (_captions.isNotEmpty) ...[
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 28,
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
                          'Generated Captions',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _isGenerating ? null : () => _generateCaptions(regenerate: true),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('New Style'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9D4EDD),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._captions.asMap().entries.map((entry) {
                    final caption = entry.value;
                    String captionText = '';
                    List<String> hashtags = [];
                    String? style;

                    // Handle different caption formats
                    if (caption is Map) {
                      // Standard Map format: {text, style, hashtags}
                      captionText = caption['text']?.toString() ?? 
                                   caption['caption']?.toString() ?? 
                                   '';
                      style = caption['style']?.toString() ?? caption['angle']?.toString();
                      if (caption['hashtags'] != null) {
                        if (caption['hashtags'] is List) {
                          hashtags = List<String>.from(caption['hashtags']);
                        } else if (caption['hashtags'] is String) {
                          // Extract hashtags from string (e.g., "#tag1 #tag2")
                          hashtags = (caption['hashtags'] as String)
                              .split(' ')
                              .where((tag) => tag.startsWith('#'))
                              .toList();
                        }
                      }
                    } else if (caption is String) {
                      // Plain string format - extract text and hashtags
                      final captionStr = caption.toString();
                      
                      // Check if it's a JSON string that needs parsing
                      if (captionStr.trim().startsWith('{') || captionStr.trim().startsWith('[')) {
                        try {
                          final parsed = jsonDecode(captionStr);
                          if (parsed is Map) {
                            captionText = parsed['text']?.toString() ?? 
                                         parsed['caption']?.toString() ?? 
                                         '';
                            style = parsed['style']?.toString();
                            if (parsed['hashtags'] != null) {
                              if (parsed['hashtags'] is List) {
                                hashtags = List<String>.from(parsed['hashtags']);
                              }
                            }
                          } else if (parsed is List && parsed.isNotEmpty) {
                            // If it's a list, use first item
                            final firstItem = parsed[0];
                            if (firstItem is Map) {
                              captionText = firstItem['text']?.toString() ?? 
                                           firstItem['caption']?.toString() ?? 
                                           '';
                              style = firstItem['style']?.toString();
                              if (firstItem['hashtags'] != null) {
                                hashtags = List<String>.from(firstItem['hashtags']);
                              }
                            }
                          }
                        } catch (e) {
                          // JSON parsing failed, treat as plain text
                          captionText = captionStr;
                        }
                      } else {
                        // Plain text - extract hashtags
                        captionText = captionStr;
                        hashtags = captionStr
                            .split(' ')
                            .where((word) => word.startsWith('#'))
                            .toList();
                        // Remove hashtags from caption text
                        if (hashtags.isNotEmpty) {
                          for (final tag in hashtags) {
                            captionText = captionText.replaceAll(tag, '').trim();
                          }
                          captionText = captionText.replaceAll(RegExp(r'\s+'), ' ').trim();
                        }
                      }
                    } else {
                      // Fallback: convert to string
                      captionText = caption.toString();
                    }
                    
                    // Clean up caption text - remove bullet points, numbering, etc.
                    captionText = captionText
                        .replaceAll(RegExp(r'^[•\-*]\s*'), '') // Remove bullet points
                        .replaceAll(RegExp(r'^\d+[\.\)]\s*'), '') // Remove numbering
                        .trim();
                    
                    // Skip if caption is empty or too short
                    if (captionText.isEmpty || captionText.length < 5) {
                      return const SizedBox.shrink();
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF7B2CBF).withOpacity(0.1),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7B2CBF).withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header with style badge and copy button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (style != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      style.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  )
                                else
                                  const SizedBox.shrink(),
                                IconButton(
                                  icon: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF7B2CBF).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.copy,
                                      color: Color(0xFF7B2CBF),
                                      size: 18,
                                    ),
                                  ),
                                  onPressed: () => _copyToClipboard(
                                    hashtags.isNotEmpty
                                        ? '$captionText\n\n${hashtags.join(' ')}'
                                        : captionText,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            if (style != null) const SizedBox(height: 16),
                            // Caption text
                            Text(
                              captionText,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1A1A1A),
                                height: 1.5,
                                letterSpacing: 0.2,
                              ),
                            ),
                            // Hashtags section
                            if (hashtags.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F6FF),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF7B2CBF).withOpacity(0.1),
                                  ),
                                ),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: hashtags
                                      .map((tag) => Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: const Color(0xFF7B2CBF).withOpacity(0.2),
                                              ),
                                            ),
                                            child: Text(
                                              tag,
                                              style: const TextStyle(
                                                color: Color(0xFF7B2CBF),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ))
                                      .toList(),
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


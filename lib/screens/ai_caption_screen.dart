import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/ai_service.dart';
import '../services/history_service.dart';
import '../services/ad_service.dart';
import '../services/ai_usage_control_service.dart';
import '../models/user_model.dart';
import '../utils/clipboard_utils.dart';
import '../utils/ai_usage_guard.dart';
import '../utils/app_error_handler.dart';
import '../services/voice_service.dart';
import '../widgets/voice_play_button.dart';
import 'history_screen.dart';
import 'dart:io';

class AICaptionScreen extends StatefulWidget {
  const AICaptionScreen({super.key});

  @override
  State<AICaptionScreen> createState() => _AICaptionScreenState();
}

class _AICaptionScreenState extends State<AICaptionScreen> {
  final AIService _aiService = AIService();
  final HistoryService _historyService = HistoryService();
  final TextEditingController _keywordController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();

  File? _selectedImage;
  String? _detectedMood;
  String? _imageDescription;
  String _selectedStyle = 'trending';
  bool _isGenerating = false;
  bool _isAnalyzingImage = false;
  bool _isLoadingPlan = true;
  String? _generatedCaption;
  SubscriptionPlan _userPlan = SubscriptionPlan.free;

  final List<Map<String, String>> _styles = [
    {'value': 'trending', 'label': 'Trending', 'icon': '🔥'},
    {'value': 'funny', 'label': 'Funny', 'icon': '😂'},
    {'value': 'emotional', 'label': 'Emotional', 'icon': '💝'},
    {'value': 'short', 'label': 'Short', 'icon': '⚡'},
    {'value': 'marketing', 'label': 'Marketing', 'icon': '📈'},
    {'value': 'professional', 'label': 'Professional', 'icon': '💼'},
    {'value': 'casual', 'label': 'Casual', 'icon': '😎'},
    {'value': 'inspiring', 'label': 'Inspiring', 'icon': '✨'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserPlan();
    AiUsageControlService.instance.refresh(force: true);
  }

  Future<void> _loadUserPlan() async {
    try {
      await AiUsageControlService.instance.refresh(force: true);
      if (!mounted) return;
      final state = AiUsageControlService.instance.lastState;
      setState(() {
        _userPlan = (state != null && state.planType == 'premium') ? SubscriptionPlan.pro : SubscriptionPlan.free;
        _isLoadingPlan = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _userPlan = SubscriptionPlan.free;
        _isLoadingPlan = false;
      });
    }
  }

  Future<void> _pickImage() async {
    // Show options: Gallery or Camera
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF7B2CBF)),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF7B2CBF)),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(source: source);

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _detectedMood = null;
        _imageDescription = null;
        _generatedCaption = null;
      });
      _analyzeImage();
    }
  }

  Future<void> _analyzeImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isAnalyzingImage = true;
      _detectedMood = null;
    });

    try {
      // Detect mood and analyze image in parallel
      final results = await Future.wait([
        _aiService.detectMood(_selectedImage!.path),
        _aiService.analyzeImage(_selectedImage!.path),
      ]);

      setState(() {
        _detectedMood = results[0] as String;
        _imageDescription = results[1] as String;
        _isAnalyzingImage = false;
      });
    } catch (e) {
      setState(() {
        _isAnalyzingImage = false;
    });
    }
  }

  Future<void> _generateCaption() async {
    if (_selectedImage == null && _keywordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload a photo or enter keywords'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final caption = await runWithBackendAiGuard<String>(
      context,
      service: AiUsageControlService.instance,
      limitReachedMessage: 'Unlimited captions require a premium subscription. Upgrade now to unlock this feature!',
      onGenerate: () async {
        VoiceService().stop();
        setState(() => _isGenerating = true);
        try {
          final topic = _keywordController.text.trim();
          final result = await _aiService.generateCaption(
            topic: topic.isNotEmpty ? topic : null,
            imagePath: _selectedImage?.path,
            style: _selectedStyle,
            tone: _selectedStyle,
          );
          if (!mounted) return result;
          setState(() {
            _generatedCaption = result;
            _isGenerating = false;
          });
          if (result.isNotEmpty) {
            await _historyService.saveHistory(
              serviceType: 'ai_caption',
              input: topic.isNotEmpty ? topic : (_imageDescription ?? 'Image caption'),
              output: result,
              metadata: {'style': _selectedStyle},
            );
            AdService().showInterstitialAd();
            AdService().loadInterstitialAd();
          }
          return result;
        } catch (e) {
          setState(() => _isGenerating = false);
          if (!mounted) rethrow;
          AppErrorHandler.log('AICaptionGenerate', e);
          AppErrorHandler.show(context, e);
          rethrow;
        }
      },
    );
    if (caption == null && mounted) setState(() => _isGenerating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('AI Caption Generator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HistoryScreen(
                    serviceType: 'ai_caption',
                    serviceName: 'AI Caption History',
                  ),
                ),
              );
            },
            tooltip: 'History',
          ),
          if (_userPlan == SubscriptionPlan.free)
            IconButton(
              icon: const Icon(Icons.workspace_premium),
              onPressed: () => Navigator.pushNamed(context, '/subscription'),
              tooltip: 'Upgrade to Pro',
            ),
        ],
      ),
      body: _isLoadingPlan
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7B2CBF)))
          : ValueListenableBuilder<AiAccessState?>(
              valueListenable: AiUsageControlService.instance.state,
              builder: (context, aiState, _) {
                final blocked = aiState != null && aiState.isFree && aiState.isLimitReached;
                return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Picker Section
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _selectedImage != null 
                      ? const Color(0xFF7B2CBF).withOpacity(0.3)
                      : (Colors.grey[300] ?? Colors.grey),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                      height: 220,
                decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(18),
                        ),
                ),
                child: _selectedImage != null
                          ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(18),
                                  ),
                        child: Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                                    width: double.infinity,
                        ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.edit,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.add_photo_alternate,
                                    size: 40,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Upload Your Photo',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'AI will analyze and create captions',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  if (_selectedImage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(18),
                        ),
                      ),
                      child: Row(
                        children: [
                          if (_isAnalyzingImage) ...[
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF7B2CBF),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Analyzing image...',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF7B2CBF),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ] else if (_imageDescription != null) ...[
                            Icon(Icons.auto_awesome, 
                              size: 16, 
                              color: Colors.grey[700],
              ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _imageDescription!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          if (_detectedMood != null) ...[
                            const SizedBox(width: 8),
              Chip(
                              label: Text(
                                _detectedMood!,
                                style: const TextStyle(fontSize: 11),
                              ),
                              avatar: const Icon(Icons.mood, size: 16),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Style Selector
            const Text(
              'Select Caption Style:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _styles.map((style) {
                final isSelected = _selectedStyle == style['value'];
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedStyle = style['value'] ?? '');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                            )
                          : null,
                      color: isSelected ? null : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : (Colors.grey[300] ?? Colors.grey),
                        width: 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF7B2CBF).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          style['icon'] ?? '',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          style['label'] ?? '',
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[700],
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Keywords Input (Optional)
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: (Colors.grey[200] ?? Colors.grey)),
              ),
              child: TextField(
              controller: _keywordController,
                decoration: InputDecoration(
                  labelText: 'Additional Keywords (Optional)',
                  hintText: _selectedImage != null
                      ? 'Add extra context... e.g., travel, adventure'
                      : 'Enter keywords or description... e.g., travel, adventure, sunset',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  prefixIcon: Icon(Icons.tag, color: Colors.grey[600]),
                ),
                maxLines: 2,
              ),
            ),

            const SizedBox(height: 24),

            // Generate Button
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7B2CBF).withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: (_isGenerating || _isAnalyzingImage || blocked) ? null : _generateCaption,
              icon: _isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                    )
                    : const Icon(Icons.auto_awesome, color: Colors.white),
                label: Text(
                  _isGenerating
                      ? 'Generating Caption...'
                      : blocked
                          ? 'Upgrade to Premium'
                          : _selectedImage != null
                              ? 'Generate from Photo'
                              : 'Generate Caption',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ),
            ),

            if (_generatedCaption != null) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Generated Caption:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: (Colors.grey[300] ?? Colors.grey)),
                ),
                child: SelectableText(
                  _generatedCaption!,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _captionController.text = _generatedCaption!;
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () async {
                      try {
                        await _historyService.saveHistory(
                          serviceType: 'ai_caption',
                          input: _keywordController.text.trim().isNotEmpty 
                              ? _keywordController.text.trim() 
                              : (_imageDescription ?? 'Image caption'),
                          output: _generatedCaption!,
                          metadata: {'style': _selectedStyle},
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Saved to history! ✨'),
                            backgroundColor: Color(0xFF7B2CBF),
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        AppErrorHandler.log('AICaptionSaveHistory', e);
                        AppErrorHandler.show(context, e);
                      }
                    },
                    icon: const Icon(Icons.bookmark_add, color: Color(0xFF7B2CBF)),
                    tooltip: 'Save to history',
                  ),
                  VoicePlayButton(
                    textToSpeak: _generatedCaption ?? '',
                    iconSize: 22,
                    iconColor: const Color(0xFF7B2CBF),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ClipboardUtils.copyToClipboard(
                          _generatedCaption!,
                          context,
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
      },
    ),
  );
  }

  @override
  void dispose() {
    VoiceService().stop();
    _keywordController.dispose();
    _captionController.dispose();
    super.dispose();
  }
}


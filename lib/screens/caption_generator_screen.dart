import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ai_service.dart';
import '../services/history_service.dart';
import '../services/ai_usage_control_service.dart';
import '../utils/ai_usage_guard.dart';
import '../services/voice_service.dart';
import '../widgets/ai_credit_badge.dart';
import '../widgets/ai_plan_countdown.dart';
import '../widgets/ai_progressive_loading.dart';
import '../widgets/voice_play_button.dart';
import '../widgets/ai_voice_play_button.dart';
import 'history_screen.dart';
import 'dart:io';

class CaptionGeneratorScreen extends StatefulWidget {
  const CaptionGeneratorScreen({super.key});

  @override
  State<CaptionGeneratorScreen> createState() => _CaptionGeneratorScreenState();
}

class _CaptionGeneratorScreenState extends State<CaptionGeneratorScreen> {
  final TextEditingController _inputController = TextEditingController();
  final AIService _aiService = AIService();
  final HistoryService _historyService = HistoryService();
  File? _selectedImage;
  String? _imageDescription;
  bool _isGenerating = false;
  bool _isAnalyzingImage = false;
  List<Map<String, String>> _generatedCaptions = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    AiUsageControlService.instance.refresh();
  }

  Future<void> _pickImage() async {
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
        _imageDescription = null;
        _generatedCaptions = [];
      });
      _analyzeImage();
    }
  }

  Future<void> _analyzeImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isAnalyzingImage = true;
    });

    try {
      final description = await _aiService.analyzeImage(_selectedImage!.path);
      setState(() {
        _imageDescription = description;
        _isAnalyzingImage = false;
      });
    } catch (e) {
      setState(() {
        _isAnalyzingImage = false;
      });
    }
  }

  Future<void> _generateCaptions() async {
    // Allow generation if either image or keywords are provided
    if (_selectedImage == null && _inputController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload a photo or enter keywords'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }

    setState(() {
      VoiceService().stop();
      _isGenerating = true;
      _generatedCaptions = [];
      _selectedIndex = 0;
    });
    try {
      String topic = _inputController.text.trim();
      if (topic.isEmpty && _imageDescription != null) {
        topic = _imageDescription!;
      } else if (topic.isEmpty) {
        topic = 'content';
      }

      final styles = await runWithBackendAiGuard<Map<String, String>>(
        context,
        service: AiUsageControlService.instance,
        onGenerate: () async {
          return await _aiService.generateCaptionStyles(topic);
        },
      );
      if (styles == null || !mounted) {
        setState(() => _isGenerating = false);
        return;
      }

      setState(() {
        _generatedCaptions = styles.entries.map((e) => {
          'style': e.key[0].toUpperCase() + e.key.substring(1),
          'caption': e.value,
        }).toList();
        _isGenerating = false;
      });

      if (_generatedCaptions.isNotEmpty) {
        final allCaptions = _generatedCaptions.map((e) => '${e['style']}: ${e['caption']}').join('\n\n');
        await _historyService.saveHistory(
          serviceType: 'caption_generator',
          input: topic,
          output: allCaptions,
          metadata: {'styles': _generatedCaptions.map((e) => e['style']).toList()},
        );
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('unavailable')
                ? 'AI service is currently unavailable. Please try again later.'
                : 'Error generating captions. Please try again.',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard! ✨'),
        backgroundColor: Color(0xFF7B2CBF),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    VoiceService().stop();
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('AI Caption Generator'),
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
                    serviceType: 'caption_generator',
                    serviceName: 'Caption Generator History',
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
            ValueListenableBuilder<AiAccessState?>(
              valueListenable: AiUsageControlService.instance.state,
              builder: (_, state, __) => AiFreeLimitBanner(state: state, onUpgrade: () => Navigator.pushNamed(context, '/premium')),
            ),
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
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Input Section (Optional Keywords)
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: (Colors.grey[200] ?? Colors.grey)),
              ),
              child: TextField(
                controller: _inputController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: _selectedImage != null
                      ? 'Add extra context (optional)... e.g., travel, adventure'
                      : 'Enter your topic, keywords, or description...',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(20),
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: Icon(Icons.tag, color: Colors.grey[600]),
                ),
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),

            const SizedBox(height: 20),

            // Generate Button
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7B2CBF).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: (_isGenerating || (AiUsageControlService.instance.lastState != null && AiUsageControlService.instance.lastState!.isFree && AiUsageControlService.instance.lastState!.isLimitReached)) ? null : _generateCaptions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 18),
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
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Generating magic... ✨',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            (AiUsageControlService.instance.lastState != null && AiUsageControlService.instance.lastState!.isFree && AiUsageControlService.instance.lastState!.isLimitReached)
                                ? 'Upgrade to Premium'
                                : (_selectedImage != null ? 'Generate from Photo' : 'Generate Captions'),
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

            // Loading State - progressive text
            if (_isGenerating) ...[
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B2CBF).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const AiProgressiveLoading(
                  messages: ['Analyzing…', 'Generating captions…', 'Optimizing output…'],
                  accentColor: Color(0xFF7B2CBF),
                ),
              ),
            ],

            // Generated Captions
            if (_generatedCaptions.isNotEmpty) ...[
              const SizedBox(height: 32),
              const Text(
                'Generated Captions',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 16),

              // Style Selector
              SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: List.generate(
                    _generatedCaptions.length,
                    (index) => Padding(
                      padding: EdgeInsets.only(right: index < _generatedCaptions.length - 1 ? 12 : 0),
                      child: _StyleChip(
                        label: _generatedCaptions[index]['style'] ?? '',
                        isSelected: _selectedIndex == index,
                        onTap: () => setState(() => _selectedIndex = index),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Selected Caption Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: (Colors.grey[200] ?? Colors.grey)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _generatedCaptions[_selectedIndex]['style'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.bookmark_add),
                              onPressed: () async {
                                try {
                                  final allCaptions = _generatedCaptions.map((e) => '${e['style']}: ${e['caption']}').join('\n\n');
                                  final topic = _inputController.text.trim().isEmpty 
                                      ? (_imageDescription ?? 'content')
                                      : _inputController.text.trim();
                                  await _historyService.saveHistory(
                                    serviceType: 'caption_generator',
                                    input: topic,
                                    output: allCaptions,
                                    metadata: {'styles': _generatedCaptions.map((e) => e['style']).toList()},
                                  );
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Saved to history!'),
                                      backgroundColor: Color(0xFF7B2CBF),
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error saving: $e')),
                                  );
                                }
                              },
                              color: const Color(0xFF7B2CBF),
                              tooltip: 'Save to history',
                            ),
                            AIVoicePlayButton(
                              textToSpeak: _generatedCaptions[_selectedIndex]['caption'] ?? '',
                              iconSize: 22,
                              iconColor: const Color(0xFF7B2CBF),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded),
                              onPressed: () => _copyToClipboard(
                                _generatedCaptions[_selectedIndex]['caption'] ?? '',
                              ),
                              color: const Color(0xFF7B2CBF),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SelectableText(
                      _generatedCaptions[_selectedIndex]['caption'] ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: Color(0xFF1A1A1A),
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
  }
}

class _StyleChip extends StatelessWidget {
  const _StyleChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                )
              : null,
          color: isSelected ? null : Colors.grey[100],
          borderRadius: BorderRadius.circular(25),
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

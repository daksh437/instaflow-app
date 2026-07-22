import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../widgets/ai_ad_banner.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../services/api_service.dart';
import '../services/ai_usage_control_service.dart';
import '../utils/ai_usage_guard.dart';
import '../widgets/ai_credit_badge.dart';
import '../widgets/ai_plan_countdown.dart';

class AICaptionFromMediaScreen extends StatefulWidget {
  const AICaptionFromMediaScreen({super.key});

  @override
  State<AICaptionFromMediaScreen> createState() => _AICaptionFromMediaScreenState();
}

class _AICaptionFromMediaScreenState extends State<AICaptionFromMediaScreen> {
  final _api = ApiService();
  File? _selectedImage;
  Map<String, dynamic>? _analysis;
  List<dynamic> _captions = [];
  bool _isGenerating = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    AiUsageControlService.instance.refresh();
  }

  Future<void> _pickImage() async {
    try {
      // Allow images up to 10MB - backend will optimize
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        // Don't reduce size aggressively - backend will handle optimization
      );
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _analysis = null;
          _captions = [];
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _analysis = null;
      _captions = [];
    });
  }

  Future<String> _imageToBase64(File imageFile) async {
    // Read image file - backend will optimize, so send original
    final bytes = await imageFile.readAsBytes();
    
    // Check file size (10MB limit)
    final sizeMB = bytes.length / (1024 * 1024);
    if (sizeMB > 10) {
      throw Exception('Image too large. Please select an image smaller than 10MB.');
    }
    
    // Convert to base64 - backend will resize and optimize
    return base64Encode(bytes);
  }

  Future<void> _generateCaption() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload a photo or reel frame first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      // Convert image to base64 - backend will optimize to 384px
      final imageBase64 = await _imageToBase64(_selectedImage!);
      // Detect mime type from file extension
      final imageMimeType = _selectedImage!.path.toLowerCase().endsWith('.png') 
          ? 'image/png' 
          : 'image/jpeg';
      
      final sizeKB = (imageBase64.length / 1024).toStringAsFixed(1);
      if (kDebugMode) debugPrint('[AI Caption] Calling API with image size: $sizeKB KB (backend will optimize to 384px)');
      
      // Show progress message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Processing image... This may take 30-60 seconds.'),
            duration: Duration(seconds: 3),
            backgroundColor: Color(0xFF7B2CBF),
          ),
        );
      }

      final result = await runWithBackendAiGuard<Map<String, dynamic>>(
        context,
        service: AiUsageControlService.instance,
        onGenerate: () async {
          return await _api.generateCaptionFromMedia(imageBase64, imageMimeType);
        },
      );
      if (result == null || !mounted) {
        setState(() => _isGenerating = false);
        return;
      }
      if (kDebugMode) debugPrint('[AI Caption] API response received: ${result.keys}');

      setState(() {
        // Support both 'analysis' and 'image_analysis' for backward compatibility
        _analysis = (result['analysis'] ?? result['image_analysis']) as Map<String, dynamic>?;
        _captions = (result['captions'] ?? []) as List<dynamic>;
        _isGenerating = false;
      });
      
      if (kDebugMode) debugPrint('[AI Caption] Analysis: ${_analysis != null ? "Found" : "Null"}, Captions: ${_captions.length}');
      
      if (_captions.isEmpty && _analysis == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No captions generated. Please try again with a different image.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      if (!mounted) return;
      
      // Log error for debugging
      if (kDebugMode) debugPrint('[AI Caption Error] ${e.toString()}');
      
      String errorMessage;
      if (e.toString().contains('CONNECTION_ERROR')) {
        errorMessage = 'Cannot connect to backend. Make sure server is running at ${ApiService.baseUrl}';
      } else if (e.toString().contains('TIMEOUT_ERROR') || e.toString().contains('timeout')) {
        errorMessage = 'Image analysis is taking longer than expected. This may happen with large images. Please try:\n• Using a smaller image\n• Checking your internet connection\n• Trying again in a moment';
      } else if (e.toString().contains('Invalid JSON')) {
        errorMessage = 'Invalid response from server. Please try again.';
      } else if (e.toString().contains('Server error')) {
        errorMessage = 'Backend server error. Check server logs.';
      } else if (e.toString().contains('Failed to decode image')) {
        errorMessage = 'Invalid image format. Please select a valid image file.';
      } else {
        errorMessage = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ),
      );
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

  Widget _buildAnalysisRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF7B2CBF),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const AiAdBanner(),
      appBar: AppBar(
        title: const Text('AI Caption From Photo / Reel'),
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
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  state.dailyLimit != null ? '${state.remainingCredits} / ${state.dailyLimit}' : '${state.remainingCredits}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              );
            },
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
                // Upload Section
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
                      if (_selectedImage == null) ...[
                        GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            height: 200,
                            decoration: BoxDecoration(
                              color: const Color(0xFF7B2CBF).withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF7B2CBF).withOpacity(0.3),
                                width: 2,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.photo_library_rounded, 
                                  color: Color(0xFF7B2CBF), 
                                  size: 56,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Upload Photo or Reel Frame',
                                  style: TextStyle(
                                    color: Color(0xFF7B2CBF),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Tap to select from gallery',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _selectedImage!,
                                height: 250,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                ),
                                onPressed: _removeImage,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: (_isGenerating || _selectedImage == null || (AiUsageControlService.instance.lastState != null && AiUsageControlService.instance.lastState!.isFree && AiUsageControlService.instance.lastState!.isLimitReached)) ? null : _generateCaption,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7B2CBF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: Colors.grey[300],
                        ),
                        child: _isGenerating
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
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
                                  const Text(
                                    'Analyzing image and generating captions...',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              )
                            : Text(
                                (AiUsageControlService.instance.lastState != null && AiUsageControlService.instance.lastState!.isFree && AiUsageControlService.instance.lastState!.isLimitReached)
                                    ? 'Upgrade to Premium'
                                    : 'Generate AI Caption',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Analysis Section
                if (_analysis != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
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
                              'Media Analysis',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_analysis!['scene'] != null)
                          _buildAnalysisRow('Scene', _analysis!['scene'].toString()),
                        if (_analysis!['setting'] != null)
                          _buildAnalysisRow('Setting', _analysis!['setting'].toString()),
                        if (_analysis!['mood'] != null)
                          _buildAnalysisRow('Mood', _analysis!['mood'].toString()),
                        if (_analysis!['time'] != null)
                          _buildAnalysisRow('Time', _analysis!['time'].toString()),
                        if (_analysis!['occasion'] != null)
                          _buildAnalysisRow('Occasion', _analysis!['occasion'].toString()),
                        // Support old field names for backward compatibility
                        if (_analysis!['clothing'] != null && _analysis!['scene'] == null)
                          _buildAnalysisRow('Clothing', _analysis!['clothing'].toString()),
                        if (_analysis!['action'] != null && _analysis!['scene'] == null)
                          _buildAnalysisRow('Action', _analysis!['action'].toString()),
                        if (_analysis!['environment'] != null && _analysis!['setting'] == null)
                          _buildAnalysisRow('Environment', _analysis!['environment'].toString()),
                        if (_analysis!['context'] != null && _analysis!['occasion'] == null)
                          _buildAnalysisRow('Context', _analysis!['context'].toString()),
                        if (_analysis!['event_context'] != null && _analysis!['occasion'] == null)
                          _buildAnalysisRow('Context', _analysis!['event_context'].toString()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Captions Section
                if (_captions.isNotEmpty) ...[
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
                        'Generated Captions',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._captions.asMap().entries.map((entry) {
                    final caption = entry.value;
                    String captionText = '';
                    List<String> hashtags = [];

                    if (caption is Map) {
                      captionText = caption['text']?.toString() ?? 
                                   caption['caption']?.toString() ?? 
                                   caption.toString();
                      if (caption['hashtags'] != null) {
                        hashtags = List<String>.from(caption['hashtags']);
                      }
                    } else {
                      captionText = caption.toString();
                    }

                    final angle = caption is Map ? caption['angle']?.toString() : null;

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
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (angle != null && angle.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7B2CBF).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  angle.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF7B2CBF),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Text(
                              captionText,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ],
                        ),
                        subtitle: hashtags.isNotEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: hashtags
                                      .map(
                                        (tag) => Text(
                                          tag,
                                          style: const TextStyle(
                                            color: Color(0xFF7B2CBF),
                                            fontSize: 12,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              )
                            : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.copy, color: Color(0xFF7B2CBF)),
                          onPressed: () => _copyToClipboard(
                            hashtags.isNotEmpty
                                ? "$captionText\n\n${hashtags.join(' ')}"
                                : captionText,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}


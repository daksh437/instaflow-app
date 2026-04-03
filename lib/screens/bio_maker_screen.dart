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

class BioMakerScreen extends StatefulWidget {
  const BioMakerScreen({super.key});

  @override
  State<BioMakerScreen> createState() => _BioMakerScreenState();
}

class _BioMakerScreenState extends State<BioMakerScreen> {
  final TextEditingController _inputController = TextEditingController();
  final AIService _aiService = AIService();
  final HistoryService _historyService = HistoryService();
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    AiUsageControlService.instance.refresh();
  }
  Map<String, String> _bios = {};
  String? _selectedType;

  final Map<String, String> _bioTypes = {
    'short': 'Short & Punchy',
    'long': 'Detailed',
    'aesthetic': 'Aesthetic',
  };

  Future<void> _generateBios() async {
    if (_inputController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe yourself')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _bios = {};
      _selectedType = null;
    });

    try {
      final desc = _inputController.text.trim();
      final descPreview = desc.length > 50 ? '${desc.substring(0, 50)}...' : desc;
      if (kDebugMode) debugPrint('[BioMaker] 🚀 Starting bio generation for description: "$descPreview"');

      final bios = await runWithBackendAiGuard<List<String>>(
        context,
        service: AiUsageControlService.instance,
        onGenerate: () => Future.wait([
          _aiService.generateBio(desc, style: 'short'),
          _aiService.generateBio(desc, style: 'long'),
          _aiService.generateBio(desc, style: 'aesthetic'),
        ]),
      );
      if (bios == null) {
        setState(() => _isGenerating = false);
        return;
      }
      
      if (kDebugMode) debugPrint('[BioMaker] ✅ Received ${bios.length} bios');
      
      setState(() {
        _bios = {
          'short': bios[0],
          'long': bios[1],
          'aesthetic': bios[2],
        };
        _selectedType = _bios.keys.first;
        _isGenerating = false;
      });

      // Save to history
      if (_bios.isNotEmpty) {
        final allBios = _bios.entries.map((e) => '${e.key}: ${e.value}').join('\n\n');
        await _historyService.saveHistory(
          serviceType: 'bio_maker',
          input: desc,
          output: allBios,
          metadata: {'styles': _bios.keys.toList()},
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[BioMaker] ❌ Error: $e');
      setState(() => _isGenerating = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('unavailable') || e.toString().contains('Failed')
                ? 'AI service error: ${e.toString()}'
                : 'Error generating bio: ${e.toString()}',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bio copied!'),
        backgroundColor: Color(0xFF7B2CBF),
        duration: Duration(seconds: 1),
      ),
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
                      'How to Use Bio Maker',
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
                      title: 'What is Bio Maker?',
                      content:
                          'Bio Maker helps you create professional, engaging Instagram bios that capture your personality, brand, or business essence. Generate multiple bio styles (short, detailed, aesthetic) in one go, perfect for personal profiles, business accounts, or creators.',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.edit_note,
                      iconColor: const Color(0xFF7B2CBF),
                      title: 'Step 1: Describe Yourself',
                      content:
                          'Enter information about yourself, your brand, or your business in the text field. Include:\n\n• Your profession or role\n• Your interests and passions\n• What makes you unique\n• Your values or mission\n• Key achievements or highlights\n• Your niche or specialty\n\nExample: "Fitness coach, yoga enthusiast, helping people transform their lives through movement and mindfulness. Based in NYC."',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.auto_awesome,
                      iconColor: Colors.green,
                      title: 'Step 2: Generate Bios',
                      content:
                          'Click the "Generate Bios" button. Our AI will automatically create 3 different bio styles:\n\n• **Short & Punchy:** Concise, impactful bio (150 characters)\n• **Detailed:** Comprehensive bio with more information\n• **Aesthetic:** Stylized bio with emojis and formatting\n\nAll three styles are generated simultaneously, so you can choose the one that fits best!',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.swap_horiz,
                      iconColor: Colors.orange,
                      title: 'Step 3: Choose Your Style',
                      content:
                          'After generation, you\'ll see three style tabs at the top:\n\n• Tap on "Short & Punchy" for a concise bio\n• Tap on "Detailed" for a comprehensive bio\n• Tap on "Aesthetic" for a stylized bio with emojis\n\nThe selected bio will be displayed below. Switch between styles to find your perfect match!',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.content_copy,
                      iconColor: Colors.purple,
                      title: 'Step 4: Copy & Use',
                      content:
                          'Once you\'ve selected your preferred bio:\n\n• Review the generated bio text\n• Click the copy icon to copy it to clipboard\n• Paste it directly into your Instagram bio\n• Edit if needed to add personal touches\n• Update your profile picture and highlights to match',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.lightbulb_outline,
                      iconColor: Colors.amber,
                      title: 'Pro Tips',
                      content:
                          '💡 **Best Practices:**\n\n• Be specific about your niche or profession\n• Include keywords relevant to your audience\n• Mention your location if relevant\n• Add a call-to-action (e.g., "DM for collabs")\n• Keep it authentic and true to your brand\n• Update your bio regularly to reflect growth\n\n💡 **When to Use Each Style:**\n\n• **Short & Punchy:** Personal profiles, minimal aesthetic\n• **Detailed:** Business accounts, professional profiles\n• **Aesthetic:** Creative accounts, lifestyle brands\n\n💡 **Optimization Tips:**\n\n• Use line breaks for readability\n• Add relevant emojis (but don\'t overdo it)\n• Include a link in bio mention\n• Test different styles to see what resonates',
                    ),
                    const SizedBox(height: 24),
                    _buildGuideSection(
                      icon: Icons.psychology,
                      iconColor: Colors.purple,
                      title: 'How It Works',
                      content:
                          'Our AI Bio Maker uses advanced artificial intelligence to:\n\n1. **Analyze Description:** Understands your profession, interests, and brand\n2. **Generate Styles:** Creates three distinct bio styles automatically\n3. **Optimize Content:** Ensures bios are engaging and platform-appropriate\n4. **Ensure Variety:** Provides different approaches for maximum flexibility\n\nPowered by advanced AI technology that learns from successful Instagram profiles to provide bios that actually work.',
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
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Bio Maker'),
        backgroundColor: const Color(0xFF7B2CBF),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
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
                    serviceType: 'bio_maker',
                    serviceName: 'Bio Maker History',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueListenableBuilder<AiAccessState?>(
              valueListenable: AiUsageControlService.instance.state,
              builder: (_, state, __) => AiFreeLimitBanner(state: state, onUpgrade: () => Navigator.pushNamed(context, '/premium')),
            ),
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
                  hintText: 'Describe yourself, your interests, or your brand...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(20),
                ),
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),

            const SizedBox(height: 24),

            ValueListenableBuilder<AiAccessState?>(
              valueListenable: AiUsageControlService.instance.state,
              builder: (_, state, __) {
                final blocked = state != null && state.isFree && state.isLimitReached;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7B2CBF).withOpacity(0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: (_isGenerating || blocked) ? null : _generateBios,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: _isGenerating
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(blocked ? Icons.workspace_premium : Icons.auto_awesome, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    blocked ? 'Upgrade to Premium' : 'Generate Bios',
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
                    if (blocked && state?.resetAtUtc != null && state!.resetAtUtc!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      AiPlanCountdown(resetAtUtc: state.resetAtUtc, prefix: 'New free credits in '),
                    ],
                  ],
                );
              },
            ),

            if (_isGenerating) ...[
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B2CBF).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF7B2CBF)),
                    const SizedBox(height: 16),
                    Text(
                      'Crafting perfect bios... ✨',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_bios.isNotEmpty) ...[
              const SizedBox(height: 32),
              const Text(
                'Generated Bios',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                height: 45,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _bios.length,
                  itemBuilder: (context, index) {
                    final key = _bios.keys.elementAt(index);
                    final isSelected = _selectedType == key;
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedType = key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? const LinearGradient(
                                    colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                                  )
                                : null,
                            color: isSelected ? null : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              _bioTypes[key] ?? '',
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey[700],
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              if (_selectedType != null)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: (Colors.grey[200] ?? Colors.grey)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                (_bioTypes[_selectedType] ?? ''),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.bookmark_add, color: Color(0xFF7B2CBF)),
                                  onPressed: () async {
                                    try {
                                      final allBios = _bios.entries.map((e) => '${e.key}: ${e.value}').join('\n\n');
                                      await _historyService.saveHistory(
                                        serviceType: 'bio_maker',
                                        input: _inputController.text.trim(),
                                        output: allBios,
                                        metadata: {'styles': _bios.keys.toList()},
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
                                  tooltip: 'Save to history',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, color: Color(0xFF7B2CBF)),
                                  onPressed: () => _copyToClipboard(_bios[_selectedType] ?? ''),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SelectableText(
                          (_bios[_selectedType] ?? ''),
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.6,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import '../widgets/ai_ad_banner.dart';
import 'package:flutter/services.dart';

import '../services/ai_usage_control_service.dart';
import '../services/analytics_event_service.dart';
import '../services/api_service.dart';
import '../utils/share_helper.dart';
import '../services/history_service.dart';
import '../services/retention_service.dart';
import '../utils/ai_usage_guard.dart';
import '../widgets/ai_credit_badge.dart';
import 'history_screen.dart';

class AICaptionsScreen extends StatefulWidget {
  const AICaptionsScreen({super.key});

  @override
  State<AICaptionsScreen> createState() => _AICaptionsScreenState();
}

class _AICaptionsScreenState extends State<AICaptionsScreen> {
  final TextEditingController _captionRequestController = TextEditingController();
  final ApiService _api = ApiService();
  final HistoryService _historyService = HistoryService();
  final AnalyticsEventService _analytics = AnalyticsEventService();

  static const List<String> _styles = ['Viral', 'Funny', 'Luxury', 'Emotional'];

  List<Map<String, dynamic>> _captions = [];
  bool _isGenerating = false;
  String _selectedStyle = 'Viral';
  String _loadingDots = '';
  Timer? _loadingTimer;

  @override
  void initState() {
    super.initState();
    AiUsageControlService.instance.refresh();
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _captionRequestController.dispose();
    super.dispose();
  }

  void _startLoadingAnimation() {
    _loadingTimer?.cancel();
    _loadingDots = '';
    _loadingTimer = Timer.periodic(const Duration(milliseconds: 350), (_) {
      if (!mounted) return;
      setState(() {
        if (_loadingDots.length >= 3) {
          _loadingDots = '';
        } else {
          _loadingDots = '$_loadingDots.';
        }
      });
    });
  }

  void _stopLoadingAnimation() {
    _loadingTimer?.cancel();
    _loadingTimer = null;
    _loadingDots = '';
  }

  Future<void> _generateCaptions() async {
    final prompt = _captionRequestController.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe your post first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final generated = await runWithBackendAiGuard<List<dynamic>>(
        context,
        service: AiUsageControlService.instance,
        onGenerate: () async {
          setState(() {
            _isGenerating = true;
            _captions = [];
          });
          _startLoadingAnimation();

          final effectiveInput = '$prompt\nStyle: $_selectedStyle';
          final raw = await _api.generateCaptions(
            effectiveInput,
            onRetry: (_) {},
          );
          await AiUsageControlService.instance.refresh();
          return _normalizeCaptions(raw);
        },
      );

      if (!mounted) return;
      if (generated == null) {
        setState(() => _isGenerating = false);
        _stopLoadingAnimation();
        return;
      }

      final normalized = _normalizeCaptions(generated);
      setState(() {
        _captions = normalized;
        _isGenerating = false;
      });
      _stopLoadingAnimation();

      if (normalized.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No captions generated. Please try again.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final output = normalized
          .map((c) => '${c['text']}\n${(c['hashtags'] as List<String>).join(' ')}')
          .join('\n\n');

      await _historyService.saveHistory(
        serviceType: 'ai_captions',
        input: prompt,
        output: output,
        metadata: {'count': normalized.length, 'style': _selectedStyle},
      );

      unawaited(_analytics.logAppEvent('ai_captions_generated', {
        'style': _selectedStyle,
        'count': normalized.length,
      }));
      unawaited(RetentionService.instance.markToolUsed(
        tool: 'ai_captions',
        inputSnippet: prompt,
      ));
      unawaited(RetentionService.instance.completeMissionTask('caption_generate'));
    } catch (e) {
      if (!mounted) return;
      _stopLoadingAnimation();
      setState(() => _isGenerating = false);

      String msg = 'AI service not responding. Please try again.';
      if (e.toString().contains('CONNECTION_ERROR')) {
        msg = 'Cannot connect to backend.';
      } else if (e.toString().contains('TIMEOUT_ERROR')) {
        msg = 'Request timed out.';
      } else if (!e.toString().contains('DailyLimitReached')) {
        msg = e.toString().replaceAll('Exception: ', '');
      }

      if (!e.toString().contains('DailyLimitReached')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> _normalizeCaptions(List<dynamic> raw) {
    final out = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is Map) {
        final text = (item['text'] ?? item['caption'] ?? '').toString().trim();
        if (text.isEmpty) continue;
        final hashtags = <String>[];
        final source = item['hashtags'];
        if (source is List) {
          hashtags.addAll(source.map((e) => e.toString()));
        }
        if (hashtags.isEmpty) {
          hashtags.addAll(_extractHashtagsFromText(text));
        }
        out.add({
          'style': (item['style'] ?? item['angle'] ?? _selectedStyle).toString(),
          'text': _cleanCaptionText(text),
          'hashtags': hashtags,
        });
      } else if (item is String) {
        final cleaned = _cleanCaptionText(item);
        if (cleaned.isEmpty) continue;
        out.add({
          'style': _selectedStyle,
          'text': cleaned,
          'hashtags': _extractHashtagsFromText(item),
        });
      }
    }
    return out;
  }

  List<String> _extractHashtagsFromText(String text) {
    final matches = RegExp(r'(#[A-Za-z0-9_]+)').allMatches(text);
    return matches
        .map((m) => m.group(1) ?? '')
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  String _cleanCaptionText(String text) {
    var t = text.trim();
    t = t.replaceAll(RegExp(r'^[•\-\*]\s*'), '');
    t = t.replaceAll(RegExp(r'^\d+[\.\)]\s*'), '');
    t = t.replaceAll(RegExp(r'\s+'), ' ');
    return t.trim();
  }

  Future<void> _copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied'),
        backgroundColor: Color(0xFF7B2CBF),
      ),
    );
  }

  Future<void> _saveCaption(Map<String, dynamic> caption) async {
    final prompt = _captionRequestController.text.trim();
    final output = '${caption['text']}\n${(caption['hashtags'] as List<String>).join(' ')}';
    await _historyService.saveHistory(
      serviceType: 'ai_captions',
      input: prompt,
      output: output,
      metadata: {'single': true, 'style': caption['style']},
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Caption saved')),
    );
  }

  Future<void> _scheduleCaption(Map<String, dynamic> caption) async {
    await _saveCaption(caption);
    if (!mounted) return;
    Navigator.pushNamed(context, '/schedule-post');
  }

  List<String> _allUniqueHashtags() {
    final tags = <String>{};
    for (final c in _captions) {
      final list = c['hashtags'];
      if (list is List<String>) {
        tags.addAll(list);
      }
    }
    return tags.toList();
  }

  List<List<String>> _groupHashtags(List<String> tags, {int size = 6}) {
    if (tags.isEmpty) return const [];
    final grouped = <List<String>>[];
    for (var i = 0; i < tags.length; i += size) {
      final end = (i + size < tags.length) ? i + size : tags.length;
      grouped.add(tags.sublist(i, end));
    }
    return grouped;
  }

  Widget _buildStyleChip(String label) {
    final selected = _selectedStyle == label;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: _isGenerating
          ? null
          : (_) => setState(() {
                _selectedStyle = label;
              }),
      selectedColor: const Color(0xFF7B2CBF).withOpacity(0.18),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF5A189A) : Colors.black87,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: selected
              ? const Color(0xFF7B2CBF)
              : const Color(0xFF7B2CBF).withOpacity(0.2),
        ),
      ),
      backgroundColor: Colors.white,
    );
  }

  Widget _buildGenerateButton() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B2CBF).withOpacity(0.28),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isGenerating ? null : _generateCaptions,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white70,
          disabledBackgroundColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          _isGenerating ? 'Generating viral captions$_loadingDots' : '✨ Generate AI Captions',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildSkeletonCard() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.35, end: 0.75),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, value, _) {
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF7B2CBF).withOpacity(0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 84,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(value),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                height: 12,
                width: double.infinity,
                color: Colors.grey.withOpacity(value),
              ),
              const SizedBox(height: 8),
              Container(
                height: 12,
                width: 220,
                color: Colors.grey.withOpacity(value - 0.1),
              ),
              const SizedBox(height: 12),
              Container(
                height: 38,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(value - 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCaptionCard(Map<String, dynamic> caption, int index) {
    final style = (caption['style'] ?? _selectedStyle).toString();
    final text = (caption['text'] ?? '').toString();
    final hashtags = (caption['hashtags'] as List<String>? ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7B2CBF), Color(0xFFFF66C4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Container(
        margin: const EdgeInsets.all(1.6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7B2CBF).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '🔥 ${style[0].toUpperCase()}${style.substring(1)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF5A189A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Caption ${index + 1}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              text,
              style: const TextStyle(
                fontSize: 15.5,
                color: Color(0xFF1F1A2E),
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (hashtags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: hashtags
                    .take(6)
                    .map(
                      (tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3EEFF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            color: Color(0xFF6A1B9A),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copyText('$text\n\n${hashtags.join(' ')}'.trim()),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text(
                      'Copy',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7B2CBF),
                      side: BorderSide(color: const Color(0xFF7B2CBF).withOpacity(0.35)),
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _saveCaption(caption),
                    icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                    label: const Text(
                      'Save',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7B2CBF),
                      side: BorderSide(color: const Color(0xFF7B2CBF).withOpacity(0.35)),
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _scheduleCaption(caption),
                    icon: const Icon(Icons.schedule_rounded, size: 18),
                    label: const Text(
                      'Schedule',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7B2CBF),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Share',
                  onPressed: () => ShareHelper.shareResult('$text\n\n${hashtags.join(' ')}'.trim()),
                  icon: const Icon(Icons.ios_share_rounded, color: Color(0xFF7B2CBF)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHashtagsSection() {
    final allTags = _allUniqueHashtags();
    if (allTags.isEmpty) return const SizedBox.shrink();

    final grouped = _groupHashtags(allTags);
    final allAsText = allTags.join(' ');

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7B2CBF).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Hashtags',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2A1A3A),
                ),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: () => _copyText(allAsText),
                icon: const Icon(Icons.copy_all_rounded, size: 18),
                label: const Text('Copy all'),
                style: FilledButton.styleFrom(
                  foregroundColor: const Color(0xFF6A1B9A),
                  backgroundColor: const Color(0xFFEDE0FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...grouped.asMap().entries.map(
                (entry) => Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F3FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Set ${entry.key + 1}: ${entry.value.join(' ')}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: Color(0xFF4A2D6B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final limitReached = AiUsageControlService.instance.lastState != null &&
        AiUsageControlService.instance.lastState!.isFree &&
        AiUsageControlService.instance.lastState!.isLimitReached;

    return Scaffold(
      bottomNavigationBar: const AiAdBanner(),
      appBar: AppBar(
        title: const Text('AI Captions'),
        backgroundColor: const Color(0xFF7B2CBF),
        actions: [
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HistoryScreen(
                    serviceType: 'ai_captions',
                    serviceName: 'AI Captions History',
                  ),
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
            colors: [Color(0xFFF8F6FF), Color(0xFFFFFFFF)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ValueListenableBuilder<AiAccessState?>(
                valueListenable: AiUsageControlService.instance.state,
                builder: (_, state, __) => AiFreeLimitBanner(
                  state: state,
                  onUpgrade: () => Navigator.pushNamed(context, '/premium'),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7B2CBF).withOpacity(0.1),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _captionRequestController,
                      minLines: 3,
                      maxLines: 6,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Describe your post',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        filled: true,
                        fillColor: const Color(0xFFF8F4FF),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF7B2CBF), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Style',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF341B4E),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _styles.map(_buildStyleChip).toList(),
                    ),
                    const SizedBox(height: 16),
                    AbsorbPointer(
                      absorbing: limitReached,
                      child: Opacity(
                        opacity: limitReached ? 0.55 : 1,
                        child: Center(
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            child: _buildGenerateButton(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_isGenerating) ...[
                Center(
                  child: Text(
                    'Generating viral captions$_loadingDots',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6A1B9A),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildSkeletonCard(),
                _buildSkeletonCard(),
                _buildSkeletonCard(),
              ] else ...[
                ..._captions.asMap().entries.map((e) => _buildCaptionCard(e.value, e.key)),
                if (_captions.isNotEmpty) _buildHashtagsSection(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

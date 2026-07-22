import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/schedule_post_media_slot.dart';
import '../../services/ai_growth_service.dart';
import '../../services/ai_service.dart';
import '../../utils/ai_access_exception.dart';
import '../../widgets/schedule_post/photo_filters.dart';
import '../../widgets/schedule_post/schedule_post_video_preview.dart';
import 'music_library_sheet.dart';
import 'post_creation_session.dart';

/// Step 2: crop, resize, filters, brightness for images; trim + music for video.
class PostCreationStep2Editor extends StatefulWidget {
  const PostCreationStep2Editor({
    super.key,
    required this.session,
    required this.captionController,
    required this.hashtagController,
    required this.onContinue,
  });

  final PostCreationSession session;
  final TextEditingController captionController;
  final TextEditingController hashtagController;
  final VoidCallback onContinue;

  @override
  State<PostCreationStep2Editor> createState() => _PostCreationStep2EditorState();
}

class _PostCreationStep2EditorState extends State<PostCreationStep2Editor> {
  final PageController _pageController = PageController();
  final AIService _ai = AIService();
  final AiGrowthService _growth = AiGrowthService();
  bool _aiBusy = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _filtered(SchedulePostMediaSlot s, Widget child) {
    return applyMatrixWidget(
      buildFinalMatrix(
        filterIndex: s.filterIndex,
        intensity: s.filterIntensity,
        brightness: s.brightnessFactor,
        contrast: s.contrast.clamp(0.25, 2.0),
        saturation: s.saturation,
        warmth: s.warmth,
      ),
      child,
    );
  }

  Future<void> _openFilters(int index) async {
    final slot = widget.session.imageSlots[index];
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final primary = Theme.of(ctx).colorScheme.primary;
        return StatefulBuilder(
          builder: (ctx, setModal) {
            void upd(VoidCallback fn) {
              setModal(fn);
              setState(() {});
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ListTile(
                      leading: Icon(Icons.tune_rounded),
                      title: Text('Edit photo'),
                    ),
                    SizedBox(
                      height: 96,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: kPhotoFilterCount,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) {
                          final selected = slot.filterIndex == i;
                          return GestureDetector(
                            onTap: () => upd(() => slot.filterIndex = i),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 62,
                                  height: 62,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: selected ? primary : Colors.transparent,
                                      width: 2.5,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  // Native-decode the photo (handles HEIC etc.) and
                                  // apply the pure filter look as a widget — reliable
                                  // where image-package decode returned blank.
                                  child: applyMatrixWidget(
                                    buildFinalMatrix(filterIndex: i),
                                    Image.file(slot.file, fit: BoxFit.cover, cacheWidth: 140),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  kPhotoFilters[i].name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (slot.filterIndex != 0)
                      _sliderRow('Filter strength', slot.filterIntensity, 0, 1,
                          (v) => upd(() => slot.filterIntensity = v)),
                    _sliderRow('Brightness', slot.brightness, -1, 1,
                        (v) => upd(() => slot.brightness = v)),
                    _sliderRow('Contrast', slot.contrast, 0.5, 1.5,
                        (v) => upd(() => slot.contrast = v)),
                    _sliderRow('Saturation', slot.saturation, 0, 2,
                        (v) => upd(() => slot.saturation = v)),
                    _sliderRow('Warmth', slot.warmth, -1, 1,
                        (v) => upd(() => slot.warmth = v)),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: OutlinedButton(
                        onPressed: () => upd(() {
                          slot.filterIndex = 0;
                          slot.filterIntensity = 1;
                          slot.brightness = 0;
                          slot.contrast = 1;
                          slot.saturation = 1;
                          slot.warmth = 0;
                        }),
                        child: const Text('Reset'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _sliderRow(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  /// Crop is temporarily disabled: the native cropper (image_cropper/uCrop) was
  /// removed because its device requirements dropped ~3000 device models from
  /// Play. The post editor is gated as "Coming Soon", so this is a harmless stub
  /// until we ship a device-safe cropper when the editor goes live.
  Future<void> _openCrop(int index, {bool lockAspect = false}) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cropping is coming soon.')),
    );
  }

  Future<void> _resizeSheet(int index) async {
    final chosen = await showModalBottomSheet<PostFeedAspect>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Aspect ratio',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Pick a size — the photo opens in the cropper to fit it.',
                style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 14),
            SegmentedButton<PostFeedAspect>(
              segments: const [
                ButtonSegment(value: PostFeedAspect.square, icon: Icon(Icons.crop_square), label: Text('1:1')),
                ButtonSegment(value: PostFeedAspect.portrait, icon: Icon(Icons.crop_portrait), label: Text('4:5')),
                ButtonSegment(value: PostFeedAspect.reel, icon: Icon(Icons.stay_current_portrait), label: Text('9:16')),
              ],
              selected: {widget.session.aspect},
              onSelectionChanged: (s) => Navigator.pop(ctx, s.first),
            ),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    setState(() => widget.session.aspect = chosen);
    // Actually APPLY the new size: open the cropper LOCKED to this aspect so the
    // image is re-cut to it (previously this only changed a setting → no effect).
    await _openCrop(index, lockAspect: true);
  }

  /// Music entry point: choose the in-app royalty-free library or a device file.
  Future<void> _openMusicOptions() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.library_music_rounded, color: Color(0xFF7B2CBF)),
              title: const Text('InstaFlow music library'),
              subtitle: const Text('Royalty-free songs — no copyright'),
              onTap: () => Navigator.pop(ctx, 'library'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_rounded),
              title: const Text('Choose from device'),
              onTap: () => Navigator.pop(ctx, 'device'),
            ),
            if (widget.session.musicLabel != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: const Text('Remove music'),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'device') {
      await _pickMusic();
    } else if (choice == 'remove') {
      setState(() {
        widget.session.musicFile = null;
        widget.session.musicLabel = null;
      });
    } else if (choice == 'library') {
      final picked = await showModalBottomSheet<PickedMusic>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => const MusicLibrarySheet(),
      );
      if (picked != null && mounted) {
        setState(() {
          widget.session.musicFile = picked.file;
          widget.session.musicLabel = picked.label;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Music added: ${picked.label}')),
        );
      }
    }
  }

  Future<void> _pickMusic() async {
    final r = await FilePicker.pickFiles(type: FileType.audio);
    if (r == null || r.files.isEmpty || !mounted) return;
    final path = r.files.single.path;
    if (path == null) return;
    setState(() {
      widget.session.musicFile = File(path);
      widget.session.musicLabel = r.files.single.name;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Music added: ${r.files.single.name}')),
      );
    }
  }

  /// Append more photos to the carousel (Instagram-style multi-image post).
  Future<void> _addPhotos() async {
    if (widget.session.isVideo) return;
    try {
      final picked = await ImagePicker().pickMultiImage();
      if (picked.isEmpty || !mounted) return;
      const maxSlots = 10;
      setState(() {
        for (final x in picked) {
          if (widget.session.imageSlots.length >= maxSlots) break;
          widget.session.imageSlots.add(
            SchedulePostMediaSlot(
              id: '${DateTime.now().microsecondsSinceEpoch}_${widget.session.imageSlots.length}',
              file: File(x.path),
            ),
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not add photos: $e')));
      }
    }
  }

  Future<void> _showAiEnhanceMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_search_rounded),
              title: const Text('Improve image'),
              subtitle: const Text('AI scene understanding & tips'),
              onTap: () async {
                Navigator.pop(ctx);
                await _improveImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_rounded),
              title: const Text('Generate caption'),
              onTap: () async {
                Navigator.pop(ctx);
                await _genCaption();
              },
            ),
            ListTile(
              leading: const Icon(Icons.tag_rounded),
              title: const Text('Suggest hashtags'),
              onTap: () async {
                Navigator.pop(ctx);
                await _genTags();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _improveImage() async {
    if (widget.session.imageSlots.isEmpty || !_ai.isConfigured) return;
    setState(() => _aiBusy = true);
    try {
      final desc = await _ai.analyzeImage(widget.session.imageSlots.first.file.path);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Image insights'),
          content: SingleChildScrollView(child: Text(desc)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  Future<void> _genCaption() async {
    if (!_ai.isConfigured) return;
    setState(() => _aiBusy = true);
    try {
      final path = widget.session.imageSlots.isNotEmpty ? widget.session.imageSlots.first.file.path : null;
      final t = widget.captionController.text.trim().isEmpty
          ? 'Engaging Instagram post for my audience'
          : widget.captionController.text.trim();
      final c = await _ai.generateCaption(topic: t, style: 'trending', imagePath: path);
      if (!mounted) return;
      if (c.trim().isNotEmpty) widget.captionController.text = c.trim();
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  Future<void> _genTags() async {
    if (!_ai.isConfigured) return;
    setState(() => _aiBusy = true);
    try {
      final t = widget.captionController.text.trim().isEmpty
          ? 'instagram creator content'
          : widget.captionController.text.trim();
      final tags = await _ai.generateHashtags(t);
      if (!mounted) return;
      if (tags.isNotEmpty) {
        widget.hashtagController.text = tags.take(18).join(' ');
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  Future<File?> _writeEnhancedImageFromDataUrl(String? dataUrl) async {
    if (dataUrl == null || dataUrl.isEmpty) return null;
    if (!dataUrl.startsWith('data:')) return null;
    final comma = dataUrl.indexOf('base64,');
    if (comma < 0) return null;
    final b64 = dataUrl.substring(comma + 7);
    final bytes = base64Decode(b64);
    final dir = await getTemporaryDirectory();
    final f = File(p.join(dir.path, 'ai_enhanced_${DateTime.now().millisecondsSinceEpoch}.jpg'));
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }

  /// Full pipeline: enhance preview, fill caption & hashtags, show engagement + timing.
  Future<void> _runFullAssist() async {
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to use AI Assist')),
      );
      return;
    }
    if (widget.session.isVideo || widget.session.imageSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a photo to use AI Assist')),
      );
      return;
    }
    setState(() => _aiBusy = true);
    try {
      final slot = widget.session.imageSlots[widget.session.currentImageIndex];
      final topic = widget.captionController.text.trim();
      final r = await _growth.fullAssistFromFile(
        slot.file,
        topic: topic.isEmpty ? null : topic,
      );
      if (!mounted) return;
      final out = await _writeEnhancedImageFromDataUrl(r.enhancedImageDataUrl);
      if (out != null) setState(() => slot.file = out);
      widget.captionController.text = r.caption;
      widget.hashtagController.text = r.hashtags.join(' ');
      widget.session.aiEngagementScore = r.engagementScore;
      widget.session.aiBestTime = r.bestTime;
      widget.session.aiTips = r.tips;
      setState(() {});
    } on DailyLimitReachedException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Daily AI limit reached')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = widget.session;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (!s.isVideo && s.imageSlots.isNotEmpty)
                FilledButton.icon(
                  onPressed: _aiBusy ? null : _runFullAssist,
                  icon: _aiBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_rounded),
                  label: const Text('✨ AI Assist'),
                ),
              if (_ai.isConfigured)
                FilledButton.tonalIcon(
                  onPressed: _aiBusy ? null : _showAiEnhanceMenu,
                  icon: _aiBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.psychology_outlined),
                  label: const Text('More AI'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: s.isVideo && s.videoFile != null
              ? ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: ColoredBox(
                        color: Colors.black,
                        child: SchedulePostVideoPreview(
                          file: s.videoFile!,
                          trimStartFraction: s.trimStart,
                          trimEndFraction: s.trimEnd,
                          onTrimChanged: (a, b) => setState(() {
                            s.trimStart = a;
                            s.trimEnd = b;
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const Icon(Icons.library_music_rounded),
                      title: const Text('Add music'),
                      subtitle: Text(s.musicLabel ?? 'Royalty-free library or your device'),
                      trailing: FilledButton.tonal(
                        onPressed: _openMusicOptions,
                        child: const Text('Add'),
                      ),
                    ),
                    if (s.musicLabel != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: InputChip(
                          label: Text(s.musicLabel!),
                          onDeleted: () => setState(() {
                            s.musicFile = null;
                            s.musicLabel = null;
                          }),
                        ),
                      ),
                  ],
                )
              : Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (i) => setState(() => s.currentImageIndex = i),
                        itemCount: s.imageSlots.length,
                        itemBuilder: (ctx, i) {
                          final slot = s.imageSlots[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: ColoredBox(
                                color: Colors.black,
                                child: Center(
                                  child: _filtered(
                                    slot,
                                    Image.file(
                                      slot.file,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (s.imageSlots.length > 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            s.imageSlots.length,
                            (i) => Container(
                              width: i == s.currentImageIndex ? 18 : 7,
                              height: 7,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: i == s.currentImageIndex ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Row(
                        children: [
                          _chip(theme, Icons.add_photo_alternate_outlined, 'Add photo', _addPhotos),
                          _chip(theme, Icons.crop_rounded, 'Crop', () => _openCrop(s.currentImageIndex)),
                          _chip(theme, Icons.aspect_ratio_rounded, 'Resize', () => _resizeSheet(s.currentImageIndex)),
                          _chip(theme, Icons.palette_outlined, 'Filters', () => _openFilters(s.currentImageIndex)),
                          _chip(theme, Icons.tune_rounded, 'Adjust', () => _openFilters(s.currentImageIndex)),
                          _chip(
                            theme,
                            Icons.library_music_outlined,
                            s.musicLabel == null ? 'Music' : 'Music ✓',
                            _openMusicOptions,
                          ),
                        ],
                      ),
                    ),
                    if (s.aiEngagementScore != null ||
                        (s.aiBestTime != null && s.aiBestTime!.isNotEmpty) ||
                        (s.aiTips != null && s.aiTips!.isNotEmpty))
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (s.aiEngagementScore != null)
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Engagement outlook',
                                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: (s.aiEngagementScore!.clamp(0, 100)) / 100,
                                                minHeight: 8,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            '${s.aiEngagementScore}',
                                            style: theme.textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (s.aiBestTime != null && s.aiBestTime!.isNotEmpty)
                              Card(
                                child: ListTile(
                                  leading: Icon(Icons.schedule_rounded, color: theme.colorScheme.primary),
                                  title: const Text('Suggested post time'),
                                  subtitle: Text(s.aiBestTime!),
                                ),
                              ),
                            if (s.aiTips != null && s.aiTips!.isNotEmpty)
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Tips',
                                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(s.aiTips!, style: theme.textTheme.bodyMedium),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FilledButton(
              onPressed: widget.onContinue,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Next'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(ThemeData theme, IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        onPressed: onTap,
      ),
    );
  }
}

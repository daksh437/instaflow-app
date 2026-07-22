import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/ai_service.dart';
import '../../services/instagram_auth_service.dart';
import '../../services/scheduler_service.dart';
import '../../services/shared_ai_content_store.dart';
import 'post_creation_session.dart';
import 'post_creation_step1_gallery.dart';
import 'post_creation_step2_editor.dart';
import 'post_creation_step3_caption.dart';
import 'post_creation_submit.dart';

/// Instagram-style 3-step post creation: gallery → editor → caption & schedule.
class PostCreationFlow extends StatefulWidget {
  const PostCreationFlow({super.key});

  @override
  State<PostCreationFlow> createState() => _PostCreationFlowState();
}

class _PostCreationFlowState extends State<PostCreationFlow> {
  final PostCreationSession _session = PostCreationSession();
  final TextEditingController _caption = TextEditingController();
  final TextEditingController _hashtags = TextEditingController();
  final SchedulerService _scheduler = SchedulerService();
  final AIService _ai = AIService();

  int _step = 0;
  bool _ready = false;
  bool _submitting = false;

  void _captionListener() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _caption.addListener(_captionListener);
    final shared = SharedAiContentStore.instance.current;
    if (shared.caption.trim().isNotEmpty) {
      _caption.text = shared.caption;
    } else if (shared.idea.trim().isNotEmpty) {
      _caption.text = shared.idea;
    }
    if (shared.hashtags.isNotEmpty) {
      _hashtags.text = shared.hashtags.join(' ');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await InstagramAuthService.instance.init();
      await _loadSlots();
      if (!mounted) return;
      setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _caption.removeListener(_captionListener);
    _caption.dispose();
    _hashtags.dispose();
    super.dispose();
  }

  Future<void> _loadSlots() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final slots = await _scheduler.getSlots(uid);
      if (!mounted) return;
      setState(() {
        _session.queueSlots = slots;
        if (_session.selectedQueueSlotId == null && slots.isNotEmpty) {
          _session.selectedQueueSlotId = '${slots.first['id']}';
        }
      });
    } catch (_) {}
  }

  Future<void> _applyAutoPost() async {
    if (!_ai.isConfigured) return;
    final path =
        !_session.isVideo && _session.imageSlots.isNotEmpty ? _session.imageSlots.first.file.path : null;
    final topic = _caption.text.trim().isEmpty ? 'Engaging Instagram post for my audience' : _caption.text.trim();
    final cap = await _ai.generateCaption(topic: topic, style: 'viral', imagePath: path);
    if (cap.trim().isNotEmpty) _caption.text = cap.trim();
    final tags = await _ai.generateHashtags(_caption.text.trim().isEmpty ? topic : _caption.text.trim());
    if (tags.isNotEmpty) _hashtags.text = tags.take(18).join(' ');
    _session.scheduledAt = suggestedBestPostTime();
  }

  Future<void> _submit() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (_session.isVideo && _session.videoFile == null || !_session.isVideo && _session.imageSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add media')));
      return;
    }

    setState(() => _submitting = true);
    try {
      if (_session.autoPostMode) {
        await _applyAutoPost();
      }
      if (!mounted) return;
      if (_caption.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add a caption')));
        return;
      }
      await submitScheduledPost(
        session: _session,
        captionText: _caption.text,
        hashtagText: _hashtags.text,
        scheduler: _scheduler,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post scheduled')));
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _goBack() {
    if (_step <= 0) {
      Navigator.of(context).pop();
    } else {
      setState(() => _step--);
    }
  }

  String _title() {
    switch (_step) {
      case 0:
        return 'New post';
      case 1:
        return 'Edit';
      case 2:
        return 'Caption';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(_step == 0 ? Icons.close : Icons.arrow_back_ios_new_rounded),
          onPressed: _submitting ? null : _goBack,
        ),
        title: Text(_title()),
        actions: [
          IconButton(
            tooltip: 'Queue slots',
            onPressed: _submitting ? null : () => Navigator.pushNamed(context, '/queue-slots'),
            icon: const Icon(Icons.tune_rounded),
          ),
          IconButton(
            tooltip: 'Calendar',
            onPressed: _submitting ? null : () => Navigator.pushNamed(context, '/scheduler-calendar'),
            icon: const Icon(Icons.calendar_month_outlined),
          ),
          IconButton(
            tooltip: 'Scheduled posts',
            onPressed: _submitting ? null : () => Navigator.pushNamed(context, '/scheduled_posts'),
            icon: const Icon(Icons.list_alt_rounded),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) {
          final offset = Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero).animate(anim);
          return SlideTransition(
            position: offset,
            child: FadeTransition(opacity: anim, child: child),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_step),
          child: _step == 0
              ? PostCreationStep1Gallery(
                  session: _session,
                  onStep1Complete: () => setState(() => _step = 1),
                )
              : _step == 1
                  ? PostCreationStep2Editor(
                      session: _session,
                      captionController: _caption,
                      hashtagController: _hashtags,
                      onContinue: () => setState(() => _step = 2),
                    )
                  : PostCreationStep3Caption(
                      session: _session,
                      captionController: _caption,
                      hashtagController: _hashtags,
                      onSchedule: _submit,
                      submitting: _submitting,
                    ),
        ),
      ),
    );
  }
}

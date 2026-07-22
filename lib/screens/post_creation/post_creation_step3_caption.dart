import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/ai_service.dart';
import '../../services/instagram_auth_service.dart';
import '../../models/schedule_post_media_slot.dart';
import '../../widgets/schedule_post/photo_filters.dart';
import 'post_creation_session.dart';
import 'post_creation_submit.dart';

/// Step 3: caption, schedule, preview, auto-post, trend boost.
class PostCreationStep3Caption extends StatefulWidget {
  const PostCreationStep3Caption({
    super.key,
    required this.session,
    required this.captionController,
    required this.hashtagController,
    required this.onSchedule,
    required this.submitting,
  });

  final PostCreationSession session;
  final TextEditingController captionController;
  final TextEditingController hashtagController;
  final Future<void> Function() onSchedule;
  final bool submitting;

  @override
  State<PostCreationStep3Caption> createState() => _PostCreationStep3CaptionState();
}

class _PostCreationStep3CaptionState extends State<PostCreationStep3Caption> {
  final AIService _ai = AIService();
  bool _aiBusy = false;
  final PageController _previewPage = PageController();

  @override
  void dispose() {
    _previewPage.dispose();
    super.dispose();
  }

  Future<void> _aiCaption() async {
    if (!_ai.isConfigured || _aiBusy) return;
    setState(() => _aiBusy = true);
    try {
      final path = !widget.session.isVideo && widget.session.imageSlots.isNotEmpty
          ? widget.session.imageSlots.first.file.path
          : null;
      final t = widget.captionController.text.trim().isEmpty
          ? 'Engaging Instagram post'
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

  Future<void> _suggestHashtags() async {
    if (!_ai.isConfigured || _aiBusy) return;
    setState(() => _aiBusy = true);
    try {
      final t = widget.captionController.text.trim().isEmpty
          ? 'instagram creator'
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

  void _appendTag(String tag) {
    final h = widget.hashtagController.text.trim();
    final add = tag.startsWith('#') ? tag : '#$tag';
    widget.hashtagController.text = h.isEmpty ? add : '$h $add';
    setState(() {});
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final connected = InstagramAuthService.instance.isLoggedIn;
    final suggested = suggestedBestPostTime();
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName?.trim();
    final uname = (name != null && name.isNotEmpty)
        ? name
        : ((user?.email ?? '').split('@').first.isEmpty ? 'creator' : (user?.email ?? '').split('@').first);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (!connected)
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Connect Instagram to schedule.'),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () async {
                      await InstagramAuthService.instance.login();
                      if (context.mounted) setState(() {});
                    },
                    child: const Text('Connect'),
                  ),
                ],
              ),
            ),
          )
        else
          Row(
            children: [
              CircleAvatar(
                backgroundColor: cs.primaryContainer,
                child: Icon(Icons.person_rounded, color: cs.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(uname, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    Text(
                      'Scheduled Post',
                      style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Preview mode'),
          subtitle: const Text('Overlay caption on media'),
          value: widget.session.previewCaption,
          onChanged: (v) => setState(() => widget.session.previewCaption = v),
        ),
        if (widget.session.previewCaption &&
            !widget.session.isVideo &&
            widget.session.imageSlots.isNotEmpty)
          SizedBox(
            height: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _previewPage,
                    itemCount: widget.session.imageSlots.length,
                    itemBuilder: (ctx, i) {
                      final slot = widget.session.imageSlots[i];
                      return _filtered(
                        slot,
                        Image.file(slot.file, fit: BoxFit.cover),
                      );
                    },
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Text(
                      widget.captionController.text.trim().isEmpty
                          ? 'Caption preview'
                          : widget.captionController.text.trim(),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        shadows: [Shadow(blurRadius: 8, color: Colors.black87)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (widget.session.previewCaption && widget.session.imageSlots.isNotEmpty) const SizedBox(height: 12),
        TextField(
          controller: widget.captionController,
          minLines: 4,
          maxLines: 8,
          maxLength: 2200,
          decoration: InputDecoration(
            hintText: 'Write a caption...',
            filled: true,
            fillColor: cs.surfaceContainerHighest.withOpacity(0.45),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: cs.primary),
            ),
            contentPadding: const EdgeInsets.all(18),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: widget.hashtagController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Hashtags',
            filled: true,
            fillColor: cs.surfaceContainerHighest.withOpacity(0.35),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('#trending'),
              onPressed: () => _appendTag('trending'),
            ),
            ActionChip(
              label: const Text('#explore'),
              onPressed: () => _appendTag('explore'),
            ),
            ActionChip(
              label: const Text('#creator'),
              onPressed: () => _appendTag('creator'),
            ),
            ActionChip(
              label: const Text('#growth'),
              onPressed: () => _appendTag('growth'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Trend Boost — tap to add', style: theme.textTheme.labelLarge),
        const SizedBox(height: 20),
        if (_ai.isConfigured)
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: widget.submitting || _aiBusy ? null : _aiCaption,
                  icon: _aiBusy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome_rounded),
                  label: const Text('AI caption'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.submitting || _aiBusy ? null : _suggestHashtags,
                  icon: const Icon(Icons.tag_rounded),
                  label: const Text('Hashtag ideas'),
                ),
              ),
            ],
          ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: cs.surfaceContainerHighest.withOpacity(0.5),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Best time to post', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  DateFormat('EEEE · hh:mm a').format(suggested),
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Evening slots often get stronger engagement (heuristic).',
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: widget.submitting
                      ? null
                      : () {
                          setState(() => widget.session.scheduledAt = suggested);
                        },
                  child: const Text('Use suggested time'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('Auto Post mode'),
          subtitle: const Text('AI writes caption & hashtags and applies best time when you schedule'),
          value: widget.session.autoPostMode,
          onChanged: (v) => setState(() => widget.session.autoPostMode = v),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'exact', label: Text('Exact time')),
            ButtonSegment(value: 'queue', label: Text('Queue')),
          ],
          selected: {widget.session.scheduleMode},
          onSelectionChanged: (x) => setState(() => widget.session.scheduleMode = x.first),
        ),
        if (widget.session.scheduleMode == 'queue') ...[
          const SizedBox(height: 12),
          if (widget.session.queueSlots.isEmpty)
            Text(
              'Create queue slots from the toolbar menu.',
              style: TextStyle(color: Colors.amber.shade900, fontSize: 13),
            )
          else
            DropdownButtonFormField<String>(
              value: widget.session.selectedQueueSlotId != null &&
                      widget.session.queueSlots.any((s) => '${s['id']}' == widget.session.selectedQueueSlotId)
                  ? widget.session.selectedQueueSlotId
                  : null,
              decoration: const InputDecoration(
                labelText: 'Queue slot',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
              items: widget.session.queueSlots
                  .map(
                    (slot) => DropdownMenuItem<String>(
                      value: '${slot['id']}',
                      child: Text(
                        '${slot['time'] ?? '-'} • ${(slot['days'] as List?)?.join(',') ?? '-'}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: widget.submitting
                  ? null
                  : (v) => setState(() => widget.session.selectedQueueSlotId = v),
            ),
        ],
        if (widget.session.scheduleMode == 'exact') ...[
          const SizedBox(height: 12),
          Text(DateFormat('dd MMM yyyy · hh:mm a').format(widget.session.scheduledAt),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.submitting
                      ? null
                      : () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: widget.session.scheduledAt,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (d == null || !context.mounted) return;
                          setState(() {
                            widget.session.scheduledAt = DateTime(
                              d.year,
                              d.month,
                              d.day,
                              widget.session.scheduledAt.hour,
                              widget.session.scheduledAt.minute,
                            );
                          });
                        },
                  icon: const Icon(Icons.calendar_today_rounded),
                  label: const Text('Date'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.submitting
                      ? null
                      : () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(widget.session.scheduledAt),
                          );
                          if (t == null || !context.mounted) return;
                          setState(() {
                            final s = widget.session.scheduledAt;
                            widget.session.scheduledAt = DateTime(s.year, s.month, s.day, t.hour, t.minute);
                          });
                        },
                  icon: const Icon(Icons.schedule_rounded),
                  label: const Text('Time'),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF833AB4), Color(0xFF7B2CBF), Color(0xFF5A189A)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5A189A).withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: !connected || widget.submitting ? null : widget.onSchedule,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: widget.submitting
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : const Text(
                    'Schedule & Boost',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

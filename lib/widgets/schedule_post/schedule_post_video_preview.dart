import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Video preview with play/pause and trim range (UI only; upload uses full file).
class SchedulePostVideoPreview extends StatefulWidget {
  const SchedulePostVideoPreview({
    super.key,
    required this.file,
    required this.trimStartFraction,
    required this.trimEndFraction,
    required this.onTrimChanged,
  });

  final File file;
  /// 0–1 relative to duration.
  final double trimStartFraction;
  final double trimEndFraction;
  final void Function(double start, double end) onTrimChanged;

  @override
  State<SchedulePostVideoPreview> createState() => _SchedulePostVideoPreviewState();
}

class _SchedulePostVideoPreviewState extends State<SchedulePostVideoPreview> {
  VideoPlayerController? _c;
  bool _initFailed = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final controller = VideoPlayerController.file(widget.file);
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.setLooping(true);
      controller.addListener(_tick);
      controller.addListener(_onVideoUpdate);
      setState(() => _c = controller);
      _applyTrimSeek();
    } catch (_) {
      await controller.dispose();
      if (mounted) setState(() => _initFailed = true);
    }
  }

  void _onVideoUpdate() {
    if (mounted) setState(() {});
  }

  void _tick() {
    if (!mounted || _c == null || !_c!.value.isInitialized) return;
    final d = _c!.value.duration.inMilliseconds;
    if (d <= 0) return;
    final endMs = widget.trimEndFraction * d;
    final pos = _c!.value.position.inMilliseconds;
    if (pos >= endMs - 80) {
      final startMs = widget.trimStartFraction * d;
      _c!.seekTo(Duration(milliseconds: startMs.round()));
    }
  }

  void _applyTrimSeek() {
    final controller = _c;
    if (controller == null || !controller.value.isInitialized) return;
    final d = controller.value.duration.inMilliseconds;
    if (d <= 0) return;
    final startMs = (widget.trimStartFraction * d).round();
    controller.seekTo(Duration(milliseconds: startMs));
  }

  @override
  void didUpdateWidget(covariant SchedulePostVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trimStartFraction != widget.trimStartFraction ||
        oldWidget.file.path != widget.file.path) {
      _applyTrimSeek();
    }
  }

  @override
  void dispose() {
    final controller = _c;
    if (controller != null) {
      controller.removeListener(_tick);
      controller.removeListener(_onVideoUpdate);
      controller.dispose();
    }
    super.dispose();
  }

  void _togglePlay() {
    final controller = _c;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_initFailed) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Could not load video preview'),
        ),
      );
    }
    final controller = _c;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    final d = controller.value.duration;
    final durSec = d.inMilliseconds / 1000.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: controller.value.aspectRatio > 0 ? controller.value.aspectRatio : 16 / 9,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(controller),
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _togglePlay,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(controller.value.isPlaying ? 0.25 : 0.55),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white70),
                        ),
                        child: Icon(
                          controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (durSec > 0.5) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: RangeSlider(
              values: RangeValues(widget.trimStartFraction, widget.trimEndFraction),
              min: 0,
              max: 1,
              divisions: 100,
              labels: RangeLabels(
                _fmt(widget.trimStartFraction * durSec),
                _fmt(widget.trimEndFraction * durSec),
              ),
              onChanged: (rv) {
                widget.onTrimChanged(rv.start, rv.end);
              },
            ),
          ),
          Text(
            'Trim: ${_fmt(widget.trimStartFraction * durSec)} — ${_fmt(widget.trimEndFraction * durSec)} · '
            'Full video is uploaded; native trim may be added server-side.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ],
    );
  }

  static String _fmt(double seconds) {
    if (seconds.isNaN || seconds < 0) return '0:00';
    final s = seconds.floor();
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }
}

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../models/schedule_post_media_slot.dart';
import 'post_creation_session.dart';

/// Step 1: device gallery grid, multi-select, count, Next. Video via app bar.
class PostCreationStep1Gallery extends StatefulWidget {
  const PostCreationStep1Gallery({
    super.key,
    required this.session,
    required this.onStep1Complete,
  });

  final PostCreationSession session;
  final VoidCallback onStep1Complete;

  @override
  State<PostCreationStep1Gallery> createState() => _PostCreationStep1GalleryState();
}

class _PostCreationStep1GalleryState extends State<PostCreationStep1Gallery> {
  static const int _kMaxSelection = 10;
  static const int _kPageSize = 60;

  List<AssetEntity> _assets = [];
  final List<String> _selectionOrder = [];
  bool _loading = true;
  String? _error;
  int _page = 0;
  bool _hasMore = true;
  final ScrollController _scroll = ScrollController();

  String _newId() => '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(999999)}';

  String _fmtDur(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loading) return;
    final max = _scroll.position.maxScrollExtent;
    if (max <= 0) return;
    if (_scroll.position.pixels > max * 0.8) _loadMore();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ps = await PhotoManager.requestPermissionExtend();
      if (ps != PermissionState.authorized && ps != PermissionState.limited) {
        setState(() {
          _loading = false;
          _error = 'denied';
        });
        return;
      }
      final paths = await PhotoManager.getAssetPathList(
        onlyAll: true,
        type: RequestType.common, // photos AND videos together (Instagram-style)
      );
      if (paths.isEmpty) {
        setState(() => _loading = false);
        return;
      }
      final recent = paths.first;
      final total = await recent.assetCountAsync;
      final take = total < _kPageSize ? total : _kPageSize;
      final list = await recent.getAssetListPaged(page: 0, size: take);
      setState(() {
        _assets = list;
        _page = 0;
        _hasMore = total > list.length;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loading) return;
    final paths = await PhotoManager.getAssetPathList(onlyAll: true, type: RequestType.common);
    if (paths.isEmpty) return;
    final recent = paths.first;
    final total = await recent.assetCountAsync;
    final nextPage = _page + 1;
    final offset = nextPage * _kPageSize;
    if (offset >= total) {
      setState(() => _hasMore = false);
      return;
    }
    setState(() => _loading = true);
    final list = await recent.getAssetListPaged(page: nextPage, size: _kPageSize);
    setState(() {
      _assets = [..._assets, ...list];
      _page = nextPage;
      _hasMore = offset + list.length < total;
      _loading = false;
    });
  }

  void _toggle(AssetEntity e) {
    // A post is EITHER photos OR one video. Tapping a video goes straight to the
    // video editor; tapping photos multi-selects.
    if (e.type == AssetType.video) {
      _selectVideo(e);
      return;
    }
    final id = e.id;
    setState(() {
      if (_selectionOrder.contains(id)) {
        _selectionOrder.remove(id);
      } else {
        if (_selectionOrder.length >= _kMaxSelection) return;
        _selectionOrder.add(id);
      }
    });
  }

  Future<void> _selectVideo(AssetEntity e) async {
    setState(() => _loading = true);
    try {
      final f = await e.file;
      if (f == null || !mounted) return;
      widget.session.imageSlots.clear();
      widget.session.videoFile = f;
      widget.session.trimStart = 0;
      widget.session.trimEnd = 1;
      if (!mounted) return;
      widget.onStep1Complete();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fallbackPicker() async {
    final files = await ImagePicker().pickMultiImage();
    if (files.isEmpty || !mounted) return;
    widget.session.imageSlots
      ..clear()
      ..addAll(files.map((x) => SchedulePostMediaSlot(id: _newId(), file: File(x.path))));
    widget.session.videoFile = null;
    widget.onStep1Complete();
  }

  static const _videoExts = ['.mp4', '.mov', '.mkv', '.webm', '.avi', '.3gp', '.m4v'];
  bool _isVideoPath(String path) {
    final p = path.toLowerCase();
    return _videoExts.any(p.endsWith);
  }

  /// System photo picker showing BOTH photos and videos (no gallery permission
  /// needed). A post is either photos OR one video: if a video is picked we use
  /// it, otherwise the images become a carousel.
  Future<void> _pickFromSystem() async {
    try {
      final items = await ImagePicker().pickMultipleMedia();
      if (items.isEmpty || !mounted) return;
      final videos = items.where((x) => _isVideoPath(x.path)).toList();
      if (videos.isNotEmpty) {
        widget.session.imageSlots.clear();
        widget.session.videoFile = File(videos.first.path);
        widget.session.trimStart = 0;
        widget.session.trimEnd = 1;
        widget.onStep1Complete();
        return;
      }
      final images = items.where((x) => !_isVideoPath(x.path)).toList();
      if (images.isEmpty) return;
      widget.session.imageSlots
        ..clear()
        ..addAll(images.take(_kMaxSelection).map((x) => SchedulePostMediaSlot(id: _newId(), file: File(x.path))));
      widget.session.videoFile = null;
      widget.session.currentImageIndex = 0;
      widget.onStep1Complete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open gallery: $e')));
      }
    }
  }

  Future<void> _commitSelection() async {
    if (_selectionOrder.isEmpty) return;
    setState(() => _loading = true);
    try {
      final slots = <SchedulePostMediaSlot>[];
      for (final id in _selectionOrder) {
        final entity = await AssetEntity.fromId(id);
        if (entity == null) continue;
        final f = await entity.file;
        if (f == null) continue;
        slots.add(SchedulePostMediaSlot(id: _newId(), file: f));
      }
      widget.session.imageSlots
        ..clear()
        ..addAll(slots);
      widget.session.videoFile = null;
      widget.session.currentImageIndex = 0;
      if (!mounted) return;
      widget.onStep1Complete();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              IconButton.filledTonal(
                tooltip: 'Open gallery (photos & videos)',
                onPressed: _loading ? null : _pickFromSystem,
                icon: const Icon(Icons.photo_library_outlined),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectionOrder.isEmpty
                      ? 'Tap photos or a video'
                      : '${_selectionOrder.length} selected',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (_error == 'denied')
                TextButton(
                  onPressed: _fallbackPicker,
                  child: const Text('Use picker'),
                ),
            ],
          ),
        ),
        Expanded(
          child: _buildGrid(theme),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FilledButton(
              onPressed: _loading || _selectionOrder.isEmpty ? null : _commitSelection,
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

  Widget _buildGrid(ThemeData theme) {
    if (_loading && _assets.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _error != 'denied' && _assets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(onPressed: _loadInitial, child: const Text('Retry')),
              TextButton(onPressed: _fallbackPicker, child: const Text('Pick with system dialog')),
            ],
          ),
        ),
      );
    }
    if (_assets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            const Text('No photos found'),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: _fallbackPicker, child: const Text('Choose photos')),
          ],
        ),
      );
    }
    return GridView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: _assets.length + (_hasMore ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i >= _assets.length) {
          return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
        }
        final e = _assets[i];
        final sel = _selectionOrder.contains(e.id);
        final order = sel ? _selectionOrder.indexOf(e.id) + 1 : 0;
        return GestureDetector(
          onTap: () => _toggle(e),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: FutureBuilder<Uint8List?>(
                  future: e.thumbnailDataWithSize(const ThumbnailSize(240, 240)),
                  builder: (ctx, snap) {
                    if (snap.data == null) {
                      return ColoredBox(color: theme.colorScheme.surfaceContainerHighest);
                    }
                    return Image.memory(snap.data!, fit: BoxFit.cover);
                  },
                ),
              ),
              if (e.type == AssetType.video)
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.videocam, color: Colors.white, size: 12),
                        const SizedBox(width: 3),
                        Text(
                          _fmtDur(e.videoDuration),
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              if (sel)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.primary, width: 3),
                    color: Colors.black26,
                  ),
                ),
              if (sel)
                Positioned(
                  top: 6,
                  right: 6,
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(
                      '$order',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

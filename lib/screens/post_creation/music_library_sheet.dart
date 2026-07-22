import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// One royalty-free track in the in-app music library.
class MusicTrack {
  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.category,
    required this.url,
  });

  final String id;
  final String title;
  final String artist;
  final String category;
  final String url;
}

/// Curated royalty-free library (SoundHelix — free to use). Served client-side
/// for now; can move behind a backend endpoint later without UI changes.
const List<MusicTrack> kMusicLibrary = [
  MusicTrack(id: 's1', title: 'Golden Hour', artist: 'InstaFlow', category: 'Trending', url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3'),
  MusicTrack(id: 's2', title: 'City Lights', artist: 'InstaFlow', category: 'Upbeat', url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3'),
  MusicTrack(id: 's3', title: 'Sunset Drive', artist: 'InstaFlow', category: 'Chill', url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3'),
  MusicTrack(id: 's4', title: 'Morning Vibe', artist: 'InstaFlow', category: 'Vlog', url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3'),
  MusicTrack(id: 's5', title: 'Neon Nights', artist: 'InstaFlow', category: 'Upbeat', url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3'),
  MusicTrack(id: 's6', title: 'Deep Focus', artist: 'InstaFlow', category: 'Chill', url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3'),
  MusicTrack(id: 's7', title: 'Adventure', artist: 'InstaFlow', category: 'Cinematic', url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3'),
  MusicTrack(id: 's8', title: 'Feel Good', artist: 'InstaFlow', category: 'Trending', url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3'),
  MusicTrack(id: 's9', title: 'Epic Rise', artist: 'InstaFlow', category: 'Cinematic', url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-9.mp3'),
  MusicTrack(id: 's10', title: 'Daydream', artist: 'InstaFlow', category: 'Vlog', url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-10.mp3'),
  MusicTrack(id: 's11', title: 'Party Starter', artist: 'InstaFlow', category: 'Upbeat', url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-11.mp3'),
  MusicTrack(id: 's12', title: 'Late Night', artist: 'InstaFlow', category: 'Chill', url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-12.mp3'),
];

/// Result returned when the user picks a track: the local file + a display label.
class PickedMusic {
  const PickedMusic(this.file, this.label);
  final File file;
  final String label;
}

/// Instagram-style in-app music picker. Preview streams the track; "Use"
/// downloads it and returns a [PickedMusic]. Returns null if dismissed.
class MusicLibrarySheet extends StatefulWidget {
  const MusicLibrarySheet({super.key});

  @override
  State<MusicLibrarySheet> createState() => _MusicLibrarySheetState();
}

class _MusicLibrarySheetState extends State<MusicLibrarySheet> {
  static const _primary = Color(0xFF7B2CBF);
  final AudioPlayer _player = AudioPlayer();
  final TextEditingController _search = TextEditingController();

  String _query = '';
  String _category = 'All';
  String? _playingId;
  String? _downloadingId;

  List<String> get _categories =>
      ['All', ...{for (final t in kMusicLibrary) t.category}];

  List<MusicTrack> get _filtered => kMusicLibrary.where((t) {
        final okCat = _category == 'All' || t.category == _category;
        final okQ = _query.isEmpty ||
            t.title.toLowerCase().contains(_query) ||
            t.category.toLowerCase().contains(_query);
        return okCat && okQ;
      }).toList();

  @override
  void dispose() {
    _player.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _togglePreview(MusicTrack t) async {
    try {
      if (_playingId == t.id) {
        await _player.stop();
        setState(() => _playingId = null);
        return;
      }
      setState(() => _playingId = t.id);
      await _player.setUrl(t.url);
      await _player.play();
      // When it finishes, clear the playing indicator.
      _player.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed && mounted) {
          setState(() => _playingId = null);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _playingId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not preview this track')),
        );
      }
    }
  }

  Future<void> _use(MusicTrack t) async {
    if (_downloadingId != null) return;
    setState(() => _downloadingId = t.id);
    try {
      await _player.stop();
      final res = await http.get(Uri.parse(t.url)).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) throw Exception('download failed');
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/music_${t.id}.mp3');
      await f.writeAsBytes(res.bodyBytes, flush: true);
      if (!mounted) return;
      Navigator.of(context).pop(PickedMusic(f, '${t.title} • ${t.artist}'));
    } catch (e) {
      if (mounted) {
        setState(() => _downloadingId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add this track. Check your connection.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Icon(Icons.library_music_rounded, color: _primary),
                  SizedBox(width: 8),
                  Text('Music library', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search songs',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final c = _categories[i];
                  final sel = c == _category;
                  return ChoiceChip(
                    label: Text(c),
                    selected: sel,
                    onSelected: (_) => setState(() => _category = c),
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final t = _filtered[i];
                  final playing = _playingId == t.id;
                  final downloading = _downloadingId == t.id;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFEDE3FF),
                      child: IconButton(
                        icon: Icon(playing ? Icons.stop_rounded : Icons.play_arrow_rounded, color: _primary),
                        onPressed: () => _togglePreview(t),
                      ),
                    ),
                    title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${t.artist} • ${t.category}'),
                    trailing: downloading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        : FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _primary,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            onPressed: () => _use(t),
                            child: const Text('Use'),
                          ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

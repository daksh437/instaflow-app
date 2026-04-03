import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../services/history_service.dart';
import '../utils/clipboard_utils.dart';
import 'history_screen.dart';

class HashtagAnalyzerScreen extends StatefulWidget {
  const HashtagAnalyzerScreen({super.key});

  @override
  State<HashtagAnalyzerScreen> createState() => _HashtagAnalyzerScreenState();
}

class _HashtagAnalyzerScreenState extends State<HashtagAnalyzerScreen> {
  final AIService _aiService = AIService();
  final HistoryService _historyService = HistoryService();
  final TextEditingController _captionController = TextEditingController();
  bool _isAnalyzing = false;
  List<String> _hashtags = [];

  Future<void> _analyzeHashtags() async {
    if (_captionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a caption first')),
      );
      return;
    }

    setState(() => _isAnalyzing = true);

    final hashtags = await _aiService.analyzeHashtags(
      caption: _captionController.text,
    );

    setState(() {
      _hashtags = hashtags;
      _isAnalyzing = false;
    });

    // Save to history
    if (hashtags.isNotEmpty) {
      await _historyService.saveHistory(
        serviceType: 'hashtag_analyzer',
        input: _captionController.text,
        output: hashtags.join('\n'),
        metadata: {'count': hashtags.length},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Hashtag Analyzer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HistoryScreen(
                    serviceType: 'hashtag_analyzer',
                    serviceName: 'Hashtag Analyzer History',
                  ),
                ),
              );
            },
            tooltip: 'History',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter your caption to get trending hashtags:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _captionController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Type your caption here...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isAnalyzing ? null : _analyzeHashtags,
              icon: _isAnalyzing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.tag),
              label: Text(_isAnalyzing ? 'Analyzing...' : 'Analyze Hashtags'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            if (_hashtags.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Recommended Hashtags:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _hashtags.map((tag) {
                  return Chip(
                    label: Text(tag),
                    onDeleted: () {
                      setState(() => _hashtags.remove(tag));
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await _historyService.saveHistory(
                          serviceType: 'hashtag_analyzer',
                          input: _captionController.text,
                          output: _hashtags.join('\n'),
                          metadata: {'count': _hashtags.length},
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
                    icon: const Icon(Icons.bookmark_add),
                    label: const Text('Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: const Color(0xFF7B2CBF),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      ClipboardUtils.copyToClipboard(
                        _hashtags.join(' '),
                        context,
                      );
                    },
                    icon: const Icon(Icons.copy_all),
                    label: const Text('Copy All Hashtags'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }
}


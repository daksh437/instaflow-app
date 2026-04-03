import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/history_service.dart';
import '../utils/app_error_handler.dart';
import '../widgets/error_retry_card.dart';

class HistoryScreen extends StatefulWidget {
  final String? serviceType;
  final String serviceName;

  const HistoryScreen({
    super.key,
    this.serviceType,
    required this.serviceName,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final HistoryService _historyService = HistoryService();

  String _getServiceDisplayName(String serviceType) {
    final names = {
      'hashtag_generator': 'Hashtag Generator',
      'bio_maker': 'Bio Maker',
      'viral_hook': 'Viral Hook',
      'caption_generator': 'Caption Generator',
      'ai_caption': 'AI Caption',
      'ai_captions': 'AI Captions',
      'reel_script': 'Reel Script',
      'reels_script': 'Reels Script',
      'rewrite_tool': 'Rewrite Tool',
      'carousel_writer': 'Carousel Writer',
      'comment_reply': 'Comment Reply',
      'ideas': 'Content Ideas',
      'story_ideas': 'Story Ideas',
      'trending_hashtags': 'Trending Hashtags',
      'product_brief': 'Product Brief',
      'dm_auto_reply': 'DM Auto Reply',
      'hashtag_analyzer': 'Hashtag Analyzer',
      'ai_calendar': 'AI Calendar',
      'ai_strategy': 'AI Growth Strategy',
      'niche_analysis': 'Niche Analysis',
    };
    return names[serviceType] ?? serviceType;
  }

  Widget _buildHistoryItem(Map<String, dynamic> history) {
    final createdAt = history['createdAt'] as DateTime?;
    final input = history['input'] as String? ?? '';
    final output = history['output'] as String? ?? '';
    final serviceType = history['serviceType'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getServiceDisplayName(serviceType),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
                if (createdAt != null) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 3,
                    child: Text(
                      DateFormat('MMM dd, yyyy • hh:mm a').format(createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onSelected: (value) async {
                    if (value == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete History'),
                          content: const Text('Are you sure you want to delete this item?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        try {
                          await _historyService.deleteHistory(history['id']);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Deleted successfully')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            AppErrorHandler.log('HistoryDelete', e);
                            AppErrorHandler.show(context, e);
                          }
                        }
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (input.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: (Colors.grey[200] ?? Colors.grey)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.edit_note, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          'Input:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      input.length > 150 ? '${input.substring(0, 150)}...' : input,
                      style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                      maxLines: null,
                      overflow: TextOverflow.visible,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF7B2CBF).withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF7B2CBF).withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF7B2CBF)),
                      const SizedBox(width: 6),
                      Text(
                        'Output:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF7B2CBF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    output,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
                    maxLines: null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: output));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard!')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF7B2CBF),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.serviceName),
        backgroundColor: const Color(0xFF7B2CBF),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: widget.serviceType != null
            ? _historyService.getHistoryByService(widget.serviceType ?? '')
            : _historyService.getAllHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF7B2CBF)),
            );
          }

          if (snapshot.hasError) {
            return ErrorRetryCard(
              error: snapshot.error,
              onRetry: () => setState(() {}),
            );
          }

          final historyList = snapshot.data ?? [];

          if (historyList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No history yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your generated content will appear here',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            color: const Color(0xFF7B2CBF),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: historyList.length,
              itemBuilder: (context, index) {
                return _buildHistoryItem(historyList[index]);
              },
            ),
          );
        },
      ),
    );
  }
}


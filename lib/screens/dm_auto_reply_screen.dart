import 'package:flutter/material.dart';
import '../widgets/ai_tool_base_screen.dart';
import '../services/ai_service.dart';

class DMAutoReplyScreen extends StatelessWidget {
  const DMAutoReplyScreen({super.key});

  Future<String> _generateReply(String message) async {
    final aiService = AIService();
    // Use generateCommentReply for DM replies (similar logic)
    return await aiService.generateCommentReply(message);
  }

  @override
  Widget build(BuildContext context) {
    return AIToolBaseScreen(
      title: 'DM Auto Reply AI',
      hintText: 'Paste the DM message you want to reply to...',
      icon: Icons.chat_bubble_outline_rounded,
      onGenerate: _generateReply,
      serviceType: 'dm_auto_reply',
    );
  }
}


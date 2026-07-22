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
      analyticsToolId: 'dm_auto_reply',
      emptyFieldSnackText: 'Paste a message or tap a quick idea below.',
      generatingButtonLabel: 'Writing reply…',
      progressiveLoadingMessages: const [
        'Reading the DM…',
        'Drafting a friendly reply…',
        'Polishing tone…',
      ],
      quickIdeas: const [
        AiToolQuickIdea(
          label: 'Collab',
          text: 'Hey! Love your content. Would you be open to a collab this month?',
        ),
        AiToolQuickIdea(
          label: 'Thanks',
          text: 'Thank you so much for the support — it really means a lot! 💜',
        ),
        AiToolQuickIdea(
          label: 'Question',
          text: 'Quick question: do you ship to Mumbai? And approx delivery time?',
        ),
        AiToolQuickIdea(
          label: 'Price',
          text: 'Hi! What’s your rate for a 1‑minute reel mention?',
        ),
      ],
      prominentCopy: true,
    );
  }
}


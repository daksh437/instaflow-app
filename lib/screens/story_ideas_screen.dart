import 'package:flutter/material.dart';
import '../widgets/ai_tool_base_screen.dart';
import '../services/ai_service.dart';

class StoryIdeasScreen extends StatelessWidget {
  const StoryIdeasScreen({super.key});

  Future<String> _generateStoryIdea(String input) async {
    final aiService = AIService();
    // Use generateIdeas for story ideas (similar to post ideas)
    final ideas = await aiService.generateIdeas(input);
    return ideas.isNotEmpty 
        ? ideas.join('\n\n') 
        : 'No story ideas generated. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return AIToolBaseScreen(
      title: 'Story Ideas Generator',
      hintText: 'Enter your niche or topic for story ideas...',
      icon: Icons.auto_stories_rounded,
      onGenerate: _generateStoryIdea,
      serviceType: 'story_ideas',
      analyticsToolId: 'story_ideas',
      emptyFieldSnackText: 'Enter a topic or tap a quick idea below.',
      generatingButtonLabel: 'Generating story ideas…',
      progressiveLoadingMessages: const [
        'Understanding your topic…',
        'Brainstorming story angles…',
        'Polishing ideas for Stories…',
      ],
      quickIdeas: const [
        AiToolQuickIdea(
          label: 'BTS',
          text: 'Behind the scenes: how we pack orders — casual, phone camera vibe',
        ),
        AiToolQuickIdea(
          label: 'Poll',
          text: 'Coffee or chai? Quick poll for my community — fun and light',
        ),
        AiToolQuickIdea(
          label: 'Teaser',
          text: 'Teaser for tomorrow’s drop — mystery + countdown sticker energy',
        ),
        AiToolQuickIdea(
          label: 'Tip',
          text: 'One tip that doubled my engagement — educational 3-slide story',
        ),
      ],
      prominentCopy: true,
    );
  }
}


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
    );
  }
}


import 'package:flutter/material.dart';

/// Static screen to show product vision, AI services, WOW features,
/// and subscription strategy based on the provided brief.
class ProductBriefScreen extends StatelessWidget {
  const ProductBriefScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Overview'),
        backgroundColor: const Color(0xFF7B2CBF),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle('Part 1: Product Overview & Vision'),
            _CardWrapper(
              child: _TableBlock(
                headers: const ['Category', 'Description'],
                rows: const [
                  [
                    'Core Goal',
                    'To position Instaflow as the ultimate AI Social Media Manager for Instagram creators, reducing content creation time by 80% and maximizing audience growth.'
                  ],
                  [
                    'Target Audience',
                    'Small to mid-sized creators, micro-influencers, and small businesses who lack the budget for a full-time social media manager but are dedicated to professional growth.'
                  ],
                  [
                    'WOW Factor',
                    'Providing users with a fully-baked, personalized 30-Day AI Growth Strategy and high-converting Viral Reel Scripts.'
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            _SectionTitle('Part 2: Essential AI Services & Feature Set'),
            _CardWrapper(
              child: _TableBlock(
                headers: const ['AI Service', 'Feature Set (What it does)'],
                rows: const [
                  [
                    '1. AI Growth Strategy & Calendar',
                    'Generates a 30-Day Action Plan based on the user\'s niche and targets, including content ideas, suggested posting times, and trend forecasts.'
                  ],
                  [
                    '2. Viral Reel Script Engine',
                    'Drafts complete, high-conversion scripts for Reels including the hook (first 3 seconds), value/body, and a strong CTA.'
                  ],
                  [
                    '3. Caption & Bio Optimizer',
                    'Generates captions and bios optimized for SEO with multiple tones (funny, professional, inspiring) plus smart hashtag clustering.'
                  ],
                  [
                    '4. Community Management Assistant',
                    'Generates quick, on-brand responses for high-volume comments and drafts professional DM opener scripts for collaborations/client outreach.'
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            _SectionTitle('Part 3: Detailed "WOW" Factor Features'),
            _CardWrapper(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _FeatureBlock(
                    title: 'A. The Mega Feature: AI-Powered Growth Campaign (UltraPro)',
                    benefit:
                        'User Benefit: The feeling of having a Personal Digital Strategist.',
                    requirements:
                        'Key Requirements: Deeply understand the user\'s niche and target audience; deliver personalized, concrete tasks (e.g., "Post a tutorial reel using trending sound X at 7 PM IST").',
                  ),
                  SizedBox(height: 14),
                  _FeatureBlock(
                    title: 'B. The Productivity Feature: Reel Script Engine (UltraPro)',
                    benefit:
                        'User Benefit: Solves the most time-consuming part of content creation: scriptwriting.',
                    requirements:
                        'Key Requirements: Scripts should include different viral formats (listicles, story time, tutorials) and suggest specific trending audio.',
                  ),
                  SizedBox(height: 14),
                  _FeatureBlock(
                    title: 'C. The Retention Feature: AI Comment Reply (Pro)',
                    benefit:
                        'User Benefit: Saves significant time on community management while keeping replies professional and personal.',
                    requirements:
                        'Key Requirements: Automatically gauge sentiment/tone of incoming comments and adjust replies accordingly (enthusiastic for positive, empathetic for negative).',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _SectionTitle('Part 4: Subscription & Launch Strategy'),
            _CardWrapper(
              child: _TableBlock(
                headers: const ['Aspect', 'Strategy'],
                rows: const [
                  [
                    'Free TIER (The Hook)',
                    'Offer 3 free Caption Generations per day or 1 free Reel Hook draft so users can experience the output quality before committing.'
                  ],
                  [
                    'Pro TIER (The Value)',
                    'Unlimited Captions/Bios, Comment Reply Assistant, and Best Posting Time Analysis for users who need reliable daily tools.'
                  ],
                  [
                    'Ultra Pro TIER (The Retention)',
                    '30-Day Growth Campaign Builder, Full Reel Scripting, and Media Kit Drafting for growth-minded users seeking strategic guidance.'
                  ],
                  [
                    'Launch Focus',
                    'Use a limited-time introductory offer for Ultra Pro to drive initial high-value subscriptions. Market the “Never run out of content ideas” promise.'
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),
            _SectionTitle('Part 5: Core API Recommendations'),
            _CardWrapper(
              child: _TableBlock(
                headers: const ['Priority Feature', 'Recommended API'],
                rows: const [
                  [
                    'AI Growth Strategy & Calendar (Highest value)',
                    'Google Gemini API (Pro/Ultra) OR OpenAI GPT-4o',
                  ],
                  [
                    'Viral Reel Script Engine',
                    'Google Gemini API (Pro/Ultra) OR OpenAI GPT-4o',
                  ],
                  [
                    'Caption & Bio Optimizer',
                    'OpenAI GPT-4o',
                  ],
                  [
                    'Community Management Assistant',
                    'Google Gemini API',
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),
            _SectionTitle('Part 5B: Detailed API Mapping (New)'),
            _CardWrapper(
              child: _TableBlock(
                headers: const ['Feature Set', 'API Recommendation'],
                rows: const [
                  [
                    '1. AI Growth Strategy & Calendar',
                    'Google Gemini API',
                  ],
                  [
                    '2. Viral Reel/Shorts Script Engine',
                    'OpenAI GPT-4o',
                  ],
                  [
                    '3. Cross-Platform Repurposer',
                    'Google Gemini API',
                  ],
                  [
                    '4. AI Brand Voice Creator',
                    'OpenAI GPT-4o',
                  ],
                  [
                    '5. Post Performance Auditor',
                    'Google Gemini API',
                  ],
                  [
                    '6. Caption & Bio Optimizer',
                    'OpenAI GPT-4o',
                  ],
                  [
                    '7. Comment Reply Assistant',
                    'Google Gemini API',
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),
            _SectionTitle('Part 6: Strategy — Combining APIs for Best Results'),
            _CardWrapper(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Target: Ultra Pro quality output using two high-quality LLMs.',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
                  ),
                  SizedBox(height: 10),
                  _Bullet(
                    title: 'Primary API (e.g., Gemini)',
                    body: 'Use for complex/strategic, high-volume tasks like Growth Campaigns and Reel Scripts.',
                  ),
                  SizedBox(height: 8),
                  _Bullet(
                    title: 'Secondary API (e.g., GPT-4o)',
                    body: 'Use when maximum creativity/fine-tuning is needed, e.g., Caption Optimization and creative marketing copy.',
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Redundancy ensures if one service is down, you can switch the critical flows to the other.',
                    style: TextStyle(color: Color(0xFF333333), height: 1.35),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            _SectionTitle('Part 7: Future Expansion API (Optional, recommended)'),
            _CardWrapper(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Real-Time Data API (Social Media Analytics/Trend)',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Purpose: Feed trending hashtags, popular sounds, viral topics into Gemini/GPT prompts to keep outputs highly relevant.',
                    style: TextStyle(color: Color(0xFF333333), height: 1.35),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'How: Use providers like DataForSEO or similar social trend APIs; inject signals into prompts for growth features.',
                    style: TextStyle(color: Color(0xFF333333), height: 1.35),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            _SectionTitle('Part 8: Reel Script Drafter — Prompt (Gemini/GPT-4o)'),
            _CardWrapper(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'System Instruction',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '“You are an expert Instagram Reel strategist. Generate a high-converting 30-second Reel script based on the user’s input. Ensure maximum viewer retention.”',
                    style: TextStyle(color: Color(0xFF333333), height: 1.35),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'User Inputs Required',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Niche, Topic idea, Desired Outcome, Tone.',
                    style: TextStyle(color: Color(0xFF333333), height: 1.35),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Output Format',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'A. Hook (0–3s) — text overlay + spoken line\n'
                    'B. Body/Value (4–25s) — 3–4 bullets, concise\n'
                    'C. CTA (26–30s) — clear action\n'
                    'D. Suggested Caption — 1–2 lines + 5 trending hashtags\n'
                    'E. Background Music Suggestion — vibe and type of audio',
                    style: TextStyle(color: Color(0xFF333333), height: 1.35),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Sample Prompt',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
                  ),
                  SizedBox(height: 6),
                  SelectableText(
                    'You are an expert Instagram Reel strategist. Generate a high-converting 30-second Reel script based on the user’s input. Ensure maximum viewer retention.\\n\\n'
                    'Niche: {{user_niche}}\\n'
                    'Topic: {{user_topic}}\\n'
                    'Goal: {{user_goal}}\\n'
                    'Tone: {{user_tone}}\\n\\n'
                    'Provide output in this structure:\\n'
                    '**REEL SCRIPT**\\n'
                    'HOOK (0-3s): ... (Text Overlay + Spoken Line)\\n'
                    'BODY/VALUE (4-25s): ... (3-4 bullets)\\n'
                    'CTA (26-30s): ... (Clear action)\\n'
                    '**CAPTION DRAFT**: One-liner + 5 trending hashtags\\n'
                    '**MUSIC SUGGESTION**: Type + vibe',
                    style: TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A1A1A),
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

class _CardWrapper extends StatelessWidget {
  final Widget child;
  const _CardWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shadowColor: Colors.black.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: child,
      ),
    );
  }
}

class _TableBlock extends StatelessWidget {
  final List<String> headers;
  final List<List<String>> rows;
  const _TableBlock({required this.headers, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF4E9FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  headers[0],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  headers[1],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...rows.map(
          (row) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    row[0],
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4A148C),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    row[1],
                    style: const TextStyle(
                      color: Color(0xFF333333),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  final String title;
  final String body;
  const _Bullet({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ', style: TextStyle(color: Color(0xFF4A148C), fontSize: 16)),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Color(0xFF333333), height: 1.4),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
                ),
                TextSpan(text: body),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FeatureBlock extends StatelessWidget {
  final String title;
  final String benefit;
  final String requirements;

  const _FeatureBlock({
    required this.title,
    required this.benefit,
    required this.requirements,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          benefit,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF4A148C),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          requirements,
          style: const TextStyle(
            color: Color(0xFF333333),
            height: 1.35,
          ),
        ),
      ],
    );
  }
}


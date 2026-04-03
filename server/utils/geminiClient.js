const { GoogleGenerativeAI } = require('@google/generative-ai');

const apiKey = process.env.GEMINI_API_KEY;
const modelName = process.env.GEMINI_MODEL || 'gemini-2.5-flash';

let model = null;
if (apiKey) {
  const genAI = new GoogleGenerativeAI(apiKey);
  model = genAI.getGenerativeModel({ model: modelName });
} else {
  console.warn('⚠️ GEMINI_API_KEY is missing. AI calls will fail until set.');
}

// Mock data generator for testing without API key
function getMockResponse(prompt) {
  if (prompt.includes('captions')) {
    return JSON.stringify([
      { caption: 'Living my best life! ✨ Who else can relate? Save this!', hashtags: ['#lifestyle', '#vibes', '#instagood', '#happy', '#life', '#trending', '#viral', '#motivation', '#inspiration', '#selfcare'] },
      { caption: 'Good vibes only! 🌟 What\'s your vibe today? Share with a friend!', hashtags: ['#goodvibes', '#positive', '#energy', '#mood', '#happy', '#trending', '#viral', '#motivation', '#inspiration', '#selfcare'] },
      { caption: 'Making memories one day at a time 📸', hashtags: ['#memories', '#photography', '#moments', '#life', '#captured', '#trending', '#viral', '#motivation', '#inspiration', '#selfcare'] },
      { caption: 'Sunshine and good times ☀️ Save this for later!', hashtags: ['#sunshine', '#goodtimes', '#summer', '#bright', '#happy', '#trending', '#viral', '#motivation', '#inspiration', '#selfcare'] },
      { caption: 'Just another day in paradise 🌴', hashtags: ['#paradise', '#travel', '#adventure', '#explore', '#wanderlust', '#trending', '#viral', '#motivation', '#inspiration', '#selfcare'] },
      { caption: 'Coffee and good vibes ☕✨ Share with a friend!', hashtags: ['#coffee', '#vibes', '#morning', '#energy', '#goodday', '#trending', '#viral', '#motivation', '#inspiration', '#selfcare'] },
      { caption: 'Living in the moment 💫', hashtags: ['#moment', '#present', '#mindful', '#life', '#now', '#trending', '#viral', '#motivation', '#inspiration', '#selfcare'] },
      { caption: 'Creating my own sunshine 🌞 Save this!', hashtags: ['#sunshine', '#create', '#positive', '#energy', '#bright', '#trending', '#viral', '#motivation', '#inspiration', '#selfcare'] },
      { caption: 'Every day is a fresh start 🌅 What are you grateful for today?', hashtags: ['#gratitude', '#mindfulness', '#growth', '#wellness', '#peace', '#trending', '#viral', '#motivation', '#inspiration', '#selfcare'] },
      { caption: 'Small steps, big dreams 🚀 Keep going! Share with a friend!', hashtags: ['#dreams', '#goals', '#motivation', '#success', '#growth', '#trending', '#viral', '#motivation', '#inspiration', '#selfcare'] },
    ]);
  }
  if (prompt.includes('calendar')) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const contentTypes = ['Reel', 'Carousel', 'Story', 'Single Image', 'Meme'];
    const hooks = [
      'POV: You just discovered this game-changing tip',
      'Stop scrolling if you want to 10x your results',
      'This changed everything for me',
      'Nobody talks about this but...',
      'I wish I knew this sooner',
      'The secret nobody tells you',
      'This will blow your mind'
    ];
    const ctas = [
      'Save this post for later!',
      'Share with someone who needs this',
      'Comment your thoughts below',
      'Double tap if you agree',
      'Follow for more tips',
      'Share your experience in comments',
      'Tag someone who needs to see this'
    ];
    return JSON.stringify(days.map((day, index) => ({
      day_of_week: day,
      content_type: contentTypes[index % contentTypes.length],
      hook: hooks[index % hooks.length],
      caption: `${hooks[index % hooks.length]} 💡 This ${day.toLowerCase()} tip will transform your approach. The results speak for themselves!`,
      hashtag_set: [
        '#trending', '#viral', '#instagram', '#content', '#growth',
        '#tips', '#strategy', '#success', '#motivation', '#inspiration',
        '#lifestyle', '#business', '#entrepreneur', '#mindset', '#goals'
      ],
      best_posting_time: ['6 PM IST', '7 PM IST', '8 PM IST', '9 AM IST', '10 AM IST', '11 AM IST', '5 PM IST'][index],
      content_brief: `Create ${contentTypes[index % contentTypes.length].toLowerCase()} content with engaging visuals, clear text overlays, and dynamic transitions that capture attention in the first 3 seconds.`,
      viral_angle: `This post taps into current trends, uses proven engagement hooks, and provides actionable value that encourages saves and shares. The timing aligns with peak engagement hours.`,
      cta: ctas[index % ctas.length]
    })));
  }
  if (prompt.includes('strategy')) {
    return JSON.stringify({
      audience_profile: {
        target_age_groups: ['18-24', '25-34', '35-44'],
        motivations: ['Personal growth', 'Community connection', 'Learning new skills', 'Entertainment', 'Inspiration'],
        psychological_triggers: ['FOMO (Fear of Missing Out)', 'Social proof', 'Aspiration', 'Relatability', 'Achievement'],
        problems_they_want_solved: ['Lack of direction', 'Need for authentic connections', 'Desire for quick wins', 'Information overload', 'Time management']
      },
      growth_plan: {
        reel_strategy: 'Post 3-5 Reels per week focusing on trending audio, quick tips, and behind-the-scenes content. Use first 3 seconds hook, add captions, and include strong CTAs.',
        posting_schedule: 'Post daily at 6 PM IST (peak engagement), with Reels on Mon/Wed/Fri and Feed posts on Tue/Thu/Sat. Stories 2-3 times daily.',
        content_to_avoid: ['Overly promotional posts', 'Low-quality images', 'Generic quotes without context', 'Posts without clear value', 'Inconsistent branding'],
        style_guide: {
          colors: 'Primary: Purple (#7B2CBF), Secondary: Pink (#9D4EDD), Accent: White. Maintain 80/20 rule for brand colors.',
          tone: 'Friendly, authentic, empowering, and slightly playful. Avoid being preachy or overly salesy.',
          personality: 'Approachable expert, relatable friend, inspiring mentor'
        }
      },
      viral_content_ideas: [
        {
          hook: 'POV: You just discovered the secret to 10x growth',
          angle: 'Behind-the-scenes transformation story',
          expected_engagement_reason: 'Relatable struggle + quick win = high saves and shares'
        },
        {
          hook: 'Stop scrolling if you want real results',
          angle: 'Contrarian take on common advice',
          expected_engagement_reason: 'Curiosity gap + controversy = comments and debate'
        },
        {
          hook: 'This changed everything for me in 30 days',
          angle: 'Personal journey with before/after',
          expected_engagement_reason: 'Social proof + transformation = high engagement'
        },
        {
          hook: 'Nobody talks about this but...',
          angle: 'Unpopular truth or hidden insight',
          expected_engagement_reason: 'Exclusive knowledge = saves and shares'
        },
        {
          hook: 'I wish I knew this 5 years ago',
          angle: 'Regret-based learning moment',
          expected_engagement_reason: 'Relatability + value = comments and saves'
        },
        {
          hook: 'The mistake 90% of people make',
          angle: 'Common error + solution',
          expected_engagement_reason: 'Problem-solution format = high engagement'
        },
        {
          hook: 'POV: You\'re about to go viral',
          angle: 'Meta content about going viral',
          expected_engagement_reason: 'Self-referential humor = shares and comments'
        },
        {
          hook: 'This will save you 10 hours per week',
          angle: 'Time-saving hack or tool',
          expected_engagement_reason: 'Practical value = high saves'
        },
        {
          hook: 'The truth nobody wants to hear',
          angle: 'Hard truth or reality check',
          expected_engagement_reason: 'Controversy + truth = debate and shares'
        },
        {
          hook: 'I tried this for 7 days and...',
          angle: 'Challenge or experiment results',
          expected_engagement_reason: 'Curiosity + results = high engagement'
        }
      ],
      analytics_insights: {
        best_posting_times: ['6 PM IST', '7 PM IST', '8 PM IST', '9 AM IST'],
        average_competition_strength: 'Medium-High. Focus on unique angles and consistent quality to stand out.',
        content_gap_opportunities: ['Educational carousels', 'User-generated content', 'Behind-the-scenes Reels', 'Interactive polls and Q&As'],
        posting_frequency_impact: 'Posting 1-2 times daily shows 40% higher engagement vs 3-4 times per week. Quality over quantity is key.'
      },
      hashtag_strategy: {
        low_competition_tags: ['#nichegrowth', '#authenticcontent', '#smallbusinessowner', '#contentcreatorlife', '#socialmediatips', '#growthmindset', '#creativelife', '#digitalmarketing', '#brandbuilding', '#communityfirst'],
        mid_competition_tags: ['#instagramgrowth', '#contentstrategy', '#socialmediamarketing', '#digitalmarketing', '#contentcreator', '#instagramtips', '#socialmediatips', '#marketingstrategy', '#brandgrowth', '#engagement'],
        high_competition_tags: ['#instagram', '#marketing', '#business', '#entrepreneur', '#success', '#motivation', '#inspiration', '#growth', '#viral', '#trending']
      },
      cta_strategy: 'Use varied CTAs: "Save this post", "Share with someone who needs this", "Comment your experience", "Double tap if you agree", "Follow for daily tips". Rotate CTAs to avoid repetition and test which drives most engagement.'
    });
  }
  if (prompt.includes('Analyze the Instagram niche') || prompt.includes('analyze')) {
    return JSON.stringify({
      trend_forecast_30_days: {
        week_1: 'Short-form educational content will dominate. Quick tips and "POV" formats will see 40% higher engagement.',
        week_2: 'Behind-the-scenes and authentic storytelling will peak. Users crave real connections over polished content.',
        week_3: 'Interactive content (polls, Q&As, challenges) will surge. Engagement rates expected to increase by 25%.',
        week_4: 'Trending audio integration will be crucial. Reels with trending sounds will get 3x more reach.',
        overall_trend: 'Shift towards authentic, value-driven content. Educational and relatable content will outperform promotional posts.'
      },
      top_5_viral_patterns: [
        {
          pattern: 'POV (Point of View) storytelling',
          engagement_rate: 'High',
          reason: 'Creates immediate relatability and emotional connection'
        },
        {
          pattern: 'Before/After transformations',
          engagement_rate: 'Very High',
          reason: 'Visual proof + social proof = high saves and shares'
        },
        {
          pattern: 'Quick tip carousels',
          engagement_rate: 'High',
          reason: 'Actionable value in swipeable format increases time spent'
        },
        {
          pattern: 'Trending audio + original hook',
          engagement_rate: 'Very High',
          reason: 'Algorithm boost from trending audio + unique angle'
        },
        {
          pattern: 'Contrarian takes on common advice',
          engagement_rate: 'High',
          reason: 'Creates debate and discussion in comments'
        }
      ],
      best_3_reel_formats: [
        {
          format: 'Quick Tips Reel (15-30 seconds)',
          description: 'Fast-paced, text-overlay format with trending audio. Start with hook, deliver value, end with CTA.',
          expected_performance: 'High reach, good engagement, high save rate'
        },
        {
          format: 'Transformation Story Reel (30-60 seconds)',
          description: 'Before/after visual journey with emotional storytelling. Use trending audio that matches the mood.',
          expected_performance: 'Very high engagement, viral potential, high share rate'
        },
        {
          format: 'Day-in-the-Life Reel (45-90 seconds)',
          description: 'Authentic behind-the-scenes content showing real moments. Use casual, relatable tone.',
          expected_performance: 'Strong engagement, builds connection, good for community building'
        }
      ],
      hashtag_clusters: {
        low_competition: ['#nichegrowth', '#authenticcontent', '#smallbusinessowner', '#contentcreatorlife', '#socialmediatips', '#growthmindset', '#creativelife', '#digitalmarketing', '#brandbuilding', '#communityfirst'],
        mid_competition: ['#instagramgrowth', '#contentstrategy', '#socialmediamarketing', '#digitalmarketing', '#contentcreator', '#instagramtips', '#socialmediatips', '#marketingstrategy', '#brandgrowth', '#engagement'],
        high_competition: ['#instagram', '#marketing', '#business', '#entrepreneur', '#success', '#motivation', '#inspiration', '#growth', '#viral', '#trending']
      },
      untapped_content_ideas: [
        'User-generated content series featuring community members',
        'Myth-busting content debunking common misconceptions',
        'Collaborative content with micro-influencers in the niche',
        'Data-driven insights with original research or surveys',
        'Interactive challenges that encourage participation',
        'Behind-the-scenes of content creation process',
        'Real-time problem-solving sessions',
        'Comparison content (this vs that) with honest opinions'
      ],
      psychological_triggers: [
        {
          trigger: 'FOMO (Fear of Missing Out)',
          application: 'Use phrases like "Don\'t miss out", "Limited time", "Join before it\'s too late"',
          effectiveness: 'High - drives immediate action'
        },
        {
          trigger: 'Social Proof',
          application: 'Showcase testimonials, user results, follower count, engagement metrics',
          effectiveness: 'Very High - builds trust and credibility'
        },
        {
          trigger: 'Curiosity Gap',
          application: 'Start with intriguing hook, reveal answer gradually, use "You won\'t believe..."',
          effectiveness: 'High - increases watch time and engagement'
        },
        {
          trigger: 'Scarcity',
          application: 'Limited offers, exclusive content, time-sensitive deals',
          effectiveness: 'High - creates urgency'
        },
        {
          trigger: 'Relatability',
          application: 'Share struggles, failures, real moments. "POV: You..." format works well',
          effectiveness: 'Very High - builds connection and trust'
        },
        {
          trigger: 'Achievement/Status',
          application: 'Show transformation, success stories, milestones. "I went from X to Y"',
          effectiveness: 'High - inspires and motivates'
        }
      ],
      common_mistakes: [
        {
          mistake: 'Posting inconsistently',
          impact: 'Algorithm penalizes irregular posting. Engagement drops by 30-40%.',
          solution: 'Create content calendar, batch create content, use scheduling tools'
        },
        {
          mistake: 'Ignoring analytics',
          impact: 'Posting blind without understanding what works. Wasting time on low-performing content.',
          solution: 'Review insights weekly, identify top performers, double down on what works'
        },
        {
          mistake: 'Over-promoting',
          impact: 'Audience disengages from constant sales pitches. Engagement rate drops.',
          solution: 'Follow 80/20 rule: 80% value, 20% promotion. Focus on building trust first'
        },
        {
          mistake: 'Copying competitors exactly',
          impact: 'No differentiation, algorithm doesn\'t favor duplicate content.',
          solution: 'Get inspired but add unique angle, personal story, or different perspective'
        },
        {
          mistake: 'Ignoring captions',
          impact: 'Missing opportunity to engage. Captions drive comments and saves.',
          solution: 'Write compelling hooks, ask questions, include CTAs, tell stories'
        },
        {
          mistake: 'Not engaging with audience',
          impact: 'One-way communication kills community. Low engagement rates.',
          solution: 'Reply to comments within 2 hours, engage in DMs, create community content'
        },
        {
          mistake: 'Posting at wrong times',
          impact: 'Content gets buried. Missing peak engagement windows.',
          solution: 'Use analytics to find your audience\'s active hours, test different times'
        }
      ]
    });
  }
  return JSON.stringify({ message: 'Mock response - add GEMINI_API_KEY for real AI' });
}

async function runGemini(prompt, opts = {}) {
  console.log('[runGemini] Starting...');
  
  // If no API key, return mock data
  if (!model) {
    console.log('⚠️ Using mock data (GEMINI_API_KEY not set)');
    await new Promise(resolve => setTimeout(resolve, 500)); // Simulate API delay
    const mockResponse = getMockResponse(prompt);
    console.log('[runGemini] Mock response generated, length:', mockResponse.length);
    return mockResponse;
  }
  
  try {
    console.log('[runGemini] Calling Gemini API with prompt length:', prompt.length);
    
    // Add timeout wrapper for Gemini API call
    const timeoutPromise = new Promise((_, reject) => {
      setTimeout(() => {
        console.log('[runGemini] Timeout reached (10 seconds)');
        reject(new Error('Gemini API timeout after 10 seconds'));
      }, 10000);
    });

    console.log('[runGemini] Creating API promise...');
    const apiPromise = model.generateContent({
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: opts.temperature ?? 0.7,
        maxOutputTokens: opts.maxTokens ?? 1024,
      },
    }).then(result => {
      console.log('[runGemini] API response received');
      return result.response.text();
    });

    console.log('[runGemini] Waiting for API response or timeout...');
    const response = await Promise.race([apiPromise, timeoutPromise]);
    console.log('[runGemini] Response received, length:', response?.length || 0);
    return response;
  } catch (error) {
    console.error('[runGemini] Error:', error.message);
    console.log('[runGemini] Falling back to mock data');
    // Fallback to mock on API error or timeout
    const mockResponse = getMockResponse(prompt);
    console.log('[runGemini] Mock response generated');
    return mockResponse;
  }
}

module.exports = { runGemini };
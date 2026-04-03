const { runGemini } = require('../utils/geminiClient');

function tryParseJson(text, fallback) {
  try {
    return JSON.parse(text);
  } catch {
    return fallback;
  }
}

function captionsPrompt(topic, tone) {
  return `You are an expert Instagram content strategist, copywriter, and viral growth advisor.

Generate 10 extremely high-quality Instagram captions for the topic: "${topic}".

Each caption must:

- Be under 150 characters.
- Have an emotional or story-based hook.
- Use modern IG tone (aesthetic, relatable, viral).
- Contain EXACTLY 10 optimized hashtags.
- Hashtags must be: 30% niche, 30% trending, 40% evergreen.
- Include a soft CTA like "Save this", "Tag someone", "Share this".
- Tone: ${tone}

Return STRICT JSON array:

[
  {
    "caption": "...",
    "hashtags": ["...", "..."]
  }
]`;
}

function calendarPrompt(topic, days) {
  return `You are a professional Instagram strategist.

Create a 7-day content calendar for: "${topic}".

For each day include:

- day_of_week
- content_type (Reel / Carousel / Story / Static Image / Meme)
- hook (strong first line)
- caption (high-quality human-like writing)
- hashtag_set (15 optimized tags)
- best_post_time (IST)
- content_brief (what visuals to create)
- viral_angle (why it will perform well)
- cta (call to action)

Use real IG analytics logic (trends, engagement patterns, niche signals).

Return STRICT JSON array.`;
}

function strategyPrompt(niche) {
  return `You are a senior Instagram growth strategist and analytics expert.

Create a complete growth strategy for the niche "${niche}".

Return JSON with these keys:

{
  "audience_profile": {
    "age_groups": [],
    "psychology": [],
    "pain_points": [],
    "motivations": []
  },
  "growth_plan": {
    "reel_strategy": "",
    "posting_frequency": "",
    "content_style": "",
    "what_to_avoid": ""
  },
  "viral_content_ideas": [
    { "hook": "", "angle": "", "why_it_works": "" }
  ],
  "analytics": {
    "best_times_IST": [],
    "competition_strength": "",
    "content_gap_opportunities": []
  },
  "hashtag_strategy": {
    "low_comp": [],
    "mid_comp": [],
    "high_comp": []
  },
  "cta_strategy": ""
}

Write everything as if you are consulting a real creator.`;
}

function nicheAnalysisPrompt(topic) {
  return `Analyze the Instagram niche "${topic}" and return:

- trend_forecast_30_days: Trend forecast for next 30 days
- top_5_viral_patterns: Top 5 viral content patterns
- best_3_reel_formats: Best 3 reel formats for this niche
- hashtag_clusters: Hashtag clusters based on difficulty (low, mid, high - 10 each)
- untapped_content_ideas: Content ideas that competitors are not using
- psychological_triggers: Engagement boosting psychological triggers
- common_mistakes: Warning: Common mistakes creators make

Return structured JSON.`;
}

async function generateCaptions(req, res) {
  const { topic = 'instagram growth', tone = 'Friendly' } = req.body || {};
  console.log(`[generateCaptions] Request received - topic: ${topic}, tone: ${tone}`);
  try {
    console.log('[generateCaptions] Calling Gemini API...');
    const output = await runGemini(captionsPrompt(topic, tone), { maxTokens: 2048, temperature: 0.8 });
    console.log('[generateCaptions] Gemini response received, length:', output?.length || 0);
    const data = tryParseJson(output, []);
    console.log('[generateCaptions] Sending response with', data?.length || 0, 'items');
    res.json({ success: true, data });
  } catch (error) {
    console.error('[generateCaptions] Error:', error);
    res.status(500).json({ success: false, error: 'Failed to generate captions', details: error.message });
  }
}

async function generateCalendar(req, res) {
  const { topic = 'instagram growth', days = 7 } = req.body || {};
  console.log(`[generateCalendar] Request received - topic: ${topic}, days: ${days}`);
  try {
    console.log('[generateCalendar] Calling Gemini API...');
    const output = await runGemini(calendarPrompt(topic, days), { maxTokens: 4096, temperature: 0.7 });
    console.log('[generateCalendar] Gemini response received');
    const data = tryParseJson(output, []);
    console.log('[generateCalendar] Sending response');
    res.json({ success: true, data });
  } catch (error) {
    console.error('[generateCalendar] Error:', error);
    res.status(500).json({ success: false, error: 'Failed to generate calendar', details: error.message });
  }
}

async function generateStrategy(req, res) {
  const { niche = 'instagram growth' } = req.body || {};
  console.log(`[generateStrategy] Request received - niche: ${niche}`);
  try {
    console.log('[generateStrategy] Calling Gemini API...');
    const output = await runGemini(strategyPrompt(niche), { maxTokens: 4096, temperature: 0.7 });
    console.log('[generateStrategy] Gemini response received');
    const data = tryParseJson(output, {});
    console.log('[generateStrategy] Sending response');
    res.json({ success: true, data });
  } catch (error) {
    console.error('[generateStrategy] Error:', error);
    res.status(500).json({ success: false, error: 'Failed to generate strategy', details: error.message });
  }
}

async function analyzeNiche(req, res) {
  const { topic = 'instagram growth' } = req.body || {};
  console.log(`[analyzeNiche] Request received - topic: ${topic}`);
  try {
    console.log('[analyzeNiche] Calling Gemini API...');
    const output = await runGemini(nicheAnalysisPrompt(topic), { maxTokens: 4096, temperature: 0.7 });
    console.log('[analyzeNiche] Gemini response received');
    const data = tryParseJson(output, {});
    console.log('[analyzeNiche] Sending response');
    res.json({ success: true, data });
  } catch (error) {
    console.error('[analyzeNiche] Error:', error);
    res.status(500).json({ success: false, error: 'Failed to analyze niche', details: error.message });
  }
}

module.exports = {
  generateCaptions,
  generateCalendar,
  generateStrategy,
  analyzeNiche,
};

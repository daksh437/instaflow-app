const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");
const cors = require("cors")({ origin: true });
const { XMLParser } = require("fast-xml-parser");

admin.initializeApp({
  projectId: "insta-flow-7d1a7",
});

// --- CORS Helper ---
function applyCors(req, res) {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  res.set("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return true;
  }
  return false;
}

// --- Get Gemini API Key from Firebase Config ---
function getGeminiApiKey() {
  const config = functions.config().gemini || {};
  const apiKey = config.api_key || process.env.GEMINI_API_KEY;
  
  if (!apiKey) {
    throw new Error(
      "Gemini API key not found. Set it using: firebase functions:config:set gemini.api_key=YOUR_KEY"
    );
  }
  return apiKey;
}

// --- Gemini API Call Helper ---
async function callGeminiAPI(prompt, systemInstruction, temperature = 0.9) {
  const apiKey = getGeminiApiKey();
  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`;
  
  try {
    const response = await axios.post(
      url,
      {
        contents: [
          {
            parts: [{ text: `${systemInstruction}\n\nUser Input: ${prompt}` }],
          },
        ],
        generationConfig: {
          temperature: temperature,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 2048,
        },
      },
      {
        headers: { "Content-Type": "application/json" },
        timeout: 30000,
      }
    );

    const text = response.data?.candidates?.[0]?.content?.parts?.[0]?.text || "";
    return text.trim();
  } catch (error) {
    functions.logger.error("Gemini API Error:", error.response?.data || error.message);
    throw new Error(`Gemini API failed: ${error.message}`);
  }
}

// ========== AI CAPTION GENERATOR ==========
exports.generateCaption = functions
  .region("us-central1")
  .https.onRequest(async (req, res) => {
    cors(req, res, async () => {
      if (applyCors(req, res)) return;

      if (req.method !== "POST") {
        return res.status(405).json({ error: "Method not allowed" });
      }

      try {
        const { topic, style = "trending" } = req.body;

        if (!topic || typeof topic !== "string") {
          return res.status(400).json({ error: "Missing or invalid 'topic' in request body" });
        }

        const stylePrompts = {
          trending:
            "Create a trending, viral-style Instagram caption with current slang and emojis. Make it attention-grabbing and shareable.",
          funny:
            "Create a funny, humorous Instagram caption that will make people laugh. Use wit and humor naturally.",
          emotional:
            "Create an emotional, heartfelt Instagram caption that connects with people's feelings. Be authentic and touching.",
          short:
            "Create a short, punchy one-liner Instagram caption. Maximum 10 words. Make it memorable and impactful.",
          marketing:
            "Create a professional marketing-style Instagram caption that's persuasive and converts. Include a clear call-to-action.",
        };

        const systemInstruction = stylePrompts[style] || stylePrompts.trending;

        const caption = await callGeminiAPI(topic, systemInstruction);

        // Store in user history if uid provided
        if (req.body.uid) {
          try {
            await admin.firestore().collection("users").doc(req.body.uid).collection("generated_content").add({
              type: "caption",
              style: style,
              input: topic,
              output: caption,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          } catch (err) {
            functions.logger.warn("Failed to save history:", err);
          }
        }

        return res.status(200).json({ ok: true, caption, style });
      } catch (error) {
        functions.logger.error("generateCaption error:", error);
        return res.status(500).json({ error: error.message });
      }
    });
  });

// ========== AI HASHTAG GENERATOR ==========
exports.generateHashtags = functions
  .region("us-central1")
  .https.onRequest(async (req, res) => {
    cors(req, res, async () => {
      if (applyCors(req, res)) return;

      if (req.method !== "POST") {
        return res.status(405).json({ error: "Method not allowed" });
      }

      try {
        const { topic } = req.body;

        if (!topic || typeof topic !== "string") {
          return res.status(400).json({ error: "Missing or invalid 'topic' in request body" });
        }

        const systemInstruction = `Generate 20-40 relevant Instagram hashtags for this topic. Mix popular hashtags (1M+ posts) with niche hashtags (10K-500K posts). Format: one hashtag per line, no explanations, just hashtags starting with #.`;

        const hashtags = await callGeminiAPI(topic, systemInstruction);

        return res.status(200).json({ ok: true, hashtags: hashtags.split("\n").filter((h) => h.trim()) });
      } catch (error) {
        functions.logger.error("generateHashtags error:", error);
        return res.status(500).json({ error: error.message });
      }
    });
  });

// ========== AI BIO GENERATOR ==========
exports.generateBio = functions
  .region("us-central1")
  .https.onRequest(async (req, res) => {
    cors(req, res, async () => {
      if (applyCors(req, res)) return;

      if (req.method !== "POST") {
        return res.status(405).json({ error: "Method not allowed" });
      }

      try {
        const { description } = req.body;

        if (!description || typeof description !== "string") {
          return res.status(400).json({ error: "Missing or invalid 'description' in request body" });
        }

        const systemInstruction = `Create an engaging Instagram bio (max 150 characters) based on the user's description. Use 2-3 emojis strategically. Include what they do, their personality, and optionally a call-to-action or contact info. Make it memorable and authentic.`;

        const bio = await callGeminiAPI(description, systemInstruction);

        return res.status(200).json({ ok: true, bio });
      } catch (error) {
        functions.logger.error("generateBio error:", error);
        return res.status(500).json({ error: error.message });
      }
    });
  });

// ========== AI REWRITE TEXT ==========
exports.rewriteText = functions
  .region("us-central1")
  .https.onRequest(async (req, res) => {
    cors(req, res, async () => {
      if (applyCors(req, res)) return;

      if (req.method !== "POST") {
        return res.status(405).json({ error: "Method not allowed" });
      }

      try {
        const { text, tone = "engaging" } = req.body;

        if (!text || typeof text !== "string") {
          return res.status(400).json({ error: "Missing or invalid 'text' in request body" });
        }

        const tonePrompts = {
          simple: "Rewrite this text in a simple, clear, and easy-to-understand way. Remove jargon and complexity.",
          attractive:
            "Rewrite this text to make it more attractive and appealing. Use engaging language that draws people in.",
          seo:
            "Rewrite this text to be SEO-optimized for Instagram. Include relevant keywords naturally while keeping it engaging.",
          engaging:
            "Rewrite this text to be more engaging and interactive. Make people want to read it and take action.",
          professional:
            "Rewrite this text in a professional, polished tone suitable for business or brand accounts.",
        };

        const systemInstruction = tonePrompts[tone] || tonePrompts.engaging;

        const rewritten = await callGeminiAPI(text, systemInstruction);

        return res.status(200).json({ ok: true, rewritten, tone });
      } catch (error) {
        functions.logger.error("rewriteText error:", error);
        return res.status(500).json({ error: error.message });
      }
    });
  });

// ========== AI REEL SCRIPT GENERATOR ==========
exports.generateReelScript = functions
  .region("us-central1")
  .https.onRequest(async (req, res) => {
    cors(req, res, async () => {
      if (applyCors(req, res)) return;

      if (req.method !== "POST") {
        return res.status(405).json({ error: "Method not allowed" });
      }

      try {
        const { topic } = req.body;

        if (!topic || typeof topic !== "string") {
          return res.status(400).json({ error: "Missing or invalid 'topic' in request body" });
        }

        const systemInstruction = `Create a complete Instagram Reels script for the given topic. Structure it as follows:

HOOK (0-3s): Create an attention-grabbing hook that stops the scroll
BODY (3-12s): Develop the main content with clear steps or points
CTA (12-15s): Add a strong call-to-action

Also suggest:
- Caption idea
- 5-10 relevant hashtags

Format it clearly with sections marked.`;

        const script = await callGeminiAPI(topic, systemInstruction);

        return res.status(200).json({ ok: true, script });
      } catch (error) {
        functions.logger.error("generateReelScript error:", error);
        return res.status(500).json({ error: error.message });
      }
    });
  });

// ========== AI POST IDEAS GENERATOR ==========
exports.generatePostIdeas = functions
  .region("us-central1")
  .https.onRequest(async (req, res) => {
    cors(req, res, async () => {
      if (applyCors(req, res)) return;

      if (req.method !== "POST") {
        return res.status(405).json({ error: "Method not allowed" });
      }

      try {
        const { niche } = req.body;

        if (!niche || typeof niche !== "string") {
          return res.status(400).json({ error: "Missing or invalid 'niche' in request body" });
        }

        const systemInstruction = `Generate 10 creative and diverse Instagram post ideas for this niche. Each idea should be specific, actionable, and engaging. Format as a numbered list with brief descriptions. Include mix of: behind-the-scenes, educational, inspirational, entertaining, and user-generated content ideas.`;

        const ideas = await callGeminiAPI(niche, systemInstruction);

        return res.status(200).json({ ok: true, ideas: ideas.split("\n").filter((i) => i.trim()) });
      } catch (error) {
        functions.logger.error("generatePostIdeas error:", error);
        return res.status(500).json({ error: error.message });
      }
    });
  });

// ========== INSTAGRAM STATS SCRAPER ==========
exports.getInstagramStats = functions
  .region("us-central1")
  .https.onRequest(async (req, res) => {
    cors(req, res, async () => {
      if (applyCors(req, res)) return;

      if (req.method !== "POST") {
        return res.status(405).json({ error: "Method not allowed" });
      }

      try {
        const { username } = req.body;

        if (!username || typeof username !== "string") {
          return res.status(400).json({ error: "Missing or invalid 'username' in request body" });
        }

        // Try public Instagram endpoint
        const url = `https://www.instagram.com/${username}/?__a=1&__d=dis`;
        
        try {
          const response = await axios.get(url, {
            headers: {
              "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            },
            timeout: 10000,
          });

          if (response.status === 200 && response.data) {
            const graphql = response.data.graphql || response.data;
            const user = graphql.user || graphql;

            const stats = {
              username: user.username || username,
              fullName: user.full_name || "",
              biography: user.biography || "",
              profilePic: user.profile_pic_url_hd || user.profile_pic_url || "",
              followers: user.edge_followed_by?.count || 0,
              following: user.edge_follow || user.edge_follow?.count || 0,
              postsCount: user.edge_owner_to_timeline_media?.count || 0,
              isVerified: user.is_verified || false,
              posts: (user.edge_owner_to_timeline_media?.edges || []).slice(0, 10).map((edge) => {
                const node = edge.node || {};
                return {
                  id: node.id || "",
                  shortcode: node.shortcode || "",
                  thumbnail: node.thumbnail_src || node.display_url || "",
                  likes: node.edge_liked_by?.count || 0,
                  comments: node.edge_media_to_comment?.count || 0,
                  isVideo: node.is_video || false,
                  timestamp: node.taken_at_timestamp || 0,
                };
              }),
            };

            return res.status(200).json({ ok: true, profile: stats });
          }
        } catch (apiError) {
          functions.logger.warn("Instagram API failed, using fallback:", apiError.message);
        }

        // Fallback: Return mock data
        return res.status(200).json({
          ok: true,
          profile: {
            username: username,
            fullName: "",
            biography: "",
            profilePic: "",
            followers: 0,
            following: 0,
            postsCount: 0,
            isVerified: false,
            posts: [],
          },
          note: "Unable to fetch live data. Please check username.",
        });
      } catch (error) {
        functions.logger.error("getInstagramStats error:", error);
        return res.status(500).json({ error: error.message });
      }
    });
  });

// ========== USER PROFILE CREATION ==========
exports.createUserProfile = functions.auth.user().onCreate(async (user) => {
  try {
    const now = new Date();
    const trialEndsAt = new Date(now);
    trialEndsAt.setDate(trialEndsAt.getDate() + 7); // 7-day trial
    const y = now.getFullYear();
    const m = String(now.getMonth() + 1).padStart(2, "0");
    const d = String(now.getDate()).padStart(2, "0");
    const dailyAiDate = `${y}-${m}-${d}`;

    await admin.firestore().collection("users").doc(user.uid).set({
      uid: user.uid,
      email: user.email || "",
      displayName: user.displayName || "",
      photoURL: user.photoURL || "",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      instaUsername: "",
      subscriptionPlan: "trial",
      trialEndsAt: admin.firestore.Timestamp.fromDate(trialEndsAt),
      planType: "trial",
      trialStartDate: admin.firestore.FieldValue.serverTimestamp(),
      trialEndDate: admin.firestore.Timestamp.fromDate(trialEndsAt),
      dailyAiUsed: 0,
      dailyAiDate,
      totalAiUsed: 0,
    });

    functions.logger.info(`✅ User profile created for ${user.uid}`);
  } catch (error) {
    functions.logger.error(`❌ Error creating user profile: ${error}`);
  }
});

// ========== DAILY VIRAL DROP — Gemini only, scheduled 00:00 UTC ==========
const DAILY_DROPS_COLLECTION = "daily_drops";
const TRENDS_RSS_URL = "https://trends.google.com/trending/rss?geo=US";
const FALLBACK_TRENDS = [
  "day in my life", "get ready with me", "morning routine", "tips and tricks",
  "before and after", "trending sound", "challenge", "relatable", "storytime", "tutorial",
];

/** Fetch trend keywords: Google Trends RSS + safe static fallback. */
async function fetchDailyDropTrendKeywords() {
  try {
    const res = await axios.get(TRENDS_RSS_URL, {
      timeout: 10000,
      headers: { "User-Agent": "Mozilla/5.0 (compatible; InstaFlow/1.0)" },
      validateStatus: () => true,
    });
    if (res.status !== 200 || !res.data) return FALLBACK_TRENDS;
    const parsed = new XMLParser({ ignoreAttributes: false }).parse(res.data);
    const channel = parsed?.rss?.channel || parsed?.feed;
    const items = channel?.item ? (Array.isArray(channel.item) ? channel.item : [channel.item]) : [];
    const titles = items.map((it) => (it.title || "").trim()).filter((t) => t.length > 0 && t.length < 80);
    if (titles.length > 0) return titles.slice(0, 15);
  } catch (err) {
    functions.logger.warn("fetchDailyDropTrendKeywords failed, using fallback:", err.message);
  }
  return FALLBACK_TRENDS;
}

/** Daily Drop prompt template (matches Flutter daily_drop_ai_helper). */
function buildDailyViralDropPrompt(trendList) {
  const trendListStr = (trendList.length > 0 ? trendList : FALLBACK_TRENDS).slice(0, 15).join(", ");
  return `You are a viral Instagram reel strategist.

Using today's trend keywords:
${trendListStr}

Generate ONE daily viral reel execution plan.

Return STRICT JSON:

trend_theme
virality_score
reel_concept
steps (5)
hooks (5)
caption
hashtags (10)
best_post_time
coach_summary

Avoid repeating structure from previous days.`;
}

/** Call Gemini (existing helper only — do not modify). Parse JSON and return. */
async function generateDailyViralDropWithGemini(trendList) {
  const prompt = buildDailyViralDropPrompt(trendList);
  const raw = await callGeminiAPI(prompt, "Return only valid JSON. No markdown, no code fences.", 0.7);
  const cleaned = raw.replace(/```json\s*/gi, "").replace(/```\s*/g, "").trim();
  try {
    return JSON.parse(cleaned);
  } catch (e) {
    const start = raw.indexOf("{");
    const end = raw.lastIndexOf("}") + 1;
    if (start >= 0 && end > start) return JSON.parse(raw.slice(start, end));
    throw new Error("Failed to parse daily drop JSON from Gemini");
  }
}

/** Firestore doc for daily_drops/{YYYY-MM-DD}. Fields exactly as specified. */
function toDailyDropDoc(json) {
  const arr = (v) => (Array.isArray(v) ? v : []);
  const str = (v) => (v != null ? String(v) : "");
  const num = (v) => (typeof v === "number" ? v : parseInt(v, 10) || 0);
  return {
    trend_theme: str(json.trend_theme),
    virality_score: Math.min(100, Math.max(0, num(json.virality_score))),
    concept: str(json.reel_concept || json.concept),
    steps: arr(json.steps).slice(0, 5).map(String),
    hooks: arr(json.hooks).slice(0, 5).map(String),
    caption: str(json.caption),
    hashtags: arr(json.hashtags).slice(0, 10).map((h) => (h.startsWith("#") ? h : "#" + h)),
    best_time: str(json.best_post_time || json.best_time),
    coach_summary: str(json.coach_summary),
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  };
}

/** Scheduled: runs daily at 00:00 UTC. Fetches trends, calls Gemini once, writes daily_drops/{YYYY-MM-DD}. */
exports.generateDailyViralDrop = functions.pubsub
  .schedule("0 0 * * *")
  .timeZone("UTC")
  .onRun(async () => {
    const now = new Date();
    const y = now.getUTCFullYear();
    const m = String(now.getUTCMonth() + 1).padStart(2, "0");
    const d = String(now.getUTCDate()).padStart(2, "0");
    const dateKey = `${y}-${m}-${d}`;

    try {
      const trends = await fetchDailyDropTrendKeywords();
      const json = await generateDailyViralDropWithGemini(trends);
      const data = toDailyDropDoc(json);

      await admin.firestore().collection(DAILY_DROPS_COLLECTION).doc(dateKey).set(data, { merge: true });
      functions.logger.info(`Daily Viral Drop written: ${DAILY_DROPS_COLLECTION}/${dateKey}`);
    } catch (error) {
      functions.logger.error("generateDailyViralDrop failed:", error);
      throw error;
    }
  });

// ========== SUBSCRIPTION REFUND DETECTION (Google Play) ==========
const subscriptionCheck = require("./subscriptionCheck");
exports.checkSubscriptionStatus = subscriptionCheck.checkSubscriptionStatus;
exports.runSubscriptionCheckJob = subscriptionCheck.runSubscriptionCheckJob;

// ========== INSTAGRAM SCHEDULED POSTS (runs every minute) ==========
const SCHEDULED_POSTS_COLLECTION = "scheduled_posts";

/**
 * Placeholder: Publish to Instagram Graph API.
 * TODO: Insert real Instagram API call here (Facebook App ID, Client Token, App Secret).
 * Use accessToken (decrypt first if stored encrypted) and postData.mediaUrl, postData.caption, postData.mediaType.
 * @param {object} postData - { uid, caption, mediaUrl, mediaType }
 * @param {string} accessToken - User's Instagram/Facebook access token (decrypt if stored encrypted)
 * @returns {{ success: boolean, error?: string }}
 */
async function publishToInstagram(postData, accessToken) {
  if (!accessToken || accessToken === "mock_ig_business_token_replace_with_real") {
    functions.logger.warn("publishToInstagram: no real token, skipping publish");
    return { success: false, error: "No valid access token" };
  }
  // TODO: Call Instagram Content Publishing API (Graph API) with accessToken.
  // 1. Create media container (image or video) with media_url and caption
  // 2. Poll container status until ready
  // 3. Publish container to get media publish id
  // 4. Return { success: true } or { success: false, error: "..." }
  functions.logger.info("publishToInstagram placeholder", { mediaType: postData.mediaType, uid: postData.uid });
  return { success: false, error: "Real API not configured" };
}

/** Scheduled: every minute. Process pending scheduled_posts where scheduledAt <= now. */
exports.processScheduledPosts = functions.pubsub
  .schedule("every 1 minutes")
  .timeZone("UTC")
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    try {
      const snapshot = await admin
        .firestore()
        .collection(SCHEDULED_POSTS_COLLECTION)
        .where("status", "==", "pending")
        .where("scheduledAt", "<=", now)
        .limit(50)
        .get();

      for (const doc of snapshot.docs) {
        const data = doc.data();
        const uid = data.uid;
        if (!uid) {
          await doc.ref.update({ status: "failed" });
          continue;
        }
        let accessToken = null;
        try {
          const userDoc = await admin.firestore().collection("users").doc(uid).get();
          const userData = userDoc.data() || {};
          accessToken = userData.accessToken || userData.accessTokenEncrypted;
          // TODO: If token is stored encrypted, decrypt here using Functions config or Secret Manager.
        } catch (err) {
          functions.logger.warn("Failed to get token for user " + uid, err);
        }
        const result = await publishToInstagram(
          {
            uid,
            caption: data.caption || "",
            mediaUrl: data.mediaUrl || "",
            mediaType: data.mediaType || "photo",
          },
          accessToken
        );
        if (result.success) {
          await doc.ref.update({ status: "published" });
          functions.logger.info("Scheduled post published:", doc.id);
        } else {
          await doc.ref.update({ status: "failed" });
          functions.logger.warn("Scheduled post failed:", doc.id, result.error);
        }
      }
    } catch (error) {
      functions.logger.error("processScheduledPosts error:", error);
      throw error;
    }
  });

// ========== USER DELETION CLEANUP ==========
exports.deleteUserData = functions.auth.user().onDelete(async (user) => {
  try {
    const batch = admin.firestore().batch();
    const userRef = admin.firestore().collection("users").doc(user.uid);
    batch.delete(userRef);

    // Delete generated content subcollection
    const contentSnapshot = await admin.firestore().collection("users").doc(user.uid).collection("generated_content").get();
    contentSnapshot.docs.forEach((doc) => batch.delete(doc.ref));

    await batch.commit();
    functions.logger.info(`✅ User data deleted for ${user.uid}`);
  } catch (error) {
    functions.logger.error(`❌ Error deleting user data: ${error}`);
  }
});

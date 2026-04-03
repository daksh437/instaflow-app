# Firebase Cloud Functions - SocialBoost AI

This directory contains the Firebase Cloud Functions backend for SocialBoost AI.

## Features

- **AI Caption Generator** - Generate Instagram captions in multiple styles (Trending, Funny, Emotional, Short, Marketing)
- **AI Hashtag Generator** - Generate 20-40 niche-specific hashtags
- **AI Bio Maker** - Auto-generate Instagram bio ideas
- **AI Reel Script Generator** - Create complete Reels scripts with hooks, body, and CTAs
- **AI Post Ideas** - Suggest 10 creative post ideas for your niche
- **AI Smart Rewrite** - Rewrite text in 5 tones (Simple, Attractive, SEO, Engaging, Professional)
- **Instagram Stats Scraper** - Fetch public Instagram profile data

## Setup Instructions

### 1. Install Dependencies

```bash
cd functions
npm install
```

### 2. Set Gemini API Key

You need to configure the Gemini API key in Firebase Functions config:

```bash
firebase functions:config:set gemini.api_key="YOUR_GEMINI_API_KEY_HERE"
```

**How to get Gemini API Key:**
1. Visit https://makersuite.google.com/app/apikey
2. Sign in with your Google account
3. Create a new API key
4. Copy the key and use it in the command above

### 3. Deploy Functions

```bash
firebase deploy --only functions
```

Or deploy a specific function:

```bash
firebase deploy --only functions:generateCaption
```

### 4. Test Functions Locally (Optional)

```bash
firebase emulators:start --only functions
```

Then update your Flutter app to use `http://localhost:5001/insta-flow-7d1a7/us-central1/` instead of the production URL.

## API Endpoints

All endpoints are POST requests and require CORS headers.

### Base URL
```
https://us-central1-insta-flow-7d1a7.cloudfunctions.net
```

### 1. Generate Caption
**Endpoint:** `POST /generateCaption`

**Request Body:**
```json
{
  "topic": "Your topic or keywords",
  "style": "trending", // Options: trending, funny, emotional, short, marketing
  "uid": "optional_user_id" // For saving to history
}
```

**Response:**
```json
{
  "ok": true,
  "caption": "Generated caption text...",
  "style": "trending"
}
```

### 2. Generate Hashtags
**Endpoint:** `POST /generateHashtags`

**Request Body:**
```json
{
  "topic": "Your topic or content description"
}
```

**Response:**
```json
{
  "ok": true,
  "hashtags": ["#hashtag1", "#hashtag2", ...]
}
```

### 3. Generate Bio
**Endpoint:** `POST /generateBio`

**Request Body:**
```json
{
  "description": "Describe yourself, your interests, or your brand"
}
```

**Response:**
```json
{
  "ok": true,
  "bio": "Generated bio text..."
}
```

### 4. Rewrite Text
**Endpoint:** `POST /rewriteText`

**Request Body:**
```json
{
  "text": "Text to rewrite",
  "tone": "engaging" // Options: simple, attractive, seo, engaging, professional
}
```

**Response:**
```json
{
  "ok": true,
  "rewritten": "Rewritten text...",
  "tone": "engaging"
}
```

### 5. Generate Reel Script
**Endpoint:** `POST /generateReelScript`

**Request Body:**
```json
{
  "topic": "Your Reel topic or idea"
}
```

**Response:**
```json
{
  "ok": true,
  "script": "HOOK: ...\nBODY: ...\nCTA: ..."
}
```

### 6. Generate Post Ideas
**Endpoint:** `POST /generatePostIdeas`

**Request Body:**
```json
{
  "niche": "Your niche or content type"
}
```

**Response:**
```json
{
  "ok": true,
  "ideas": ["Idea 1", "Idea 2", ...]
}
```

### 7. Get Instagram Stats
**Endpoint:** `POST /getInstagramStats`

**Request Body:**
```json
{
  "username": "instagram_username"
}
```

**Response:**
```json
{
  "ok": true,
  "profile": {
    "username": "username",
    "fullName": "Full Name",
    "biography": "Bio text",
    "profilePic": "URL",
    "followers": 1000,
    "following": 500,
    "postsCount": 100,
    "posts": [...]
  }
}
```

## Error Handling

All endpoints return errors in this format:

```json
{
  "error": "Error message here"
}
```

Status codes:
- `200` - Success
- `400` - Bad Request (missing or invalid parameters)
- `405` - Method Not Allowed (must use POST)
- `500` - Internal Server Error

## Firestore Structure

Generated content is stored in:
```
users/{uid}/generated_content/{docId}
```

Each document contains:
- `type`: "caption" | "hashtag" | "bio" | etc.
- `input`: User input
- `output`: Generated content
- `createdAt`: Timestamp
- `style` or `tone` (if applicable)

## Environment Variables

- `GEMINI_API_KEY` - Set via `firebase functions:config:set`

## Notes

- All functions are deployed to `us-central1` region
- Functions use Gemini 1.5 Flash model for fast responses
- Instagram scraping uses public endpoints (respects rate limits)
- CORS is enabled for all endpoints

## Troubleshooting

### Functions not deploying
- Check Node.js version: `node --version` (should be 20 or higher)
- Run `npm install` again
- Check Firebase project: `firebase projects:list`

### API key errors
- Verify key is set: `firebase functions:config:get`
- Re-deploy after setting config: `firebase deploy --only functions`

### CORS errors
- Functions already include CORS headers
- If testing locally, ensure Flutter app uses correct emulator URL


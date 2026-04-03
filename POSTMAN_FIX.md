# 🔧 Fix Postman Request Error

## ❌ Current Error

**Error**: `500 Internal Server Error`  
**Message**: `Unexpected token ' ' '{\"topic\":\"... is not valid JSON`

## 🔍 Problem

Your Postman request body has **single quotes** around the JSON:

```json
'{"topic": "test", "tone": "casual"}'
```

This is **invalid JSON**! The single quotes make it a string, not a JSON object.

## ✅ Solution

### Step 1: Remove Single Quotes

In Postman, change the request body from:

```json
'{"topic": "test", "tone": "casual"}'
```

To:

```json
{
  "topic": "test",
  "tone": "casual"
}
```

### Step 2: Verify Postman Settings

1. **Body tab** → Select **"raw"**
2. **Dropdown** → Select **"JSON"** (not Text)
3. **Remove all single quotes** from the JSON
4. **Send** the request

## 📋 Correct Request Format

### For `/ai/captions` endpoint:

```json
{
  "topic": "fitness",
  "tone": "casual"
}
```

### For `/ai/calendar` endpoint:

```json
{
  "niche": "fitness",
  "duration": 7
}
```

### For `/ai/reels-script` endpoint:

```json
{
  "topic": "fitness tips",
  "duration": "15s",
  "tone": "energetic",
  "audience": "fitness enthusiasts",
  "language": "English"
}
```

## ✅ After Fix

You should get a successful response like:

```json
{
  "success": true,
  "data": {
    "captions": ["Caption 1", "Caption 2", ...]
  }
}
```

## 🧪 Test with cURL (Alternative)

If Postman still has issues, use cURL:

```bash
curl -X POST https://insta-flow-backend.onrender.com/ai/captions \
  -H "Content-Type: application/json" \
  -d '{"topic": "test", "tone": "casual"}'
```

**Note**: In cURL, single quotes are OK because they're shell quotes, not JSON quotes.

---

**Quick Fix**: Remove single quotes from JSON body in Postman! ✅


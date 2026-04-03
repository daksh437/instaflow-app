# ✅ Correct Postman Request Format

## ❌ Current Error

**Error**: `400 Bad Request`  
**Message**: `"Audience is required"`

## 🔍 Problem

The `/ai/captions` endpoint requires an `audience` field, but your request only has `topic` and `tone`.

## ✅ Correct Request Body

### For `/ai/captions` endpoint:

```json
{
  "topic": "fitness",
  "tone": "casual",
  "audience": "fitness enthusiasts",
  "language": "English"
}
```

### Required Fields:

- ✅ `topic` - The topic for captions (required)
- ✅ `tone` - The tone (required)
- ✅ `audience` - Target audience (required)
- ⚪ `language` - Language (optional, defaults to "English")

## 📋 All AI Endpoints Request Formats

### 1. `/ai/captions` - Generate Instagram Captions

```json
{
  "topic": "fitness",
  "tone": "casual",
  "audience": "fitness enthusiasts",
  "language": "English"
}
```

### 2. `/ai/calendar` - Generate Content Calendar

```json
{
  "niche": "fitness",
  "duration": 7
}
```

### 3. `/ai/strategy` - Generate Growth Strategy

```json
{
  "niche": "fitness",
  "currentFollowers": 1000,
  "goal": "grow to 10k followers"
}
```

### 4. `/ai/reels-script` - Generate Reels Script

```json
{
  "topic": "fitness tips",
  "duration": "15s",
  "tone": "energetic",
  "audience": "fitness enthusiasts",
  "language": "English"
}
```

### 5. `/ai/analyze` - Analyze Niche

```json
{
  "niche": "fitness"
}
```

## 🧪 Test in Postman

1. **Method**: POST
2. **URL**: `https://insta-flow-backend.onrender.com/ai/captions`
3. **Headers**: 
   - `Content-Type: application/json`
4. **Body** (raw, JSON):
   ```json
   {
     "topic": "fitness",
     "tone": "casual",
     "audience": "fitness enthusiasts",
     "language": "English"
   }
   ```

## ✅ Expected Response

```json
{
  "success": true,
  "jobId": "CAPTIONS-1234567890-abc123"
}
```

Then poll `/ai/job-status/:jobId` to get results.

---

**Quick Fix**: Add `"audience"` field to your request body! ✅


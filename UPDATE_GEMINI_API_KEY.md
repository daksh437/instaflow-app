# 🔑 Update Gemini API Key in Render

## 📋 Your New API Key

```
AIzaSyCZafpOScQQ1sKviVzlgJFX5EyqSebfI_8
```

---

## 🚀 Update in Render Dashboard

### Step 1: Go to Render Dashboard

1. Visit [https://dashboard.render.com](https://dashboard.render.com)
2. Sign in to your account
3. Find your service: **insta-flow-backend**

### Step 2: Update Environment Variable

1. Click on your service: **insta-flow-backend**
2. Go to **Environment** tab (left sidebar)
3. Find the variable: `GEMINI_API_KEY`
4. Click **Edit** (or **Add** if it doesn't exist)
5. **Value**: Paste your new API key:
   ```
   AIzaSyCZafpOScQQ1sKviVzlgJFX5EyqSebfI_8
   ```
6. Click **Save Changes**

### Step 3: Redeploy (If Needed)

Render will automatically redeploy when you update environment variables. If not:

1. Go to **Manual Deploy** tab
2. Click **Deploy latest commit**
3. Wait for deployment to complete

### Step 4: Verify

1. Check **Logs** tab
2. Look for: `🤖 Gemini AI: REAL MODE`
3. Test an AI endpoint:
   ```bash
   curl -X POST https://insta-flow-backend.onrender.com/ai/captions \
     -H "Content-Type: application/json" \
     -d '{"topic": "test", "tone": "casual"}'
   ```

---

## ✅ Environment Variables Checklist

Make sure these are set in Render:

| Variable | Value | Status |
|----------|-------|--------|
| `GEMINI_API_KEY` | `AIzaSyCZafpOScQQ1sKviVzlgJFX5EyqSebfI_8` | ✅ Update this |
| `PORT` | `10000` | ✅ |
| `NODE_ENV` | `production` | ✅ |
| `GOOGLE_CLIENT_ID` | Your client ID | ✅ |
| `GOOGLE_CLIENT_SECRET` | Your client secret | ✅ |
| `GOOGLE_REDIRECT_URI` | Your redirect URI | ✅ |
| `CORS_ORIGINS` | `*` | ✅ |

---

## 🔒 Security Best Practices

### ✅ DO:
- Store API keys in Render environment variables
- Use different keys for development and production
- Rotate keys regularly
- Keep keys secret

### ❌ DON'T:
- Commit API keys to Git
- Hardcode keys in source code
- Share keys publicly
- Use same key for multiple projects

---

## 🧪 Test After Update

### 1. Health Check
```bash
curl https://insta-flow-backend.onrender.com/health
```

### 2. Test AI Caption Endpoint
```bash
curl -X POST https://insta-flow-backend.onrender.com/ai/captions \
  -H "Content-Type: application/json" \
  -d '{
    "topic": "sunset",
    "tone": "casual"
  }'
```

### 3. Check Logs
In Render dashboard → **Logs** tab, you should see:
```
🤖 Gemini AI: REAL MODE
🤖 Gemini Model: gemini-1.5-flash
```

---

## 🐛 Troubleshooting

### API Key Not Working

1. **Verify Key Format**: Should start with `AIzaSy`
2. **Check Logs**: Look for error messages
3. **Verify Variable Name**: Must be exactly `GEMINI_API_KEY`
4. **Check Quotas**: Ensure API key has quota remaining

### Still Getting Mock Data

1. **Check Logs**: Should say "REAL MODE" not "MOCK MODE"
2. **Verify Environment Variable**: Must be set in Render
3. **Redeploy**: Try manual redeploy after updating

### 403 Permission Denied

1. **Check API Key**: Ensure it's valid and active
2. **Enable Gemini API**: In Google Cloud Console
3. **Check Billing**: Some APIs require billing enabled

---

## 📝 Quick Reference

**Render Dashboard**: https://dashboard.render.com  
**Service URL**: https://insta-flow-backend.onrender.com  
**API Key**: `AIzaSyCZafpOScQQ1sKviVzlgJFX5EyqSebfI_8`

---

**Last Updated**: December 2024


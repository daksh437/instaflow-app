# 🚀 Backend Deployment Guide - Render

## ✅ Pre-Deployment Checklist

- [ ] Code pushed to GitHub
- [ ] Environment variables ready
- [ ] Google OAuth redirect URI updated
- [ ] Render account created

---

## 📋 Step 1: Prepare GitHub Repository

### 1.1 Ensure Code is Committed

```bash
cd backend
git add .
git commit -m "Prepare for deployment"
git push origin main
```

### 1.2 Verify .gitignore

Make sure `.env` is in `.gitignore`:
```
.env
node_modules/
data/tokens.json
```

---

## 📋 Step 2: Create Render Web Service

### 2.1 Go to Render Dashboard

1. Visit [https://dashboard.render.com](https://dashboard.render.com)
2. Sign in or create account
3. Click **"New +"** → **"Web Service"**

### 2.2 Connect Repository

1. **Connect GitHub** (if not connected)
2. **Select Repository**: Choose your repository
3. **Branch**: `main` (or your default branch)

### 2.3 Configure Service

**Basic Settings:**
- **Name**: `instaflow-backend` (or your preferred name)
- **Region**: Choose closest to your users
- **Branch**: `main`
- **Root Directory**: `backend` (if backend is in subdirectory)

**Build & Deploy:**
- **Environment**: `Node`
- **Build Command**: `npm install`
- **Start Command**: `npm start`

**Advanced Settings:**
- **Auto-Deploy**: `Yes` (deploys on every push)
- **Health Check Path**: `/health`

---

## 📋 Step 3: Set Environment Variables

In Render dashboard, go to **Environment** tab and add:

### Required Variables:

```env
PORT=10000
NODE_ENV=production
GEMINI_API_KEY=AIzaSyDJf_BcX9j2s-elirtIYVAjldUCe9DjYXo
GOOGLE_CLIENT_ID=your_google_client_id_here
GOOGLE_CLIENT_SECRET=your_google_client_secret_here
GOOGLE_REDIRECT_URI=https://instaflow-backend.onrender.com/auth/callback
CORS_ORIGINS=*
```

### Variable Details:

| Variable | Description | Example |
|----------|-------------|---------|
| `PORT` | Server port (Render auto-sets, but keep as fallback) | `10000` |
| `NODE_ENV` | Environment mode | `production` |
| `GEMINI_API_KEY` | Your Gemini API key | `AIzaSy...` |
| `GOOGLE_CLIENT_ID` | Google OAuth Client ID | `xxx.apps.googleusercontent.com` |
| `GOOGLE_CLIENT_SECRET` | Google OAuth Client Secret | `GOCSPX-xxx` |
| `GOOGLE_REDIRECT_URI` | OAuth callback URL (use your Render URL) | `https://instaflow-backend.onrender.com/auth/callback` |
| `CORS_ORIGINS` | Allowed origins (use `*` for all) | `*` |

**Important:**
- Replace `instaflow-backend.onrender.com` with your actual Render service URL
- Get `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` from Google Cloud Console

---

## 📋 Step 4: Update Google OAuth Redirect URI

### 4.1 Go to Google Cloud Console

1. Visit [Google Cloud Console](https://console.cloud.google.com)
2. Select your project
3. Go to **APIs & Services** → **Credentials**

### 4.2 Update OAuth Client

1. Click on your **OAuth 2.0 Client ID**
2. Under **Authorized redirect URIs**, add:
   ```
   https://instaflow-backend.onrender.com/auth/callback
   ```
   (Replace with your actual Render URL)
3. Click **Save**

---

## 📋 Step 5: Deploy

### 5.1 Create Service

1. Click **"Create Web Service"** in Render
2. Render will automatically:
   - Clone your repository
   - Install dependencies (`npm install`)
   - Start server (`npm start`)
3. Wait 2-3 minutes for deployment

### 5.2 Monitor Deployment

- Watch **Logs** tab for build progress
- Check for any errors
- Wait for "Your service is live" message

---

## 📋 Step 6: Verify Deployment

### 6.1 Health Check

Visit your service URL:
```
https://instaflow-backend.onrender.com/health
```

Should return:
```json
{
  "status": "ok",
  "success": true,
  "message": "OK"
}
```

### 6.2 Test Root Endpoint

```
https://instaflow-backend.onrender.com/
```

Should return:
```json
{
  "success": true,
  "message": "InstaFlow Backend API"
}
```

### 6.3 Test AI Endpoint (Optional)

```bash
curl -X POST https://instaflow-backend.onrender.com/ai/captions \
  -H "Content-Type: application/json" \
  -d '{"topic": "test", "tone": "casual"}'
```

---

## 📋 Step 7: Update Flutter App

### 7.1 Update API Base URL

In your Flutter app, update `lib/services/api_service.dart`:

```dart
static const String baseUrl = 'https://instaflow-backend.onrender.com';
```

(Replace with your actual Render URL)

---

## 🔧 Troubleshooting

### Deployment Fails

1. **Check Logs**: Go to Render dashboard → Logs tab
2. **Verify Environment Variables**: All required vars must be set
3. **Check Build Command**: Should be `npm install`
4. **Check Start Command**: Should be `npm start`
5. **Node Version**: Ensure Node 16+ (Render auto-detects)

### Server Not Starting

1. **Check PORT**: Render auto-sets PORT, but verify it's used
2. **Check Logs**: Look for error messages
3. **Verify Dependencies**: All packages in `package.json`
4. **Check app.js**: Main file should be `app.js` (not `index.js`)

### CORS Errors

1. **Verify CORS_ORIGINS**: Set to `*` or specific domains
2. **Check Flutter baseUrl**: Must match Render URL
3. **Verify HTTPS**: Use `https://` not `http://`

### OAuth Not Working

1. **Check Redirect URI**: Must match exactly in:
   - Render environment variables
   - Google Cloud Console
2. **Verify Client ID/Secret**: Must be correct
3. **Check HTTPS**: OAuth requires HTTPS in production

---

## 📊 Monitoring

### Render Dashboard

- **Metrics**: CPU, Memory, Network usage
- **Logs**: Real-time server logs
- **Events**: Deployment history

### Health Checks

Render automatically checks `/health` endpoint every few seconds.

---

## 🔄 Auto-Deploy

Render automatically deploys when you push to your connected branch.

To deploy manually:
1. Go to Render dashboard
2. Click **"Manual Deploy"**
3. Select branch
4. Click **"Deploy"**

---

## 💰 Free Tier Limits

- **512 MB RAM**
- **0.1 CPU**
- **Spins down after 15 min inactivity** (wakes on request)
- **First request may be slow** (cold start)

**Upgrade to paid plan** for:
- Always-on service
- More resources
- Faster response times

---

## ✅ Deployment Complete!

Your backend is now live at:
```
https://instaflow-backend.onrender.com
```

**Next Steps:**
1. Update Flutter app with new backend URL
2. Test all endpoints
3. Monitor logs for any issues

---

**Last Updated**: December 2024


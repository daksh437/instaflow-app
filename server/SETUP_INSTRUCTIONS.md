# Backend Server Setup - Quick Start

## ✅ What's Done

1. ✅ Dependencies installed (`npm install`)
2. ✅ `.env` file created from `env.example`
3. ✅ Server starting...

## ⚠️ IMPORTANT: Configure .env File

Edit `server/.env` and add your actual credentials:

### 1. Google OAuth (for Calendar integration)

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a project or select existing
3. Enable "Google Calendar API"
4. Go to "Credentials" → "Create Credentials" → "OAuth 2.0 Client ID"
5. Application type: "Web application"
6. Authorized redirect URIs: `http://localhost:8080/auth/callback`
7. Copy Client ID and Secret to `.env`:

```env
GOOGLE_CLIENT_ID=your-actual-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-actual-client-secret
```

### 2. Gemini API Key

1. Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Create API key
3. Add to `.env`:

```env
GEMINI_API_KEY=your-actual-gemini-api-key
```

### 3. CORS Origins (for Flutter)

Update with your Flutter app origins:

```env
CORS_ORIGINS=http://localhost:8080,http://10.0.2.2:8080
```

## 🚀 Start Server

```bash
cd server
npm run dev
```

Server will run on `http://localhost:8080`

## ✅ Test Server

Open browser: `http://localhost:8080/health`

Should see: `{"success":true,"message":"OK"}`

## 📱 Flutter App

The Flutter app is already configured to connect to:
- **Android Emulator:** `http://10.0.2.2:8080` ✅
- **iOS Simulator:** `http://localhost:8080` ✅

## 🔧 Current Status

- ✅ Dependencies installed
- ✅ .env file created (needs your credentials)
- ⚠️ Add Google OAuth credentials
- ⚠️ Add Gemini API key
- ✅ Server ready to start

## 🐛 Troubleshooting

### "Cannot find module"
→ Run `npm install` in server folder

### "Connection refused" in Flutter
→ Make sure server is running: `npm run dev`
→ Check port 8080 is not in use

### "Invalid credentials"
→ Update `.env` with actual Google OAuth and Gemini keys


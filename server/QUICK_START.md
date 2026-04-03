# 🚀 Quick Start - Test Without API Keys!

## ✅ Good News!

Server ab **MOCK MODE** mein kaam karega bina API keys ke! Aap pehle test kar sakte ho, phir baad mein real credentials add kar sakte ho.

## 🎯 Step 1: Start Server (No API Keys Needed!)

```bash
cd server
npm run dev
```

Server `http://localhost:8080` pe start hoga! ✅

## 🧪 Step 2: Test Flutter App

1. Flutter app run karo: `flutter run`
2. "AI Marketing Tools" section mein jao
3. **AI Captions** try karo - Mock data aayega! ✅
4. **AI Calendar** try karo - Mock calendar aayega! ✅
5. **AI Strategy** try karo - Mock strategy aayega! ✅

## ⚠️ Google Calendar Connect

Google Calendar connect karne ke liye real OAuth credentials chahiye. Lekin aap bina iske bhi AI features test kar sakte ho!

## 🔑 Baad Mein Real API Keys Add Karne Ke Liye

### Gemini API (AI Features):
1. [Google AI Studio](https://makersuite.google.com/app/apikey) pe jao
2. API key generate karo
3. `server/.env` mein add karo:
   ```
   GEMINI_API_KEY=your-actual-key-here
   ```
4. Server restart karo

### Google OAuth (Calendar):
1. [Google Cloud Console](https://console.cloud.google.com/)
2. Project create karo
3. "Google Calendar API" enable karo
4. OAuth 2.0 Client ID create karo
5. Redirect URI: `http://localhost:8080/auth/callback`
6. `server/.env` mein add karo:
   ```
   GOOGLE_CLIENT_ID=your-client-id
   GOOGLE_CLIENT_SECRET=your-client-secret
   ```
7. Server restart karo

## ✅ Current Status

- ✅ Server runs without API keys (mock mode)
- ✅ AI Captions works (mock data)
- ✅ AI Calendar works (mock data)
- ✅ AI Strategy works (mock data)
- ⚠️ Google Calendar needs real OAuth (but not required for testing)

## 🎉 Ab Test Karo!

Server start karo aur Flutter app mein AI features try karo - sab kaam karega! 🚀


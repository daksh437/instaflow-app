# InstaFlow AI Marketing Tools - Setup Guide

## ✅ What's Been Added

### Backend (Already Complete)
- ✅ Google OAuth routes (`/auth/url`, `/auth/callback`, `/auth/status`)
- ✅ Gemini AI endpoints (`/ai/captions`, `/ai/calendar`, `/ai/strategy`)
- ✅ Google Calendar integration (`/calendar/create`)
- ✅ Firebase UID support via `x-user-uid` header
- ✅ Token storage in `server/data/tokens.json`

### Flutter App (New Screens Added)
- ✅ `ai_captions_screen.dart` - Generate 8 captions with hashtags
- ✅ `ai_calendar_screen.dart` - Generate 7-day content calendar
- ✅ `ai_strategy_screen.dart` - Generate growth strategy
- ✅ `google_connect_screen.dart` - Connect Google Calendar
- ✅ Updated `home_screen.dart` - Added "AI Marketing Tools" section
- ✅ Updated `main.dart` - Added routes for new screens
- ✅ Updated `api_service.dart` - All methods ready (uses Firebase UID)

## 🚀 Setup Instructions

### 1. Backend Setup

```bash
cd server

# Install dependencies (if not already done)
npm install

# Copy and configure environment
cp env.example .env
```

Edit `server/.env`:
```env
PORT=8080
GOOGLE_CLIENT_ID=your-google-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-google-client-secret
GOOGLE_REDIRECT_URI=http://localhost:8080/auth/callback
GEMINI_API_KEY=your_gemini_api_key
CORS_ORIGINS=http://localhost:3000,http://localhost:5173
TOKEN_STORE_PATH=./data/tokens.json
```

**Important:** 
- Add `http://localhost:8080/auth/callback` to your Google OAuth authorized redirect URIs in Google Cloud Console
- Get Gemini API key from: https://makersuite.google.com/app/apikey

```bash
# Start backend
npm run dev
# or
npm start
```

### 2. Flutter App Setup

The Flutter app is already configured. Just ensure:

1. **Update backend URL** in `lib/services/api_service.dart` if your backend runs on a different port:
   ```dart
   static const String baseUrl = 'http://localhost:8080'; // Change if needed
   ```

2. **For Android Emulator**, use `http://10.0.2.2:8080` instead:
   ```dart
   static const String baseUrl = 'http://10.0.2.2:8080';
   ```

3. **For Physical Device**, use your computer's IP:
   ```dart
   static const String baseUrl = 'http://192.168.1.X:8080'; // Your local IP
   ```

### 3. Run the App

```bash
# Flutter
flutter pub get
flutter run

# Backend (in separate terminal)
cd server
npm run dev
```

## 📱 How to Use

### 1. AI Captions
- Navigate: Home → AI Marketing Tools → AI Captions
- Enter topic and select tone
- Generate 8 captions with hashtags
- Copy any caption to clipboard

### 2. AI Calendar Generator
- Navigate: Home → AI Marketing Tools → AI Calendar Generator
- Enter topic
- Generate 7-day content calendar
- Click calendar icon to schedule to Google Calendar (requires connection)

### 3. AI Growth Strategy
- Navigate: Home → AI Marketing Tools → AI Growth Strategy
- Enter niche
- Get complete strategy with overview, cadence, ideas, KPIs, A/B tests

### 4. Connect Google Calendar
- Navigate: Home → AI Marketing Tools → Connect Google Calendar
- Click "Connect Google Calendar"
- Authorize in browser
- Return to app and refresh status

## 🔧 Backend Endpoints

All endpoints require Firebase UID in `x-user-uid` header (automatically sent by `ApiService`):

### Auth
- `GET /auth/url` - Get Google OAuth URL
- `GET /auth/callback?code=...` - Exchange code for tokens
- `GET /auth/status` - Check connection status

### AI
- `POST /ai/captions` - Body: `{ topic, tone }`
- `POST /ai/calendar` - Body: `{ topic, days }`
- `POST /ai/strategy` - Body: `{ niche }`

### Calendar
- `POST /calendar/create` - Body: `{ title, description, startDateTime, endDateTime }`

## 🎨 UI Features

- Purple gradient theme matching InstaFlow design
- Smooth animations and transitions
- Copy-to-clipboard functionality
- Loading states
- Error handling with user-friendly messages
- Responsive cards and layouts

## 🔐 Security Notes

- Firebase UID is used for user identification
- Tokens stored in `server/data/tokens.json` (replace with DB in production)
- CORS configured for Flutter/web origins
- All API calls include authentication headers

## 🐛 Troubleshooting

1. **Backend not connecting:**
   - Check backend is running on correct port
   - Verify CORS_ORIGINS includes your Flutter app origin
   - For Android emulator, use `10.0.2.2:8080`

2. **Google OAuth not working:**
   - Verify redirect URI matches exactly in Google Cloud Console
   - Check `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` in `.env`

3. **Gemini API errors:**
   - Verify `GEMINI_API_KEY` is set correctly
   - Check API quota/limits

4. **Calendar not scheduling:**
   - Ensure user is connected to Google Calendar first
   - Check Firebase UID is being sent in headers

## ✅ All Files Created/Updated

### New Files:
- `lib/screens/ai_captions_screen.dart`
- `lib/screens/ai_calendar_screen.dart`
- `lib/screens/ai_strategy_screen.dart`
- `lib/screens/google_connect_screen.dart`

### Updated Files:
- `lib/screens/home_screen.dart` - Added AI Marketing Tools section
- `lib/main.dart` - Added routes
- `lib/services/api_service.dart` - Already had all methods (verified)

### Backend (Already Complete):
- `server/routes/auth.js`
- `server/routes/gemini.js`
- `server/routes/calendar.js`
- `server/controllers/authController.js`
- `server/controllers/geminiController.js`
- `server/controllers/calendarController.js`
- `server/utils/oauthClient.js`
- `server/utils/geminiClient.js`
- `server/utils/tokenStore.js`

Everything is ready to use! 🎉


# Firebase Setup Guide - SocialBoost AI

Complete guide to set up Firebase backend for SocialBoost AI.

## Prerequisites

1. Firebase account (https://firebase.google.com)
2. Node.js 20+ installed
3. Firebase CLI installed: `npm install -g firebase-tools`

## Step-by-Step Setup

### 1. Firebase Project Setup

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a new project (or use existing: `insta-flow-7d1a7`)
3. Enable **Firestore Database** (Start in test mode for now)
4. Enable **Authentication** (Email/Password and Google Sign-In)
5. Enable **Cloud Functions** (requires Blaze/Paid plan)
6. Enable **Firebase Hosting** (optional)

### 2. Install Firebase CLI

```bash
npm install -g firebase-tools
```

### 3. Login to Firebase

```bash
firebase login
```

### 4. Initialize Firebase (if not already done)

```bash
firebase init
```

Select:
- ✅ Functions
- ✅ Firestore
- ✅ Hosting (optional)

### 5. Set Gemini API Key

**Get your API key:**
1. Visit https://makersuite.google.com/app/apikey
2. Sign in with Google
3. Create API key
4. Copy the key

**Set in Firebase:**
```bash
firebase functions:config:set gemini.api_key="YOUR_GEMINI_API_KEY"
```

**Verify:**
```bash
firebase functions:config:get
```

### 6. Deploy Functions

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

### 7. Update Flutter App

The app should automatically use:
```
https://us-central1-insta-flow-7d1a7.cloudfunctions.net
```

If you're using a different project, update `lib/services/ai_service.dart`:
```dart
static const String _functionsBaseUrl = 'YOUR_FUNCTIONS_URL';
```

### 8. Firestore Security Rules

Update `firestore.rules`:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // Generated content subcollection
      match /generated_content/{docId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
  }
}
```

Deploy rules:
```bash
firebase deploy --only firestore:rules
```

### 9. Authentication Setup

In Firebase Console → Authentication:
1. Enable **Email/Password** sign-in
2. Enable **Google** sign-in
   - Add your app's package name
   - Add SHA-1 certificate fingerprint

**Get SHA-1 (Android):**
```bash
# Windows
cd android && gradlew signingReport

# Mac/Linux
cd android && ./gradlew signingReport
```

## Testing

### Test Functions Locally

```bash
firebase emulators:start --only functions
```

Update Flutter app temporarily:
```dart
static const String _functionsBaseUrl = 'http://localhost:5001/insta-flow-7d1a7/us-central1';
```

### Test with cURL

```bash
curl -X POST \
  https://us-central1-insta-flow-7d1a7.cloudfunctions.net/generateCaption \
  -H "Content-Type: application/json" \
  -d '{"topic": "Sunset photography", "style": "trending"}'
```

## Common Issues

### 1. "Billing not enabled"
- Cloud Functions requires Blaze plan (pay-as-you-go)
- First $2 million invocations/month are free

### 2. "API key not found"
- Verify: `firebase functions:config:get`
- Redeploy after setting: `firebase deploy --only functions`

### 3. CORS errors
- Functions already include CORS
- Check function logs: `firebase functions:log`

### 4. Functions timeout
- Default timeout: 60s
- Increase in `functions/index.js` if needed

## Monitoring

View function logs:
```bash
firebase functions:log
```

View in console:
https://console.firebase.google.com/project/insta-flow-7d1a7/functions

## Cost Estimation

**Free Tier:**
- 2M function invocations/month
- 400K GB-seconds compute time
- 200K CPU-seconds

**Typical Usage:**
- ~100 requests/day = ~3K/month (well within free tier)

## Security

- API keys are stored in Firebase config (secure)
- Functions check authentication when needed
- Firestore rules protect user data
- CORS is configured for web access

## Next Steps

1. ✅ Deploy functions
2. ✅ Test in Flutter app
3. ✅ Monitor logs
4. ✅ Set up error tracking (optional)
5. ✅ Configure custom domain (optional)


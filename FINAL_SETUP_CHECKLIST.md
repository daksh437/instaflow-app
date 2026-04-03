# ✅ Final Setup Checklist - InstaFlow Flutter App

## 📋 Project: instaflow-fosao

## ✅ Completed Steps

- ✅ New Firebase project created: **instaflow-fosao**
- ✅ Billing account linked
- ✅ APIs enabled (Identity Toolkit, Firestore, Storage, Gemini, etc.)
- ✅ Backend running: https://insta-flow-backend.onrender.com
- ✅ Firestore indexes created

---

## 🔥 PHASE 1: FIREBASE CONSOLE CONFIGURATION

### 1.1 Authentication Setup

#### Step 1: Go to Authentication

1. Visit: [Firebase Console](https://console.firebase.google.com)
2. Select project: **instaflow-fosao**
3. Go to: **Authentication** → **Get started** (if not started)
4. Go to: **Sign-in method** tab

#### Step 2: Enable Email/Password

1. Click on **Email/Password**
2. Toggle **Enable**
3. Click **Save**

#### Step 3: Enable Google Sign-In

1. Click on **Google**
2. Toggle **Enable**
3. **Project support email**: Select your email
4. Click **Save**

**Add SHA-1 Certificate:**
1. Go to **Project Settings** → **Your apps** → Android app
2. Scroll to **SHA certificate fingerprints**
3. Click **Add fingerprint**
4. Paste your SHA-1: `E7:25:43:51:E3:91:B2:82:90:9E:2D:C4:33:69:5D:B8:8F:27:36:2D`
5. Click **Save**

#### Step 4: Configure Authorized Domains

1. In Authentication → **Settings** tab
2. Scroll to **Authorized domains**
3. Ensure these are present:
   - `localhost` (for development)
   - `insta-flow-backend.onrender.com` (your backend)
   - Your production domain (if any)

#### Step 5: Enable Phone (Optional)

1. Click on **Phone**
2. Toggle **Enable**
3. Click **Save**

#### Step 6: Enable Apple (For iOS - Optional)

1. Click on **Apple**
2. Toggle **Enable**
3. Configure Apple Sign-In settings
4. Click **Save**

---

### 1.2 Firestore Security Rules

#### Current Rules Status

✅ Rules file updated and ready

#### Deploy Rules

```bash
# Make sure you're using correct project
firebase use instaflow-fosao

# Deploy rules
firebase deploy --only firestore:rules
```

#### Verify Rules in Console

1. Go to: [Firestore Database](https://console.firebase.google.com/project/instaflow-fosao/firestore)
2. Click **Rules** tab
3. Verify rules are deployed correctly

---

### 1.3 Storage Security Rules

#### Deploy Storage Rules

```bash
firebase deploy --only storage:rules
```

#### Verify in Console

1. Go to: [Storage](https://console.firebase.google.com/project/instaflow-fosao/storage)
2. Click **Rules** tab
3. Verify rules are deployed

---

## 📱 PHASE 2: FLUTTER APP CONFIGURATION

### 2.1 Verify google-services.json

✅ Already updated with new project: `instaflow-fosao`

**Location**: `android/app/google-services.json`

**Verify:**
- Project ID: `instaflow-fosao`
- Package name: `com.Instaflow.app`
- SHA-1 certificate added

### 2.2 Update Flutter Firebase Config

**Current Status**: ✅ Already updated in `lib/main.dart`

**Verify** `lib/main.dart` has:
```dart
await Firebase.initializeApp(
  options: const FirebaseOptions(
    apiKey: "YOUR_API_KEY",
    appId: "YOUR_APP_ID",
    messagingSenderId: "YOUR_SENDER_ID",
    projectId: "instaflow-fosao",
    storageBucket: "instaflow-fosao.firebasestorage.app",
  ),
);
```

### 2.3 Update API Base URL (If Needed)

**Check** `lib/services/api_service.dart`:

```dart
static const String baseUrl = 'https://insta-flow-backend.onrender.com';
```

---

## 🧪 PHASE 3: TESTING & VERIFICATION

### 3.1 Test Authentication

1. **Email/Password Sign Up:**
   ```bash
   flutter run
   ```
   - Try creating new account
   - Verify email verification (if enabled)

2. **Google Sign-In:**
   - Click Google Sign-In button
   - Should work with SHA-1 configured

3. **Sign In:**
   - Test existing user login
   - Verify session persistence

### 3.2 Test Firestore

1. **Create Document:**
   - Create a post
   - Verify it appears in Firestore Console

2. **Read Documents:**
   - Load user posts
   - Verify data retrieval

3. **Update/Delete:**
   - Edit a post
   - Delete a post
   - Verify security rules work

### 3.3 Test Storage

1. **Upload File:**
   - Upload profile picture
   - Upload post image
   - Verify files in Storage Console

2. **Download File:**
   - Load uploaded images
   - Verify URLs work

### 3.4 Test Backend Integration

1. **AI Captions:**
   ```bash
   curl -X POST https://insta-flow-backend.onrender.com/ai/captions \
     -H "Content-Type: application/json" \
     -d '{"topic": "test", "tone": "casual"}'
   ```

2. **Calendar:**
   - Test calendar creation
   - Verify Google Calendar integration

---

## ✅ FINAL VERIFICATION CHECKLIST

### Firebase Console:

- [ ] Authentication enabled (Email/Password, Google)
- [ ] SHA-1 certificate added for Google Sign-In
- [ ] Authorized domains configured
- [ ] Firestore database created
- [ ] Firestore rules deployed
- [ ] Storage bucket created
- [ ] Storage rules deployed
- [ ] Cloud Messaging configured

### Flutter App:

- [ ] `google-services.json` updated (project: instaflow-fosao)
- [ ] `lib/main.dart` Firebase config updated
- [ ] Package name matches: `com.Instaflow.app`
- [ ] API base URL: `https://insta-flow-backend.onrender.com`

### Backend:

- [ ] Running on Render: https://insta-flow-backend.onrender.com
- [ ] Environment variables set
- [ ] Gemini API key configured
- [ ] Google OAuth configured

### Testing:

- [ ] Email/Password sign up works
- [ ] Google Sign-In works
- [ ] Firestore read/write works
- [ ] Storage upload/download works
- [ ] AI endpoints work
- [ ] Calendar integration works

---

## 🔗 Quick Links

### Firebase Console:
- **Project**: https://console.firebase.google.com/project/instaflow-fosao
- **Authentication**: https://console.firebase.google.com/project/instaflow-fosao/authentication
- **Firestore**: https://console.firebase.google.com/project/instaflow-fosao/firestore
- **Storage**: https://console.firebase.google.com/project/instaflow-fosao/storage
- **Project Settings**: https://console.firebase.google.com/project/instaflow-fosao/settings/general

### Backend:
- **Health Check**: https://insta-flow-backend.onrender.com/health
- **Render Dashboard**: https://dashboard.render.com

---

## 🚀 Deployment Commands

### Deploy Firestore Rules:
```bash
firebase use instaflow-fosao
firebase deploy --only firestore:rules
```

### Deploy Storage Rules:
```bash
firebase deploy --only storage:rules
```

### Deploy Indexes:
```bash
firebase deploy --only firestore:indexes
```

### Deploy Everything:
```bash
firebase deploy --only firestore
```

---

## 📝 Important Notes

1. **Project ID**: `instaflow-fosao` (not instaflow-f65a0 or instaflow-d0a42)
2. **Package Name**: Must be `com.Instaflow.app` everywhere
3. **SHA-1**: `E7:25:43:51:E3:91:B2:82:90:9E:2D:C4:33:69:5D:B8:8F:27:36:2D`
4. **Backend URL**: `https://insta-flow-backend.onrender.com`

---

**Last Updated**: December 2024  
**Project**: instaflow-fosao


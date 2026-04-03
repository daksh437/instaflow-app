# ✅ Final Setup for InstaFlow - instaflow-fosao

## 📋 Current Status

- ✅ Firebase project: **instaflow-fosao**
- ✅ Billing: Linked
- ✅ APIs: Enabled
- ✅ Backend: https://insta-flow-backend.onrender.com
- ✅ Firestore indexes: Created

---

## 🔥 PHASE 1: FIREBASE CONSOLE CONFIGURATION

### 1.1 Authentication Setup

#### Step 1: Go to Authentication

1. Visit: [Firebase Console](https://console.firebase.google.com)
2. Select project: **instaflow-fosao**
3. Go to: **Authentication** → **Get started** (if not enabled)
4. Go to: **Sign-in method** tab

#### Step 2: Enable Email/Password

1. Click on **Email/Password**
2. Toggle **Enable** to ON
3. Click **Save**

#### Step 3: Enable Google Sign-In

1. Click on **Google**
2. Toggle **Enable** to ON
3. **Support email**: Select your email
4. **Project support email**: Your email
5. Click **Save**

**Add SHA-1 Certificate:**
1. In **Sign-in method** → **Google** → **SHA certificate fingerprints**
2. Click **Add fingerprint**
3. Paste your SHA-1: `E7:25:43:51:E3:91:B2:82:90:9E:2D:C4:33:69:5D:B8:8F:27:36:2D`
4. Click **Save**

#### Step 4: Enable Phone (Optional)

1. Click on **Phone**
2. Toggle **Enable** to ON
3. Click **Save**

#### Step 5: Configure Authorized Domains

1. Go to: **Authentication** → **Settings** → **Authorized domains**
2. Ensure these are listed:
   - `localhost` (for development)
   - `insta-flow-backend.onrender.com` (your backend)
   - Your custom domain (if any)

---

### 1.2 Firestore Security Rules

#### Current Rules Status:

✅ Rules file updated and ready

#### Deploy Rules:

```bash
# Make sure you're using correct project
firebase use instaflow-fosao

# Deploy rules
firebase deploy --only firestore:rules
```

#### Verify Rules:

1. Go to: Firebase Console → **Firestore Database** → **Rules** tab
2. Verify rules are deployed correctly
3. Test rules using Rules Playground (optional)

---

### 1.3 Storage Security Rules

#### Deploy Storage Rules:

```bash
firebase deploy --only storage:rules
```

#### Verify Storage Rules:

1. Go to: Firebase Console → **Storage** → **Rules** tab
2. Verify rules are deployed

---

## 📱 PHASE 2: FLUTTER APP VERIFICATION

### 2.1 Verify google-services.json

✅ Already updated with:
- Project ID: `instaflow-fosao` (or `instaflow-f65a0` - verify which one)
- Package name: `com.Instaflow.app`
- SHA-1 certificate: Included

### 2.2 Verify main.dart

✅ Already updated with:
- Firebase project ID
- API key
- Storage bucket

### 2.3 Test App

```bash
# Clean and rebuild
flutter clean
flutter pub get

# Run app
flutter run
```

---

## 🔧 PHASE 3: BACKEND VERIFICATION

### 3.1 Verify Backend Environment Variables

In Render dashboard, ensure these are set:

- ✅ `GEMINI_API_KEY`
- ✅ `GOOGLE_CLIENT_ID`
- ✅ `GOOGLE_CLIENT_SECRET`
- ✅ `GOOGLE_REDIRECT_URI`
- ✅ `CORS_ORIGINS=*`

### 3.2 Test Backend Endpoints

```bash
# Health check
curl https://insta-flow-backend.onrender.com/health

# Test AI endpoint
curl -X POST https://insta-flow-backend.onrender.com/ai/captions \
  -H "Content-Type: application/json" \
  -d '{"topic": "test", "tone": "casual"}'
```

---

## ✅ FINAL CHECKLIST

### Firebase Console:

- [ ] Authentication enabled (Email/Password, Google)
- [ ] SHA-1 certificate added for Google Sign-In
- [ ] Authorized domains configured
- [ ] Firestore database created
- [ ] Firestore security rules deployed
- [ ] Storage bucket created
- [ ] Storage security rules deployed
- [ ] Firestore indexes deployed

### Flutter App:

- [ ] `google-services.json` updated
- [ ] `main.dart` Firebase config updated
- [ ] Package name matches: `com.Instaflow.app`
- [ ] App builds successfully
- [ ] Authentication works (Email/Password)
- [ ] Google Sign-In works
- [ ] Firestore read/write works
- [ ] Storage upload works

### Backend:

- [ ] All environment variables set in Render
- [ ] Backend health check passes
- [ ] AI endpoints working
- [ ] OAuth working (if using)

---

## 🧪 TESTING CHECKLIST

### Authentication Tests:

1. **Email/Password Sign Up**
   - [ ] Create new account
   - [ ] Verify email (if enabled)
   - [ ] Sign in with email/password

2. **Google Sign-In**
   - [ ] Click Google Sign-In button
   - [ ] Select Google account
   - [ ] Successfully signed in

3. **Password Reset**
   - [ ] Request password reset
   - [ ] Receive email
   - [ ] Reset password

### Firestore Tests:

1. **Read Data**
   - [ ] Query user data
   - [ ] Query posts collection

2. **Write Data**
   - [ ] Create new document
   - [ ] Update document
   - [ ] Delete document

### Storage Tests:

1. **Upload File**
   - [ ] Upload image
   - [ ] Verify file in Storage

2. **Download File**
   - [ ] Download uploaded file
   - [ ] Verify file content

### Backend Tests:

1. **AI Endpoints**
   - [ ] Generate captions
   - [ ] Generate calendar
   - [ ] Generate strategy

2. **Health Check**
   - [ ] `/health` returns OK

---

## 🔗 Quick Links

### Firebase Console:
- **Project**: https://console.firebase.google.com/project/instaflow-fosao
- **Authentication**: https://console.firebase.google.com/project/instaflow-fosao/authentication
- **Firestore**: https://console.firebase.google.com/project/instaflow-fosao/firestore
- **Storage**: https://console.firebase.google.com/project/instaflow-fosao/storage

### Backend:
- **Health Check**: https://insta-flow-backend.onrender.com/health
- **Render Dashboard**: https://dashboard.render.com

---

## 🐛 Troubleshooting

### Authentication Not Working

1. **Check SHA-1**: Verify it's added in Firebase Console
2. **Check Package Name**: Must match exactly
3. **Check Authorized Domains**: Ensure backend domain is added

### Firestore Errors

1. **Check Rules**: Verify rules are deployed
2. **Check Indexes**: Ensure indexes are built
3. **Check Authentication**: User must be authenticated

### Storage Errors

1. **Check Rules**: Verify storage rules are deployed
2. **Check Permissions**: User must be authenticated
3. **Check File Size**: Verify within limits

### Backend Errors

1. **Check Logs**: Render dashboard → Logs
2. **Check Environment Variables**: All must be set
3. **Check API Keys**: Verify they're valid

---

## 📝 Project Information

- **Firebase Project**: instaflow-fosao
- **Backend URL**: https://insta-flow-backend.onrender.com
- **Package Name**: com.Instaflow.app
- **SHA-1**: E7:25:43:51:E3:91:B2:82:90:9E:2D:C4:33:69:5D:B8:8F:27:36:2D

---

**Last Updated**: December 2024  
**Status**: Ready for Production


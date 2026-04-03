# 🔥 Complete Firebase Migration Guide: Old Project → "instaflow"

## 📋 Overview
This guide will help you migrate your Flutter app from the old Firebase project (`insta-flow-7d1a7`) to the new Firebase project (`instaflow`).

---

## PHASE 1: FIREBASE CONSOLE SETUP (New Project "instaflow")

### Step 1.1: Create/Select New Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **"Add project"** or select existing project **"instaflow"**
3. Note down:
   - **Project ID**: `instaflow` (or `instaflow-xxxx`)
   - **Project Number**: `XXXXXXXXXX` (you'll need this)

### Step 1.2: Enable Authentication
1. Go to **Authentication** → **Get started**
2. Enable these sign-in methods:
   - ✅ **Email/Password** (Enable)
   - ✅ **Google** (Enable)
     - Add OAuth consent screen
     - Add authorized domains
   - ✅ **Phone** (if you use phone auth)
3. **Authorized domains**: Add your domains
   - `localhost` (for development)
   - Your production domain
   - `insta-flow-backend.onrender.com` (if using)

### Step 1.3: Create Firestore Database
1. Go to **Firestore Database** → **Create database**
2. Choose mode:
   - **Production mode** (recommended)
   - OR **Test mode** (for development)
3. Select location (same as old project if possible)
4. **Copy security rules** from old project:
   ```javascript
   // Copy rules from firestore.rules in your project
   ```

### Step 1.4: Create Storage Bucket
1. Go to **Storage** → **Get started**
2. Start in **Production mode** or **Test mode**
3. **Copy security rules** from old project:
   ```javascript
   // Copy rules from storage.rules in your project
   ```

### Step 1.5: Enable Cloud Messaging (FCM)
1. Go to **Cloud Messaging**
2. **Android**:
   - Upload new `google-services.json` (will be generated)
   - Note: Server key (if needed for backend)
3. **iOS**:
   - Upload APNs authentication key (if using)
   - Or upload APNs certificate

### Step 1.6: Register Android App
1. Go to **Project Settings** → **Your apps** → **Add app** → **Android**
2. **Package name**: `com.Instaflow.app` (must match exactly)
3. **App nickname**: InstaFlow Android (optional)
4. **SHA-1**: Add your app's SHA-1 certificate fingerprint
   ```bash
   # Get SHA-1:
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```
5. Click **Register app**
6. **Download `google-services.json`** → Save to `android/app/google-services.json`

### Step 1.7: Register iOS App (if applicable)
1. Go to **Project Settings** → **Your apps** → **Add app** → **iOS**
2. **Bundle ID**: `com.Instaflow.app` (must match iOS bundle ID)
3. **App nickname**: InstaFlow iOS (optional)
4. Click **Register app**
5. **Download `GoogleService-Info.plist`** → Save to `ios/Runner/GoogleService-Info.plist`

### Step 1.8: Register Web App (if applicable)
1. Go to **Project Settings** → **Your apps** → **Add app** → **Web**
2. **App nickname**: InstaFlow Web
3. Click **Register app**
4. **Copy Firebase config** (you'll need this for `main.dart`)

### Step 1.9: Get Project Configuration
1. Go to **Project Settings** → **General**
2. Scroll to **Your apps** section
3. Note down for each platform:
   - **API Key**
   - **App ID**
   - **Project ID**
   - **Messaging Sender ID**
   - **Storage Bucket**

### Step 1.10: Service Account (for Backend)
1. Go to **Project Settings** → **Service accounts**
2. Click **Generate new private key**
3. Download JSON file → Save securely (for backend use)
4. **DO NOT commit to git!**

---

## PHASE 2: FLUTTER FRONTEND UPDATES

### Step 2.1: Backup Old Configuration Files
```bash
# Backup old files
cp android/app/google-services.json android/app/google-services.json.old
# If iOS exists:
# cp ios/Runner/GoogleService-Info.plist ios/Runner/GoogleService-Info.plist.old
```

### Step 2.2: Replace Configuration Files

#### Android:
1. **Download new `google-services.json`** from Firebase Console (Step 1.6)
2. Replace: `android/app/google-services.json`
3. Verify package name matches: `com.Instaflow.app`

#### iOS (if applicable):
1. **Download new `GoogleService-Info.plist`** from Firebase Console (Step 1.7)
2. Replace: `ios/Runner/GoogleService-Info.plist`
3. Verify bundle ID matches

### Step 2.3: Update Flutter Dependencies
Update `pubspec.yaml` with latest Firebase versions (already done, but verify):

```yaml
dependencies:
  # Firebase Core
  firebase_core: ^3.6.0
  
  # Firebase Services
  firebase_auth: ^5.3.1
  cloud_firestore: ^5.4.3
  firebase_storage: ^12.3.4
  firebase_messaging: ^15.1.4
  
  # Google Sign-In
  google_sign_in: ^6.2.1
```

### Step 2.4: Update main.dart
Update Firebase initialization to use platform-specific config:

```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

This will automatically use:
- `google-services.json` for Android
- `GoogleService-Info.plist` for iOS
- Web config for web

### Step 2.5: Create Firebase Options File
Create `lib/firebase_options.dart` using FlutterFire CLI:

```bash
flutter pub global activate flutterfire_cli
flutterfire configure --project=instaflow
```

This will:
- Auto-detect your Firebase projects
- Generate `lib/firebase_options.dart`
- Configure all platforms automatically

---

## PHASE 3: BACKEND UPDATES

### Step 3.1: Update Environment Variables
If backend uses Firebase Admin SDK:

1. **Download new service account JSON** (from Step 1.10)
2. Update backend environment variables:
   - `GOOGLE_APPLICATION_CREDENTIALS` (path to new JSON)
   - Or use `FIREBASE_PROJECT_ID=instaflow`

### Step 3.2: Update OAuth Client IDs
If backend uses Google OAuth:

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: **instaflow**
3. Go to **APIs & Services** → **Credentials**
4. Create new OAuth 2.0 Client IDs:
   - **Web client** (for backend)
   - **Android client** (if needed)
5. Update backend `.env`:
   ```
   GOOGLE_CLIENT_ID=<new-web-client-id>
   GOOGLE_CLIENT_SECRET=<new-client-secret>
   ```

---

## PHASE 4: DATA MIGRATION (Optional)

### Step 4.1: Export Old Firestore Data
```bash
# Using Firebase CLI
firebase firestore:export gs://old-project-backup
```

### Step 4.2: Import to New Project
```bash
# Import to new project
firebase firestore:import gs://old-project-backup --project=instaflow
```

### Step 4.3: Migrate Storage Files
1. Use Firebase Console or `gsutil` to copy files
2. Update file references in Firestore documents

---

## PHASE 5: TESTING

### Step 5.1: Test Authentication
- [ ] Email/Password sign up
- [ ] Email/Password sign in
- [ ] Google Sign-In
- [ ] Password reset

### Step 5.2: Test Firestore
- [ ] Read data
- [ ] Write data
- [ ] Security rules work

### Step 5.3: Test Storage
- [ ] Upload files
- [ ] Download files
- [ ] Security rules work

### Step 5.4: Test Cloud Messaging
- [ ] Receive notifications
- [ ] Handle notification taps

---

## PHASE 6: DEPLOYMENT

### Step 6.1: Update Production Config
1. Update production `google-services.json`
2. Update production Firebase config
3. Test on production build

### Step 6.2: Update Render/Backend
1. Update environment variables in Render
2. Update Firebase project ID
3. Deploy backend

---

## ✅ MIGRATION CHECKLIST

### Firebase Console:
- [ ] Created/selected project "instaflow"
- [ ] Enabled Authentication (Email, Google, Phone)
- [ ] Created Firestore database
- [ ] Created Storage bucket
- [ ] Enabled Cloud Messaging
- [ ] Registered Android app
- [ ] Registered iOS app (if applicable)
- [ ] Registered Web app (if applicable)
- [ ] Downloaded new `google-services.json`
- [ ] Downloaded new `GoogleService-Info.plist` (iOS)
- [ ] Copied security rules
- [ ] Generated service account key (backend)

### Flutter App:
- [ ] Backed up old config files
- [ ] Replaced `google-services.json`
- [ ] Replaced `GoogleService-Info.plist` (iOS)
- [ ] Updated `pubspec.yaml` dependencies
- [ ] Updated `main.dart` Firebase initialization
- [ ] Generated `firebase_options.dart`
- [ ] Tested authentication
- [ ] Tested Firestore
- [ ] Tested Storage
- [ ] Tested Cloud Messaging

### Backend:
- [ ] Updated service account JSON
- [ ] Updated OAuth client IDs
- [ ] Updated environment variables
- [ ] Tested backend endpoints
- [ ] Deployed to production

---

## 🚨 IMPORTANT NOTES

1. **Package Name Must Match**: `com.Instaflow.app` must be exact in:
   - Android `build.gradle.kts`
   - Firebase Console
   - `google-services.json`

2. **SHA-1 Certificate**: Add debug and release SHA-1 to Firebase Console

3. **OAuth Consent Screen**: Configure in Google Cloud Console for Google Sign-In

4. **Security Rules**: Copy from old project to maintain same security

5. **Data Migration**: Plan downtime if migrating production data

---

## 📞 SUPPORT

If you encounter issues:
1. Check Firebase Console for errors
2. Check Flutter logs: `flutter run -v`
3. Verify package name matches everywhere
4. Check SHA-1 certificate is added
5. Verify OAuth client IDs are correct

---

## 🎯 QUICK START (After Firebase Setup)

1. **Download config files** from Firebase Console
2. **Replace** `android/app/google-services.json`
3. **Run**: `flutterfire configure --project=instaflow`
4. **Test**: `flutter run`

---

**Last Updated**: December 2024
**Project**: InstaFlow
**New Firebase Project**: instaflow


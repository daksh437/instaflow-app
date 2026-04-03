# ✅ Firebase Migration Checklist

## 🔥 PHASE 1: FIREBASE CONSOLE SETUP

### Step 1: Create/Select Project
- [ ] Go to Firebase Console
- [ ] Create new project "instaflow" OR select existing
- [ ] Note Project ID: `_________________`
- [ ] Note Project Number: `_________________`

### Step 2: Enable Authentication
- [ ] Go to Authentication → Get started
- [ ] Enable Email/Password
- [ ] Enable Google Sign-In
  - [ ] Configure OAuth consent screen
  - [ ] Add authorized domains
- [ ] Enable Phone (if needed)

### Step 3: Create Firestore
- [ ] Go to Firestore Database → Create database
- [ ] Choose Production mode
- [ ] Select location
- [ ] Copy security rules from `firestore.rules`

### Step 4: Create Storage
- [ ] Go to Storage → Get started
- [ ] Choose Production mode
- [ ] Copy security rules from `storage.rules`

### Step 5: Enable Cloud Messaging
- [ ] Go to Cloud Messaging
- [ ] Configure Android (after app registration)
- [ ] Configure iOS (if applicable)

### Step 6: Register Android App
- [ ] Project Settings → Your apps → Add app → Android
- [ ] Package name: `com.Instaflow.app`
- [ ] Add SHA-1 certificate:
  ```bash
  keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
  ```
- [ ] Download `google-services.json`
- [ ] Save to: `android/app/google-services.json`

### Step 7: Register iOS App (if applicable)
- [ ] Project Settings → Your apps → Add app → iOS
- [ ] Bundle ID: `com.Instaflow.app`
- [ ] Download `GoogleService-Info.plist`
- [ ] Save to: `ios/Runner/GoogleService-Info.plist`

### Step 8: Register Web App (if applicable)
- [ ] Project Settings → Your apps → Add app → Web
- [ ] Copy Firebase config values

### Step 9: Service Account (Backend)
- [ ] Project Settings → Service accounts
- [ ] Generate new private key
- [ ] Download JSON (keep secure, don't commit)

---

## 📱 PHASE 2: FLUTTER APP UPDATES

### Step 1: Backup Old Files
- [ ] Backup `android/app/google-services.json` → `google-services.json.old`
- [ ] Backup iOS file (if exists)

### Step 2: Replace Config Files
- [ ] Replace `android/app/google-services.json` with new file
- [ ] Replace `ios/Runner/GoogleService-Info.plist` (if iOS)

### Step 3: Install FlutterFire CLI
```bash
flutter pub global activate flutterfire_cli
```

### Step 4: Configure Firebase
```bash
flutterfire configure --project=instaflow
```
- [ ] Select project: instaflow
- [ ] Select platforms: Android, iOS (if applicable), Web (if applicable)
- [ ] This generates `lib/firebase_options.dart`

### Step 5: Update main.dart
- [ ] Import: `import 'firebase_options.dart';`
- [ ] Change to: `options: DefaultFirebaseOptions.currentPlatform,`

### Step 6: Test
- [ ] Run: `flutter clean`
- [ ] Run: `flutter pub get`
- [ ] Run: `flutter run`
- [ ] Test authentication
- [ ] Test Firestore read/write
- [ ] Test Storage upload

---

## 🔧 PHASE 3: BACKEND UPDATES

### Step 1: Update Service Account
- [ ] Replace service account JSON in backend
- [ ] Update environment variables

### Step 2: Update OAuth (if used)
- [ ] Go to Google Cloud Console
- [ ] Create new OAuth 2.0 Client IDs
- [ ] Update backend `.env`:
  - `GOOGLE_CLIENT_ID=`
  - `GOOGLE_CLIENT_SECRET=`

### Step 3: Test Backend
- [ ] Test authentication endpoints
- [ ] Test Firebase Admin SDK
- [ ] Deploy to Render

---

## 📊 PHASE 4: DATA MIGRATION (Optional)

### Step 1: Export Old Data
- [ ] Export Firestore data
- [ ] Export Storage files

### Step 2: Import to New Project
- [ ] Import Firestore data
- [ ] Import Storage files
- [ ] Update file references

---

## ✅ FINAL VERIFICATION

### Authentication
- [ ] Email/Password sign up works
- [ ] Email/Password sign in works
- [ ] Google Sign-In works
- [ ] Password reset works

### Firestore
- [ ] Read data works
- [ ] Write data works
- [ ] Security rules enforced

### Storage
- [ ] Upload files works
- [ ] Download files works
- [ ] Security rules enforced

### Cloud Messaging
- [ ] Receive notifications
- [ ] Handle notification taps

### Backend
- [ ] All endpoints work
- [ ] Firebase Admin SDK works
- [ ] OAuth works

---

## 🚨 IMPORTANT REMINDERS

1. **Package Name**: Must be `com.Instaflow.app` everywhere
2. **SHA-1**: Add both debug and release certificates
3. **OAuth**: Configure consent screen in Google Cloud Console
4. **Security Rules**: Copy from old project
5. **Environment Variables**: Update in Render/backend

---

**Status**: ⏳ In Progress
**Last Updated**: December 2024


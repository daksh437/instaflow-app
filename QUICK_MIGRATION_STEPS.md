# 🚀 Quick Firebase Migration Steps

## ⚡ FAST TRACK (After Firebase Console Setup)

### Step 1: Install FlutterFire CLI
```bash
flutter pub global activate flutterfire_cli
```

### Step 2: Configure Firebase
```bash
flutterfire configure --project=instaflow
```

**This will:**
- Auto-detect your Firebase projects
- Let you select "instaflow" project
- Auto-generate `lib/firebase_options.dart`
- Configure all platforms (Android, iOS, Web)

### Step 3: Update main.dart

**Before:**
```dart
await Firebase.initializeApp(
  options: const FirebaseOptions(
    apiKey: "...",
    // ... hardcoded values
  ),
);
```

**After:**
```dart
import 'firebase_options.dart';  // Add this import

await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,  // Use this
);
```

### Step 4: Replace Config Files

**Android:**
1. Download `google-services.json` from Firebase Console
2. Replace: `android/app/google-services.json`

**iOS (if applicable):**
1. Download `GoogleService-Info.plist` from Firebase Console
2. Replace: `ios/Runner/GoogleService-Info.plist`

### Step 5: Clean & Run
```bash
flutter clean
flutter pub get
flutter run
```

---

## 📋 DETAILED CHECKLIST

See `MIGRATION_CHECKLIST.md` for complete step-by-step guide.

---

## 🎯 WHAT YOU NEED FROM FIREBASE CONSOLE

1. **Project ID**: `instaflow` (or `instaflow-xxxx`)
2. **google-services.json**: Download from Android app registration
3. **GoogleService-Info.plist**: Download from iOS app registration (if iOS)
4. **Service Account JSON**: For backend (if using Firebase Admin SDK)

---

## ⚠️ IMPORTANT

- **Package Name**: Must be `com.Instaflow.app` everywhere
- **SHA-1 Certificate**: Add to Firebase Console for Google Sign-In
- **OAuth Consent**: Configure in Google Cloud Console

---

**Time Estimate**: 15-30 minutes
**Difficulty**: Easy (with FlutterFire CLI)


# ⚠️ Package Name Mismatch Fix

## 🔍 Problem Detected

**Firebase Console**: `com.instaflow`  
**Your App**: `com.Instaflow.app`

This mismatch will prevent Firebase from working correctly!

---

## ✅ Solution: Register New Android App (Recommended)

### Step 1: Add New Android App in Firebase Console

1. Go to Firebase Console → Project Settings
2. Scroll to "Your apps" section
3. Click **"Add app"** → Select **Android**
4. Enter:
   - **Package name**: `com.Instaflow.app` (exact match!)
   - **App nickname**: `InstaFlow` (optional)
5. Click **"Register app"**

### Step 2: Add SHA-1 Certificate (For Google Sign-In)

**Get your SHA-1:**
```bash
# Debug keystore
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Or on Windows:
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

**Add to Firebase:**
1. Copy the SHA-1 fingerprint
2. In Firebase Console → Project Settings → Your apps → Android app
3. Click **"Add fingerprint"**
4. Paste SHA-1 and save

### Step 3: Download New google-services.json

1. In Firebase Console → Project Settings
2. Scroll to your Android app (`com.Instaflow.app`)
3. Click **"google-services.json"** download link
4. Save the file

### Step 4: Replace in Your Project

1. Replace `android/app/google-services.json` with the new file
2. Verify package name matches: `com.Instaflow.app`

### Step 5: Update Flutter Code

The `lib/main.dart` will automatically use the new config from `google-services.json` if you use `DefaultFirebaseOptions.currentPlatform`, or update the hardcoded values:

```dart
await Firebase.initializeApp(
  options: const FirebaseOptions(
    apiKey: "YOUR_NEW_API_KEY",
    appId: "YOUR_NEW_APP_ID",
    messagingSenderId: "YOUR_PROJECT_NUMBER",
    projectId: "instaflow-f65a0",
    storageBucket: "instaflow-f65a0.firebasestorage.app",
  ),
);
```

---

## 🧹 Clean Up Old App (Optional)

After the new app is working:

1. Go to Firebase Console → Project Settings
2. Find the old app (`com.instaflow`)
3. Click **"Remove this app"** (red button at bottom)
4. Confirm deletion

**Note**: Only remove after confirming new app works!

---

## ✅ Verification

After setup, verify:

1. **Package name matches:**
   - Firebase Console: `com.Instaflow.app`
   - `android/app/build.gradle.kts`: `applicationId = "com.Instaflow.app"`
   - `android/app/google-services.json`: `"package_name": "com.Instaflow.app"`

2. **Test the app:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

3. **Test Firebase features:**
   - Authentication (sign up/in)
   - Firestore (read/write)
   - Storage (upload)

---

## 📝 Current App Package Name Locations

Your app uses `com.Instaflow.app` in:
- ✅ `android/app/build.gradle.kts` (line 24)
- ✅ `android/app/src/main/kotlin/com/Instaflow/app/MainActivity.kt`
- ✅ `android/app/src/main/AndroidManifest.xml` (namespace)

**All correct!** Just need to match Firebase Console.

---

## 🚨 Important Notes

1. **Package name is case-sensitive**: `com.Instaflow.app` ≠ `com.instaflow`
2. **Must match exactly** in Firebase Console and app
3. **SHA-1 is required** for Google Sign-In to work
4. **Don't delete old app** until new one is confirmed working

---

**Last Updated**: December 2024  
**Project**: instaflow-f65a0


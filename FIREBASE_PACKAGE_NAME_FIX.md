# Firebase Package Name Mismatch Fix

## Problem
- **Firebase Console:** Package name = `com.instaflow`
- **App Code:** Package name = `com.Instaflow.app`
- **Result:** Google Sign-In fails because package names don't match

## Solution: Add New Android App in Firebase Console

### Step 1: Go to Firebase Console
1. Open [Firebase Console](https://console.firebase.google.com/)
2. Select project: **instaflow-f65a0**
3. Go to **Project Settings** (gear icon)

### Step 2: Add New Android App
1. In **"Android apps"** section, click **"Add app"** button
2. Enter app details:
   - **Android package name:** `com.Instaflow.app` (exactly as in your app)
   - **App nickname (optional):** `InstaFlow App`
   - **Debug signing certificate SHA-1:** `E7:25:43:51:E3:91:B2:82:90:9E:2D:C4:33:69:5D:B8:8F:27:36:2D`
3. Click **"Register app"**

### Step 3: Download New google-services.json
1. After registering, download the new `google-services.json` file
2. Replace the existing file at: `android/app/google-services.json`

### Step 4: Verify Configuration
1. Check that the new `google-services.json` has:
   - `package_name`: `com.Instaflow.app`
   - SHA-1 fingerprint matches: `E7:25:43:51:E3:91:B2:82:90:9E:2D:C4:33:69:5D:B8:8F:27:36:2D`
   - OAuth client IDs are present

### Step 5: Rebuild App
```bash
flutter clean
flutter pub get
flutter run
```

## Alternative: Update Existing App (If Possible)
If Firebase allows editing package name:
1. Go to existing app settings
2. Update package name to `com.Instaflow.app`
3. Add SHA-1 fingerprint if missing
4. Download updated `google-services.json`

## Important Notes
- Package names are case-sensitive: `com.instaflow` ≠ `com.Instaflow.app`
- SHA-1 fingerprint must match exactly
- After updating, always rebuild the app (`flutter clean` is important)
- Old app (`com.instaflow`) can be removed after new one is working

## Verification Checklist
- [ ] New Android app added in Firebase Console
- [ ] Package name: `com.Instaflow.app` (matches app code)
- [ ] SHA-1 fingerprint added: `E7:25:43:51:E3:91:B2:82:90:9E:2D:C4:33:69:5D:B8:8F:27:36:2D`
- [ ] New `google-services.json` downloaded and replaced
- [ ] App rebuilt with `flutter clean && flutter pub get && flutter run`
- [ ] Google Sign-In tested and working


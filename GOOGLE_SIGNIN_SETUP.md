# Google Sign-In Setup Guide

## Error Code 10 (DEVELOPER_ERROR) Fix

Agar aapko Google sign-in mein error code 10 aa raha hai, to yeh steps follow karein:

## Step 1: SHA-1 Fingerprint Get Karein

### Windows PowerShell se:
```powershell
cd android
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

### Ya manually:
1. Android Studio kholen
2. Terminal mein yeh command run karein:
   ```
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```
3. SHA-1 fingerprint copy karein (jaisa: `AA:BB:CC:DD:...`)

## Step 2: Firebase Console mein Add Karein

1. [Firebase Console](https://console.firebase.google.com/) mein jayein
2. Apna project select karein: `insta-flow-7d1a7`
3. Project Settings (gear icon) click karein
4. "Your apps" section mein Android app select karein
5. "Add fingerprint" button click karein
6. SHA-1 fingerprint paste karein
7. Save karein

## Step 3: OAuth Client ID Check Karein

1. Firebase Console > Project Settings > General tab
2. Scroll down to "Your apps" section
3. Android app ke neeche "Download google-services.json" option hai
4. Naya `google-services.json` download karein
5. Purana file replace karein: `android/app/google-services.json`

## Step 4: Google Cloud Console mein Enable Karein

1. [Google Cloud Console](https://console.cloud.google.com/) mein jayein
2. Apna project select karein
3. "APIs & Services" > "Credentials" mein jayein
4. "OAuth 2.0 Client IDs" check karein
5. Agar nahi hai to create karein:
   - Application type: Android
   - Package name: `com.Instaflow.app`
   - SHA-1: Apna fingerprint

## Step 5: App Rebuild Karein

```bash
flutter clean
flutter pub get
flutter run
```

## Alternative: Quick Fix (Development Only)

Agar aap development mode mein hain, to yeh try karein:

1. Firebase Console > Authentication > Sign-in method
2. Google provider enable karein
3. Support email add karein
4. Save karein

## Troubleshooting

### Error: "OAuth client not found"
- Firebase Console mein OAuth client ID properly configure nahi hai
- Google Cloud Console mein OAuth consent screen setup karein

### Error: "Package name mismatch"
- Check karein: `android/app/build.gradle.kts` mein `applicationId = "com.Instaflow.app"`
- Firebase Console mein same package name hona chahiye

### Error: "SHA-1 not found"
- SHA-1 fingerprint Firebase Console mein add karein
- Release keystore ka SHA-1 bhi add karein agar production build kar rahe hain

## Important Notes

- Development ke liye debug keystore ka SHA-1 use karein
- Production ke liye release keystore ka SHA-1 add karein
- Dono SHA-1 fingerprints add kar sakte hain Firebase Console mein


# Fix OAuth Client Configuration Error

## ❌ Current Error:
"Failed to get ID token from Google"

## 🔍 Problem:
`google-services.json` file mein `oauth_client` array empty hai. Iska matlab OAuth client ID configure nahi hai.

## ✅ Solution:

### Method 1: Download New google-services.json (Easiest)

1. **Firebase Console mein jayein:**
   - https://console.firebase.google.com/project/insta-flow-7d1a7/settings/general/android:com.Instaflow.app

2. **Download google-services.json:**
   - Page scroll karein
   - **"Download google-services.json"** button click karein
   - File download hogi

3. **File replace karein:**
   - Download hui file ko copy karein
   - `android/app/google-services.json` file ko replace karein
   - Purani file backup kar lein (optional)

4. **App rebuild:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

### Method 2: Google Cloud Console se OAuth Client Create Karein

1. **Google Cloud Console open karein:**
   - https://console.cloud.google.com/apis/credentials?project=insta-flow-7d1a7

2. **OAuth Client ID create karein:**
   - **"+ CREATE CREDENTIALS"** button click karein
   - **"OAuth client ID"** select karein

3. **Application type select karein:**
   - **"Android"** select karein

4. **Details fill karein:**
   - **Name:** InstaFlow Android (ya kuch bhi)
   - **Package name:** `com.Instaflow.app`
   - **SHA-1 certificate fingerprint:**
     ```
     E7:25:43:51:E3:91:B2:82:90:9E:2D:C4:33:69:5D:B8:8F:27:36:2D
     ```

5. **Create button click karein**

6. **Firebase Console refresh karein:**
   - Firebase Console mein jayein
   - Project Settings → Android app
   - **"Download google-services.json"** button click karein
   - Naya file download karein aur replace karein

### Method 3: Verify OAuth Client Configuration

1. **Firebase Console check karein:**
   - Project Settings → General
   - Android app section mein
   - SHA certificate fingerprints section mein SHA-1 dikhna chahiye

2. **google-services.json check karein:**
   - File open karein: `android/app/google-services.json`
   - `oauth_client` array check karein
   - Agar empty hai `[]`, to Method 1 ya Method 2 follow karein

## 🔄 After Fixing:

1. **App completely restart karein:**
   - App ko background se close karein
   - Phir se open karein

2. **Google sign-in try karein:**
   - Login screen par "Continue with Google" click karein
   - Google account select karein
   - Ab ID token mil jayega

## ✅ Expected Result:

- Google account select karne ke baad
- Successfully login ho jayega
- Home screen par redirect ho jayega
- Error nahi aayega

## 📝 Quick Checklist:

- [ ] SHA-1 fingerprint Firebase Console mein added hai
- [ ] Naya google-services.json download kiya
- [ ] File replace kar di `android/app/google-services.json`
- [ ] App rebuild kiya (`flutter clean && flutter pub get`)
- [ ] App restart kiya

## 🆘 Still Not Working?

1. **Wait 2-5 minutes** - Firebase changes propagate karne mein time lagta hai
2. **Google Cloud Console check karein** - OAuth client properly created hai ya nahi
3. **google-services.json verify karein** - `oauth_client` array mein data hai ya nahi


# Firebase SHA-1 Fingerprint Setup

## ✅ Your SHA-1 Fingerprint:
```
E7:25:43:51:E3:91:B2:82:90:9E:2D:C4:33:69:5D:B8:8F:27:36:2D
```

## 📋 Step-by-Step Instructions:

### Step 1: Firebase Console mein jayein
1. Browser kholen aur [Firebase Console](https://console.firebase.google.com/) open karein
2. Login karein (agar nahi logged in hain)
3. Apna project select karein: **insta-flow-7d1a7**

### Step 2: Project Settings open karein
1. Left sidebar mein **⚙️ Project Settings** (gear icon) click karein
2. Ya top right corner mein **⚙️ Settings** → **Project settings**

### Step 3: SHA-1 Fingerprint add karein
1. Page scroll karein down to **"Your apps"** section
2. Android app (`com.Instaflow.app`) select karein
3. **"Add fingerprint"** button click karein
4. Naya dialog box khulega
5. Ye SHA-1 paste karein:
   ```
   E7:25:43:51:E3:91:B2:82:90:9E:2D:C4:33:69:5D:B8:8F:27:36:2D
   ```
6. **"Save"** button click karein

### Step 4: Google-services.json download karein (Optional but recommended)
1. Same page par **"Download google-services.json"** button click karein
2. File download hogi
3. Purani file replace karein: `android/app/google-services.json`

### Step 5: Google Cloud Console check karein
1. [Google Cloud Console](https://console.cloud.google.com/) open karein
2. Same project select karein: **insta-flow-7d1a7**
3. Left sidebar se **"APIs & Services"** → **"Credentials"** select karein
4. **"OAuth 2.0 Client IDs"** section check karein
5. Agar Android client nahi hai, to:
   - **"+ CREATE CREDENTIALS"** → **"OAuth client ID"** click karein
   - Application type: **Android**
   - Package name: `com.Instaflow.app`
   - SHA-1: `E7:25:43:51:E3:91:B2:82:90:9E:2D:C4:33:69:5D:B8:8F:27:36:2D`
   - **"Create"** click karein

### Step 6: App rebuild karein
```bash
flutter clean
flutter pub get
flutter run
```

## ✅ Verification:
1. App run karein
2. "Continue with Google" button click karein
3. Google account select karein
4. Ab error nahi aana chahiye! 🎉

## 🔍 Troubleshooting:

### Agar phir bhi error aaye:
1. **Firebase Console refresh karein** - SHA-1 add hone ke baad thoda time lag sakta hai
2. **Google-services.json update karein** - Naya file download karke replace karein
3. **App completely restart karein** - Background se close karke phir se open karein
4. **Cache clear karein**:
   ```bash
   flutter clean
   cd android
   ./gradlew clean
   cd ..
   flutter pub get
   ```

### Common Issues:
- **"OAuth client not found"** → Google Cloud Console mein OAuth client create karein
- **"Package name mismatch"** → Check karein `android/app/build.gradle.kts` mein package name sahi hai
- **"SHA-1 not recognized"** → Firebase Console mein SHA-1 properly paste karein (spaces ke saath)

## 📝 Quick Copy-Paste:
```
SHA-1: E7:25:43:51:E3:91:B2:82:90:9E:2D:C4:33:69:5D:B8:8F:27:36:2D
Package: com.Instaflow.app
```


# Google Services.json Download Guide

## 📥 Step-by-Step Instructions:

### Method 1: Firebase Console se Direct Download

1. **Browser mein yeh link open karein:**
   ```
   https://console.firebase.google.com/project/insta-flow-7d1a7/settings/general/android:com.Instaflow.app
   ```

2. **Page load hone ke baad:**
   - Scroll down karein to "Your apps" section
   - Android app (`com.Instaflow.app`) dikhna chahiye

3. **Download button:**
   - "Download google-services.json" button click karein
   - File automatically download ho jayegi

4. **File location:**
   - Usually Downloads folder mein jayegi
   - File name: `google-services.json`

5. **File replace:**
   - Download hui file ko copy karein
   - `C:\Users\Dell\metapulse_ai\android\app\google-services.json` mein paste karein
   - Purani file replace ho jayegi

### Method 2: Agar Download Button Nahi Dikhe

1. **Google Cloud Console se OAuth Client create karein:**
   - Link: https://console.cloud.google.com/apis/credentials?project=insta-flow-7d1a7
   - "+ CREATE CREDENTIALS" → "OAuth client ID"
   - Application type: **Android**
   - Package name: `com.Instaflow.app`
   - SHA-1: `E7:25:43:51:E3:91:B2:82:90:9E:2D:C4:33:69:5D:B8:8F:27:36:2D`
   - Create karein

2. **5 minutes wait karein** (OAuth client propagate hone ke liye)

3. **Phir Firebase Console se download karein** (Method 1 follow karein)

## ✅ After Download:

File download karne ke baad mujhe batayein, main automatically replace kar dunga!

Ya phir aap manually:
1. Download hui file ko `android/app/` folder mein copy karein
2. Purani `google-services.json` file ko replace karein

## 🔍 Verification:

File download karne ke baad, file open karein aur check karein:
- `oauth_client` array empty nahi hona chahiye `[]`
- `oauth_client` array mein at least ek object hona chahiye


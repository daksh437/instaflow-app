# 🔧 Firebase Google Sign-In Setup Guide

## Problem
Google Sign-In error aa raha hai jab tester users Google se connect karte hain.

## Solution Steps

### 1. SHA-1 Fingerprint Add Karein Firebase Console Mein

**Step 1:** Firebase Console mein jao:
- https://console.firebase.google.com/
- Apna project select karo: **instaflow-f65a0**

**Step 2:** Project Settings mein jao:
- Left sidebar se ⚙️ **Project Settings** click karo
- **Your apps** section mein Android app select karo

**Step 3:** SHA-1 Fingerprint Add Karein:
- **SHA certificate fingerprints** section mein **Add fingerprint** button click karo
- Ye SHA-1 add karo (Debug keystore ka):
  ```
  e7:25:43:51:e3:91:b2:82:90:9e:2d:c4:33:69:5d:b8:8f:27:36:2d
  ```

**Step 4:** Release keystore ka SHA-1 bhi add karo:
- **Add fingerprint** button click karo again
- Ye SHA-1 add karo (Release keystore ka):
  ```
  59:84:57:FB:B9:38:7C:DA:49:E5:BC:13:F7:25:EF:C0:38:93:FE:62
  ```

### 2. OAuth Client ID Verify Karein

**Step 1:** Google Cloud Console mein jao:
- https://console.cloud.google.com/
- Project: **instaflow-f65a0** select karo

**Step 2:** APIs & Services > Credentials:
- **OAuth 2.0 Client IDs** section check karo
- Android client ID verify karo:
  - Package name: `com.instaflow`
  - SHA-1 fingerprint: `E7:25:43:51:E3:91:B2:82:90:9E:2D:C4:33:69:5D:B8:8F:27:36:2D`

**Step 3:** Web client ID verify karo:
- Client ID: `412053319604-4eerf9lfm4mjg3ijfp74tf5q0g0itbi6.apps.googleusercontent.com`
- Ye `serverClientId` ke liye use ho raha hai

### 3. google-services.json Verify Karein

**File Location:** `android/app/google-services.json`

**Check Karein:**
- File mein `oauth_client` array mein Android client ID hona chahiye
- Package name `com.instaflow` match karna chahiye

### 4. App Rebuild Karein

```powershell
flutter clean
flutter pub get
flutter run
```

### 5. Test Karein

1. App uninstall karo (purana version)
2. Fresh install karo
3. Google Sign-In try karo

## Common Issues & Fixes

### Issue 1: "ID token not available"
**Fix:** 
- Firebase Console mein SHA-1 add karo
- App completely restart karo
- `flutter clean` run karo

### Issue 2: "OAuth client not configured"
**Fix:**
- Google Cloud Console mein OAuth client verify karo
- Package name match karein: `com.instaflow`

### Issue 3: "Network error"
**Fix:**
- Internet connection check karo
- Firebase project active hai ya nahi check karo

## Verification Checklist

- [ ] SHA-1 fingerprint Firebase Console mein add hai
- [ ] Release keystore ka SHA-1 bhi add hai (production ke liye)
- [ ] OAuth client ID properly configured hai
- [ ] Package name match kar raha hai: `com.instaflow`
- [ ] `google-services.json` file updated hai
- [ ] App rebuild ho chuka hai (`flutter clean && flutter pub get`)

## Production Release Ke Liye

Production release ke liye **release keystore ka SHA-1** add kar diya hai:

**Release SHA-1:**
```
59:84:57:FB:B9:38:7C:DA:49:E5:BC:13:F7:25:EF:C0:38:93:FE:62
```

**Steps:**
1. ✅ Firebase Console mein ye SHA-1 add karo (see Step 4 above)
2. ✅ Google Cloud Console mein bhi add karo (OAuth 2.0 Client IDs → Android client)
3. ✅ Wait 5-10 minutes for changes to propagate
4. ✅ Rebuild and reinstall app

## Support

Agar issue persist kare, to:
1. Firebase Console logs check karo
2. Google Cloud Console logs check karo
3. App logs check karo: `flutter logs`


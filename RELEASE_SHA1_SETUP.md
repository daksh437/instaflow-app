# 🔐 Release Keystore SHA-1 Setup Guide

## Release Keystore SHA-1 Fingerprint

```
59:84:57:FB:B9:38:7C:DA:49:E5:BC:13:F7:25:EF:C0:38:93:FE:62
```

## Steps to Add in Firebase Console

### Step 1: Firebase Console
1. Go to: https://console.firebase.google.com/
2. Select project: **instaflow-f65a0**
3. Click ⚙️ **Project Settings** (left sidebar)
4. Scroll to **Your apps** section
5. Select Android app: **instaflow** (`com.instaflow`)

### Step 2: Add Release SHA-1
1. Find **SHA certificate fingerprints** section
2. Click **Add fingerprint** button
3. Paste this SHA-1:
   ```
   59:84:57:FB:B9:38:7C:DA:49:E5:BC:13:F7:25:EF:C0:38:93:FE:62
   ```
4. Click **Save**

### Step 3: Google Cloud Console
1. Go to: https://console.cloud.google.com/
2. Select project: **instaflow-f65a0**
3. Navigate to: **APIs & Services** → **Credentials**
4. Find **OAuth 2.0 Client IDs** section
5. Click on Android client ID
6. In **SHA-1 certificate fingerprints** section, click **Add fingerprint**
7. Paste the same SHA-1:
   ```
   59:84:57:FB:B9:38:7C:DA:49:E5:BC:13:F7:25:EF:C0:38:93:FE:62
   ```
8. Click **Save**

## Current SHA-1 Fingerprints

### Debug Keystore (Already Added ✅)
```
e7:25:43:51:e3:91:b2:82:90:9e:2d:c4:33:69:5d:b8:8f:27:36:2d
```

### Release Keystore (Need to Add ⚠️)
```
59:84:57:FB:B9:38:7C:DA:49:E5:BC:13:F7:25:EF:C0:38:93:FE:62
```

## Verification

After adding the SHA-1:
1. Wait 5-10 minutes for changes to propagate
2. Uninstall the app from test devices
3. Rebuild and reinstall the app
4. Test Google Sign-In

## Important Notes

- **Both SHA-1 fingerprints must be added** for Google Sign-In to work:
  - Debug SHA-1: For development/testing
  - Release SHA-1: For production/release builds

- **Changes take 5-10 minutes** to propagate after adding SHA-1

- **App must be reinstalled** after SHA-1 is added for changes to take effect

## Troubleshooting

If Google Sign-In still doesn't work after adding SHA-1:

1. ✅ Verify SHA-1 is added in Firebase Console
2. ✅ Verify SHA-1 is added in Google Cloud Console
3. ✅ Uninstall app completely from device
4. ✅ Rebuild app: `flutter clean && flutter pub get && flutter run`
5. ✅ Wait 10 minutes after adding SHA-1
6. ✅ Check if using correct build type (debug vs release)

## Support

If issues persist, contact: instaflow38@gmail.com


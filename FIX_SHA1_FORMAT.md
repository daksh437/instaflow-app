# Firebase SHA-1 Format Fix

## ❌ Problem:
Firebase Console error: "String does not match a recognized certificate fingerprint format"

## ✅ Solution:

### Step 1: SHA1 Button Click Karein
1. Dialog box mein **"SHA1"** button (gray button) pe click karein
2. Button highlight/selected hona chahiye

### Step 2: Fingerprint Field Clear Karein
1. Input field ko completely clear karein
2. Purani value delete karein

### Step 3: Correct Format Paste Karein
Yeh exact format copy-paste karein (spaces nahi, sirf colons):

```
E7:25:43:51:E3:91:B2:82:90:9E:2D:C4:33:69:5D:B8:8F:27:36:2D
```

### Step 4: Verify Format
- Total 20 pairs of characters
- Har pair ke beech colon (:)
- No spaces anywhere
- No extra characters

### Step 5: Save Button Click Karein
- Agar format sahi hai, Save button enable ho jayega
- Save click karein

## 🔍 Alternative Method (Agar phir bhi error aaye):

### Method 1: Manual Type (Recommended)
1. SHA1 button click karein
2. Field clear karein
3. Manually type karein (copy-paste ki jagah):
   ```
   E7:25:43:51:E3:91:B2:82:90:9E:2D:C4:33:69:5D:B8:8F:27:36:2D
   ```

### Method 2: Check for Hidden Characters
1. Field select karein (Ctrl+A)
2. Delete karein
3. Fresh paste karein from here:
   ```
   E7:25:43:51:E3:91:B2:82:90:9E:2D:C4:33:69:5D:B8:8F:27:36:2D
   ```

### Method 3: Use Google Cloud Console Instead
1. [Google Cloud Console](https://console.cloud.google.com/) open karein
2. Project: **insta-flow-7d1a7** select karein
3. **APIs & Services** → **Credentials**
4. **+ CREATE CREDENTIALS** → **OAuth client ID**
5. Application type: **Android**
6. Package name: `com.Instaflow.app`
7. SHA-1: `E7:25:43:51:E3:91:B2:82:90:9E:2D:C4:33:69:5D:B8:8F:27:36:2D`
8. Create karein

## ✅ Verification:
- Dialog box close hone ke baad, SHA certificate fingerprints section mein yeh dikhna chahiye:
  ```
  SHA-1: E7:25:43:51:E3:91:B2:82:90:9E:2D:C4:33:69:5D:B8:8F:27:36:2D
  ```

## 📝 Quick Copy (Clean Format):
```
E7:25:43:51:E3:91:B2:82:90:9E:2D:C4:33:69:5D:B8:8F:27:36:2D
```


# 🔑 How to Get SHA-1 Certificate for Firebase

## ✅ Method 1: Using Gradle (Recommended - Easiest)

This is the easiest and most reliable method:

### Steps:

1. **Open terminal in your project root**

2. **Run this command:**
   ```bash
   cd android
   .\gradlew signingReport
   ```

   Or from project root:
   ```bash
   cd android && .\gradlew signingReport
   ```

3. **Look for output like this:**
   ```
   Variant: debug
   Config: debug
   Store: C:\Users\YourName\.android\debug.keystore
   Alias: AndroidDebugKey
   SHA1: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
   ```

4. **Copy the SHA1 value** (without spaces or colons, or with colons - Firebase accepts both)

5. **Add to Firebase Console:**
   - Go to Firebase Console → Project Settings → Your apps → Android app
   - Click "Add fingerprint"
   - Paste SHA-1
   - Save

---

## ✅ Method 2: Using Keytool (Direct)

### For Windows PowerShell:

```powershell
# Try this first
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

### For Windows CMD:

```cmd
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

### Alternative Paths (if above doesn't work):

```powershell
# Full path
keytool -list -v -keystore "C:\Users\$env:USERNAME\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

---

## ✅ Method 3: Using Flutter (If Gradle doesn't work)

```bash
# Build the app first (this creates the keystore if it doesn't exist)
flutter build apk --debug

# Then use keytool
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

---

## 🔍 What to Look For

In the keytool output, find this line:
```
SHA1: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
```

Copy the SHA1 value (the hex string after "SHA1:").

---

## ⚠️ Troubleshooting

### Problem: "keystore not found"
**Solution:**
1. Build your app first: `flutter build apk --debug`
2. This will create the debug keystore automatically
3. Then try keytool again

### Problem: "keytool command not found"
**Solution:**
1. Make sure Java JDK is installed
2. Add Java bin to PATH, or use full path:
   ```powershell
   "C:\Program Files\Java\jdk-XX\bin\keytool.exe" -list -v -keystore ...
   ```

### Problem: "alias androiddebugkey does not exist"
**Solution:**
- The keystore might be corrupted
- Delete it and rebuild:
  ```powershell
  Remove-Item "$env:USERPROFILE\.android\debug.keystore"
  flutter build apk --debug
  ```

---

## 📋 Quick Command Reference

**Gradle (Easiest):**
```bash
cd android && .\gradlew signingReport
```

**Keytool (PowerShell):**
```powershell
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

**Keytool (CMD):**
```cmd
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

---

## ✅ After Getting SHA-1

1. Copy the SHA-1 fingerprint
2. Go to Firebase Console → Project Settings
3. Select your Android app
4. Click "Add fingerprint"
5. Paste SHA-1
6. Save

**Note:** You need SHA-1 for:
- Google Sign-In to work
- Firebase App Check (if using)
- Some Firebase features

---

**Last Updated**: December 2024


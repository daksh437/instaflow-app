# App Complete Restart Steps

## ⚠️ Important: App Ko Completely Restart Karein

Google sign-in ke liye app ko **completely close** karke phir se open karna zaroori hai.

## 📋 Step-by-Step:

### Step 1: App Completely Close Karein
1. **Recent apps** mein jayein (Android: square button ya swipe up)
2. InstaFlow app ko **swipe up/close** karein
3. Ya **Force Stop** karein:
   - Settings → Apps → InstaFlow → Force Stop

### Step 2: Emulator/Device Restart (Optional but Recommended)
- Emulator ko completely close karein
- Phir se start karein

### Step 3: Flutter Clean & Rebuild
```bash
flutter clean
flutter pub get
flutter run
```

### Step 4: Test Google Sign-In
1. App open karein
2. "Continue with Google" click karein
3. Google account select karein
4. Ab kaam karna chahiye! ✅

## 🔍 Verification:

File properly configured hai:
- ✅ OAuth client ID: `756676582231-cjtp5ejp2gvl7v6qrl8v7k38vdf715ue.apps.googleusercontent.com`
- ✅ Package name: `com.Instaflow.app`
- ✅ SHA-1: `e7254351e391b282909e2dc433695db88f27362d`

## 🆘 Agar Phir Bhi Error Aaye:

1. **Wait 2-3 minutes** - Firebase changes propagate karne mein time lagta hai
2. **Check google-services.json** - File properly saved hai ya nahi
3. **Uninstall & Reinstall** app (last resort):
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

## ✅ Expected Result:

- Google account select karne ke baad
- ID token mil jayega
- Successfully login ho jayega
- Home screen par redirect ho jayega


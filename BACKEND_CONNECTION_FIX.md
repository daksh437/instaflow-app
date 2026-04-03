# Backend Connection Fix

## ✅ Fixed Error

The error `Connection refused` was happening because Android emulator cannot access `localhost`. 

**Solution:** Updated `api_service.dart` to automatically use:
- **Android Emulator:** `http://10.0.2.2:8080` (maps to host's localhost)
- **iOS Simulator:** `http://localhost:8080`
- **Physical Device:** Need to use your computer's IP address

## 🚀 Quick Setup

### 1. Start Backend Server

```bash
cd server
npm run dev
```

Backend should be running on `http://localhost:8080`

### 2. For Android Emulator

✅ **Already fixed!** The app now automatically uses `10.0.2.2:8080` for Android.

### 3. For Physical Device (Phone)

You need to update the base URL to use your computer's IP address:

1. **Find your computer's IP:**
   - Windows: Open CMD → `ipconfig` → Look for "IPv4 Address" (e.g., 192.168.1.5)
   - Mac/Linux: Terminal → `ifconfig` or `ip addr` → Look for your local IP

2. **Update `lib/services/api_service.dart`:**
   ```dart
   static String get baseUrl {
     if (Platform.isAndroid) {
       // Replace with your computer's IP
       return 'http://192.168.1.5:8080'; // Your IP here
     }
     // ... rest of code
   }
   ```

3. **Make sure your phone and computer are on the same WiFi network**

4. **Update backend CORS** in `server/.env`:
   ```
   CORS_ORIGINS=http://localhost:8080,http://10.0.2.2:8080,http://192.168.1.5:8080
   ```

## 🔍 Troubleshooting

### Error: "Connection refused"

**Check:**
1. ✅ Backend server is running (`npm run dev` in server folder)
2. ✅ Backend is on port 8080 (check `server/.env` PORT=8080)
3. ✅ For Android emulator: using `10.0.2.2:8080` (already fixed)
4. ✅ For physical device: using your computer's IP address

### Error: "CORS error"

**Fix:** Update `server/.env`:
```
CORS_ORIGINS=http://localhost:8080,http://10.0.2.2:8080,http://192.168.1.5:8080
```

Then restart backend server.

### Backend not starting

**Check:**
1. Node.js installed? `node --version`
2. Dependencies installed? `cd server && npm install`
3. `.env` file exists? `cp server/env.example server/.env`
4. All env variables filled? (GOOGLE_CLIENT_ID, GEMINI_API_KEY, etc.)

## 📱 Testing

1. **Start backend:** `cd server && npm run dev`
2. **Run Flutter app:** `flutter run`
3. **Test connection:** Go to "Connect Google Calendar" screen
4. **Should work now!** ✅

## 🎯 Current Status

- ✅ Android Emulator: Fixed (uses 10.0.2.2:8080)
- ✅ iOS Simulator: Works (uses localhost:8080)
- ⚠️ Physical Device: Need to set your computer's IP manually


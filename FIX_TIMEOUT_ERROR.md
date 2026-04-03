# 🔧 Timeout Error Fix

## ❌ Problem
"Request timeout" error aa raha hai - server respond nahi kar raha.

## ✅ Solution

### Step 1: Server Manually Start Karein

**Terminal kholo aur ye command run karo:**

```bash
cd server
node app.js
```

**Ya Windows mein:**
```bash
cd server
start-server.bat
```

**Expected output:**
```
🚀 InstaFlow backend running on http://localhost:8080
```

### Step 2: Agar Error Aaye

Agar server start karte waqt error aaye to:
1. Error message share karo
2. Ya screenshot bhejo
3. Main fix kar dunga

### Step 3: Server Running Check

Agar ye message dikhe to server chal raha hai:
```
🚀 InstaFlow backend running on http://localhost:8080
```

### Step 4: Flutter App Mein Test

1. **Server terminal ko open rakho** (yeh important hai!)
2. Flutter app run karo
3. "AI Captions" try karo
4. Server terminal mein logs dikhenge

---

## 🐛 Common Issues

### Issue 1: "Cannot find module"
**Fix:**
```bash
cd server
npm install
node app.js
```

### Issue 2: "Port already in use"
**Fix:**
```bash
# Find and kill process
netstat -ano | findstr :8080
taskkill /PID <PID> /F

# Start server
node app.js
```

### Issue 3: Gemini API Slow
**Fix:**
- Server mein timeout add kar diya hai (10 seconds)
- Agar slow hai to mock data return hoga automatically

---

## 📝 Important Notes

1. **Server terminal ko hamesha open rakho** - errors wahan dikhenge
2. **Server start karke test karo** - background mein nahi chalao
3. **Agar timeout aaye** - server terminal check karo, kya error dikha

---

## 🚀 Quick Start

```bash
# Terminal 1: Server
cd server
node app.js

# Terminal 2: Flutter (new terminal)
flutter run
```

**Ab test karo!** 🎯


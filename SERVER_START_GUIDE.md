# 🚀 Server Start Guide (Loading Fix)

## ❌ Problem
AI Marketing Tools mein infinite loading aa rahi hai.

## ✅ Solution

### Step 1: Server Start Karein

**Terminal kholo aur ye commands run karo:**

```bash
cd server
npm run dev
```

**Expected output:**
```
🚀 InstaFlow backend running on http://localhost:8080
```

### Step 2: Server Running Check Karein

Agar server chal raha hai to ye message dikhega terminal mein:
```
🚀 InstaFlow backend running on http://localhost:8080
```

### Step 3: Flutter App Mein Test Karein

1. Flutter app run karo
2. "AI Marketing Tools" section mein jao
3. "AI Captions" try karo
4. Ab error message dikhega agar server nahi chal raha
5. Ya captions generate hongi agar server chal raha hai

---

## 🔧 Quick Fix Commands

### Server Start:
```bash
cd server
npm run dev
```

### Server Stop:
```bash
# Terminal mein Ctrl+C press karo
```

### Port Check (Server Running Hai Ya Nahi):
```bash
netstat -ano | findstr :8080
```

Agar kuch output aaye to server chal raha hai ✅
Agar kuch na aaye to server nahi chal raha ❌

---

## 🐛 Common Issues

### 1. "Port 8080 already in use"
**Fix:**
```bash
# Find process
netstat -ano | findstr :8080

# Kill process (replace PID with actual number)
taskkill /PID <PID> /F

# Start server again
npm run dev
```

### 2. "Cannot find module"
**Fix:**
```bash
cd server
npm install
npm run dev
```

### 3. "Connection refused" in Flutter
**Fix:**
- Server start karo: `cd server && npm run dev`
- Check server running: `netstat -ano | findstr :8080`
- Flutter app mein error message ab clear dikhega

---

## ✅ After Server Starts

1. ✅ Server terminal mein "🚀 InstaFlow backend running" dikhega
2. ✅ Flutter app mein AI features kaam karenge
3. ✅ Loading infinite nahi hogi - ya to result aayega ya error message

---

## 📝 Important

- **Server hamesha chalna chahiye** jab bhi Flutter app use kar rahe ho
- Server terminal ko **open rakho** taaki errors dekh sakte ho
- Agar server crash ho to terminal mein error dikhega

---

**Ab server start karo aur test karo!** 🚀


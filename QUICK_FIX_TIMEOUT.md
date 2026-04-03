# ⚡ Quick Fix: Request Timeout Error

## 🔴 Problem
Flutter app showing: "Request timeout. Backend server may be slow or not responding."

## ✅ Solution

### Step 1: Start Backend Server

**Open NEW terminal window:**

```powershell
cd C:\Users\Dell\metapulse_ai\backend
node app.js
```

**Expected output:**
```
✅ Gemini model initialized: gemini-1.5-flash
🚀 InstaFlow backend running on http://localhost:3000
✅ Server ready for requests!
```

### Step 2: Verify Server is Running

**In a NEW terminal, test:**
```powershell
Invoke-WebRequest -Uri http://localhost:3000/health -UseBasicParsing
```

Should return: `StatusCode: 200`

### Step 3: Check Flutter App Base URL

**For Android Emulator:**
- Should be: `http://10.0.2.2:3000` ✅

**For Physical Device:**
- Should be: `http://YOUR_COMPUTER_IP:3000`
- Example: `http://10.42.138.25:3000`

**For iOS Simulator:**
- Should be: `http://localhost:3000` ✅

## 🎯 Quick Checklist

- [ ] Backend server running on port 3000
- [ ] Health check returns 200 OK
- [ ] Flutter app baseUrl matches your device type
- [ ] Server terminal shows request logs when you try AI features

## 🐛 If Still Timing Out

1. **Check server terminal** - Are requests coming in?
2. **Check Flutter logs** - What error is shown?
3. **Verify network** - Can device reach your computer?

---

**Server start karo aur test karo!** 🚀


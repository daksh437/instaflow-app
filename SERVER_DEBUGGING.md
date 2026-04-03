# 🔍 Server Debugging Guide

## ✅ Kya Add Kiya

1. **Request Logging:** Har request server terminal mein dikhegi
2. **Detailed Gemini Logs:** Gemini API calls ki detailed logs
3. **Error Tracking:** Errors clearly dikhenge

## 🚀 Ab Kya Karein

### Step 1: Server Restart Karein

**Pehle server stop karo (Ctrl+C), phir start karo:**

```bash
cd server
node app.js
```

### Step 2: Server Terminal Watch Karein

Server terminal ko **open rakho** - ab har request ki logs dikhengi:

**Expected logs jab request aayegi:**
```
[2024-12-14T13:45:00.000Z] POST /ai/captions
[generateCaptions] Request received - topic: future, tone: Friendly
[generateCaptions] Calling Gemini API...
[runGemini] Starting...
[runGemini] Calling Gemini API with prompt length: 120
[runGemini] Creating API promise...
[runGemini] Waiting for API response or timeout...
```

### Step 3: Flutter App Se Request Bhejo

1. Flutter app mein "AI Captions" try karo
2. Server terminal mein logs dikhenge
3. Agar koi error aaye to wahan dikhega

## 🔍 Debugging Steps

### Agar Request Server Tak Pahunch Rahi Hai

Server terminal mein ye dikhega:
```
[2024-12-14T...] POST /ai/captions
[generateCaptions] Request received...
```

**Matlab:** Request server tak pahunch rahi hai ✅

### Agar Gemini API Slow Hai

Server terminal mein ye dikhega:
```
[runGemini] Waiting for API response or timeout...
[runGemini] Timeout reached (10 seconds)
[runGemini] Falling back to mock data
```

**Matlab:** Gemini API slow hai, mock data return hoga ✅

### Agar Gemini API Error Hai

Server terminal mein ye dikhega:
```
[runGemini] Error: [error message]
[runGemini] Falling back to mock data
```

**Matlab:** API error hai, mock data return hoga ✅

### Agar Request Server Tak Nahi Pahunch Rahi

Server terminal mein **kuch nahi dikhega**

**Matlab:** 
- Flutter app server ko reach nahi kar raha
- IP address check karo
- Network check karo

## 📝 Log Format

Har log mein ye information hogi:
- **Timestamp:** Request ka time
- **Method & Path:** POST /ai/captions
- **Function Name:** [generateCaptions], [runGemini]
- **Status:** Starting, received, error, etc.

## 🎯 Quick Test

1. Server start: `node app.js`
2. Flutter app se request bhejo
3. Server terminal check karo - logs dikhenge
4. Agar kuch nahi dikha to network issue hai

---

**Ab server restart karo aur logs check karo!** 🔍


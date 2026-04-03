# 🎯 Final Server Start Guide

## ✅ Purane Processes Stop Ho Gaye

Ab server clean start karein.

## 🚀 Step-by-Step

### Step 1: Naya Terminal Window Kholo

**Important:** Naya PowerShell/CMD window kholo (errors dikhne ke liye)

### Step 2: Server Folder Mein Jao

```powershell
cd C:\Users\Dell\metapulse_ai\server
```

### Step 3: Server Start Karo

```powershell
node app.js
```

### Step 4: Expected Output

Agar sab theek hai to ye **4 messages** dikhenge:

```
🚀 InstaFlow backend running on http://localhost:8080
📱 Phone access: http://10.42.138.25:8080
✅ Server ready for requests!
📊 Health check: http://localhost:8080/health
```

**⚠️ Important:** Agar ye messages nahi dikhe to koi error hai - share karo!

### Step 5: Server Terminal Open Rakho

- **Server terminal ko open rakho** - yeh bahut important hai!
- Wahan logs dikhenge jab requests aayengi
- Agar koi error aaye to wahan dikhega

## 📱 Test Karein

### Test 1: Browser Se

Browser kholo aur ye URL open karo:
```
http://localhost:8080/health
```

Agar ye dikhe to server chal raha hai:
```json
{"success":true,"message":"OK"}
```

### Test 2: Flutter App Se

1. Flutter app run karo
2. "AI Marketing Tools" → "AI Captions" try karo
3. **Server terminal check karo** - ye logs dikhenge:
   ```
   [2024-12-14T...] POST /ai/captions
   [generateCaptions] Request received - topic: future, tone: Friendly
   [generateCaptions] Calling Gemini API...
   [runGemini] Starting...
   ```

## 🐛 Agar Error Aaye

### Server Start Nahi Hota

**Server terminal mein error dikhega:**
- Error message share karo
- Main fix kar dunga

### "Port already in use"

```powershell
# Find process
netstat -ano | findstr :8080
# Kill (replace PID)
taskkill /PID <PID> /F
# Start again
node app.js
```

### "Cannot find module"

```powershell
cd server
npm install
node app.js
```

## ✅ Verification Commands

### Server Running Check:
```powershell
netstat -ano | findstr :8080
```
Agar output aaye to server chal raha hai ✅

### Node Processes Check:
```powershell
Get-Process node -ErrorAction SilentlyContinue
```
Sirf 1 process hona chahiye (server) ✅

---

## 🎯 Quick Checklist

- [ ] Naya terminal window khola
- [ ] `cd server` kiya
- [ ] `node app.js` run kiya
- [ ] 4 messages dikhe (server ready)
- [ ] Server terminal open rakha
- [ ] Browser se health check kiya
- [ ] Flutter app se test kiya
- [ ] Server terminal mein logs check kiye

---

**Ab clean start karo aur server terminal mein kya dikha share karo!** 🚀


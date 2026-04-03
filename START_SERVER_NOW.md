# 🚀 Server Start Karo Abhi

## ✅ Status Check

- ✅ `.env` file exists
- ✅ `node_modules` check karein (agar nahi hai to `npm install`)

## 🎯 Ab Kya Karein

### Option 1: Isi Terminal Se Start Karo

**Current terminal mein ye command run karo:**

```powershell
node app.js
```

**Expected Output:**
```
🚀 InstaFlow backend running on http://localhost:8080
📱 Phone access: http://10.42.138.25:8080
✅ Server ready for requests!
📊 Health check: http://localhost:8080/health
```

### Option 2: Naya Terminal Window (Recommended)

1. **Naya PowerShell window kholo**
2. **Ye commands run karo:**
   ```powershell
   cd C:\Users\Dell\metapulse_ai\server
   node app.js
   ```
3. **Terminal open rakho** - logs dikhenge

## 📱 Test Karein

### Browser Test:
```
http://localhost:8080/health
```

Expected response:
```json
{"success":true,"message":"OK"}
```

### Flutter App Test:
1. Flutter app run karo
2. "AI Marketing Tools" → "AI Captions" try karo
3. **Server terminal check karo** - logs dikhenge

## 🐛 Agar Error Aaye

### "Cannot find module"
```powershell
npm install
node app.js
```

### "Port already in use"
```powershell
# Find process
netstat -ano | findstr :8080
# Kill (replace PID)
taskkill /PID <PID> /F
# Start again
node app.js
```

### "EADDRINUSE"
Koi aur process port 8080 use kar raha hai. Purane processes stop karo.

---

## ✅ Quick Start Command

```powershell
cd C:\Users\Dell\metapulse_ai\server
node app.js
```

**Server terminal ko open rakho aur kya dikha share karo!** 🚀


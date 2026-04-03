# 🚀 Server Start Instructions

## ⚠️ Important

Server ko **manually start** karna hoga. Background mein mat chalao.

## 📋 Steps

### Step 1: Terminal Kholo

**Naya terminal/PowerShell window kholo**

### Step 2: Server Folder Mein Jao

```bash
cd C:\Users\Dell\metapulse_ai\server
```

### Step 3: Server Start Karo

```bash
node app.js
```

### Step 4: Expected Output

Agar sab theek hai to ye messages dikhenge:

```
🚀 InstaFlow backend running on http://localhost:8080
📱 Phone access: http://10.42.138.25:8080
✅ Server ready for requests!
📊 Health check: http://localhost:8080/health
```

### Step 5: Server Terminal Open Rakho

- **Server terminal ko open rakho** - yeh important hai!
- Wahan logs dikhenge jab requests aayengi
- Agar error aaye to wahan dikhega

## ✅ Server Running Check

Agar server chal raha hai to:

1. **Terminal mein messages dikhenge** (upar wale)
2. **Port check:**
   ```bash
   netstat -ano | findstr :8080
   ```
   - Agar output aaye to server chal raha hai ✅
   - Agar kuch na aaye to server nahi chal raha ❌

## 🐛 Agar Server Start Nahi Ho

### Error: "Port already in use"
```bash
# Find process
netstat -ano | findstr :8080
# Kill process (replace PID)
taskkill /PID <PID> /F
# Start again
node app.js
```

### Error: "Cannot find module"
```bash
npm install
node app.js
```

## 📱 Phone Se Test

1. Server start karo (upar wale steps)
2. Flutter app run karo
3. "AI Captions" try karo
4. Server terminal mein logs dikhenge

---

**Server terminal ko hamesha open rakho!** 🔍


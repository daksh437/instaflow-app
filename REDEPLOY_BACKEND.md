# 🔄 Backend Redeploy Guide (Quick Steps)

## Method 1: Manual Deploy from Render Dashboard (Easiest)

### Steps:
1. **Render Dashboard kholo**
   - Visit: https://dashboard.render.com
   - Login karo

2. **Service select karo**
   - Apni backend service click karo (e.g., `insta-flow-backend`)

3. **Manual Deploy**
   - Top right corner mein **"Manual Deploy"** button click karo
   - **"Deploy latest commit"** select karo
   - Ya phir specific branch select karke deploy karo

4. **Wait karo**
   - Deployment start hoga
   - Logs tab mein progress dekh sakte ho
   - 2-3 minutes lag sakte hain

5. **Verify**
   - Deployment complete hone ke baad health check karo:
   ```
   https://insta-flow-backend.onrender.com/health
   ```

---

## Method 2: GitHub se Auto-Deploy (If GitHub connected hai)

### Steps:
1. **GitHub repository check karo**
   - Code GitHub pe push karna hoga
   - Render automatically deploy kar dega

2. **If Git repo nahi hai:**
   ```bash
   # Git initialize karo (if needed)
   git init
   git add .
   git commit -m "Update Gemini models to 2.5"
   git remote add origin YOUR_GITHUB_REPO_URL
   git push -u origin main
   ```

3. **Render automatically deploy kar dega** jab aap push karte ho

---

## Method 3: Render CLI se Deploy (Advanced)

### Steps:
1. **Render CLI install karo:**
   ```bash
   npm install -g render-cli
   ```

2. **Login karo:**
   ```bash
   render login
   ```

3. **Deploy karo:**
   ```bash
   cd backend
   render deploy
   ```

---

## ✅ Deployment Complete Check

### Health Check:
```bash
curl https://insta-flow-backend.onrender.com/health
```

**Expected Response:**
```json
{
  "status": "ok",
  "success": true,
  "message": "OK"
}
```

### Test Gemini API:
```bash
curl -X POST https://insta-flow-backend.onrender.com/ai/captions \
  -H "Content-Type: application/json" \
  -d '{"topic": "test", "tone": "casual", "audience": "general", "language": "en"}'
```

---

## 🔍 Troubleshooting

### Deployment Fail ho raha hai:
1. **Logs check karo** - Render dashboard → Logs tab
2. **Environment variables verify karo** - Sab required vars set hone chahiye
3. **Build errors check karo** - Logs mein error messages dekh lo

### Server start nahi ho raha:
1. **PORT check karo** - Render auto-sets PORT
2. **Dependencies check karo** - `package.json` mein sab packages honi chahiye
3. **Start command verify karo** - Should be `npm start`

### Gemini API errors:
1. **GEMINI_API_KEY check karo** - Render dashboard → Environment tab
2. **Model name verify karo** - Ab `gemini-2.5-flash` use ho raha hai
3. **Logs check karo** - Render logs mein detailed errors dikhenge

---

## 📝 Quick Checklist

- [ ] Render dashboard open kiya
- [ ] Service select kiya
- [ ] Manual Deploy button click kiya
- [ ] Deployment complete hone ka wait kiya
- [ ] Health check pass ho gaya
- [ ] Gemini API test kiya

---

## 🚀 Current Changes Deployed

✅ **Gemini Models Updated:**
- `gemini-1.5-flash` → `gemini-2.5-flash` (Primary)
- `gemini-1.5-pro` → `gemini-2.5-pro` (Fallback)
- `gemini-1.0-pro` → Kept as legacy fallback

✅ **Files Updated:**
- `backend/utils/geminiClient.js`
- `backend/app.js`
- `backend/controllers/geminiController.js`

---

**Last Updated:** December 2024


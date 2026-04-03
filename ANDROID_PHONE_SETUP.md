# 📱 Android Phone Setup Guide

## ✅ Kya Update Kiya

1. **API Service Updated:** Ab aapke computer ka IP use hoga: `10.42.138.25:8080`
2. **CORS Updated:** Phone se access allow kar diya

## 🚀 Ab Kya Karein

### Step 1: Server Start Karein

**Terminal kholo aur server start karo:**

```bash
cd server
node app.js
```

**Expected output:**
```
🚀 InstaFlow backend running on http://localhost:8080
```

### Step 2: Phone aur Computer Same WiFi Pe

- ✅ Phone aur computer **same WiFi network** pe hone chahiye
- ✅ Agar different network pe ho to connect nahi hoga

### Step 3: Flutter App Run Karein

```bash
flutter run
```

Ya phone ko select karo:
```bash
flutter devices  # Phone ka name dekho
flutter run -d <phone-device-id>
```

### Step 4: Test Karein

1. Flutter app mein "AI Marketing Tools" section pe jao
2. "AI Captions" try karo
3. Ab kaam karna chahiye! ✅

---

## 🔧 Important Notes

### IP Address Change Ho To

Agar aapka computer ka IP address change ho jaye (different WiFi pe jane se), to:

1. **New IP find karo:**
   ```bash
   ipconfig | findstr /i "IPv4"
   ```

2. **`lib/services/api_service.dart` mein update karo:**
   ```dart
   return 'http://10.42.138.25:8080'; // New IP yahan
   ```

3. **Hot restart karo:**
   ```bash
   # Flutter app mein 'r' press karo
   ```

### Firewall Issue

Agar phir bhi connect nahi ho raha:

1. **Windows Firewall check karo:**
   - Windows Security → Firewall
   - Port 8080 allow karo

2. **Ya temporarily firewall disable karo** (testing ke liye)

---

## 🐛 Troubleshooting

### "Connection refused"
- ✅ Server running hai? (`node app.js`)
- ✅ Phone aur computer same WiFi pe hain?
- ✅ IP address sahi hai? (`10.42.138.25`)

### "Timeout"
- ✅ Server terminal check karo - koi error dikha?
- ✅ Server properly start hua?

### "Cannot connect"
- ✅ Firewall check karo
- ✅ IP address verify karo: `ipconfig`

---

## ✅ Current Configuration

- **Computer IP:** `10.42.138.25`
- **Server Port:** `8080`
- **Flutter App URL:** `http://10.42.138.25:8080`

---

## 🎯 Quick Test

1. Server start: `cd server && node app.js`
2. Flutter run: `flutter run`
3. App mein "AI Captions" try karo
4. Should work! ✅

---

**Ab server start karo aur test karo!** 🚀


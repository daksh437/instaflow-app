# AI Service Setup Guide

## 🔑 Getting Your Gemini API Key

1. Visit: https://makersuite.google.com/app/apikey
2. Sign in with your Google account
3. Click "Create API Key"
4. Copy your API key

## ⚙️ Setup Options

### Option 1: Environment Variable (Recommended for Production)

**For Flutter Web/Desktop:**
```bash
flutter run --dart-define=GEMINI_API_KEY=your_api_key_here
```

**For Flutter Build:**
```bash
flutter build web --dart-define=GEMINI_API_KEY=your_api_key_here
```

### Option 2: Direct Configuration (Development Only)

Edit `lib/services/ai_service.dart` and replace:
```dart
defaultValue: 'YOUR_GEMINI_API_KEY_HERE',
```

With:
```dart
defaultValue: 'your_actual_api_key_here',
```

⚠️ **Warning:** Never commit API keys to version control!

### Option 3: Use Secure Storage (Best Practice)

For production apps, consider using:
- `flutter_secure_storage` package
- Firebase Remote Config
- Environment-specific configuration files

## ✅ Testing

Without API key: The service will use mock responses (good for testing UI)
With API key: Real AI-generated content from Gemini

## 📝 Notes

- The service automatically falls back to mock responses if API key is missing or invalid
- All AI functions are optimized for Instagram-style content
- Response quality is tailored for social media engagement


# App Icon Setup Guide

## 📱 App Icon Requirements

App icon ke liye yeh files chahiye:
- Size: 1024x1024 pixels
- Format: PNG
- Background: Pink to Purple Gradient (#FF6B9D to #7B2CBF)
- Logo: White 'f' letter (stylized)

## 🎨 Icon Design Specifications

### Colors:
- **Pink:** #FF6B9D
- **Light Purple:** #C77DFF  
- **Deep Purple:** #7B2CBF
- **White:** #FFFFFF (for logo)

### Logo:
- White 'f' letter
- Stylized, flowing design
- Centered on gradient background

## 📂 File Structure

Create these folders and add icon:
```
assets/
  icon/
    app_icon.png (1024x1024)
```

## 🔧 Generate Icons

After adding `app_icon.png`, run:
```bash
flutter pub get
flutter pub run flutter_native_splash:create
```

This will automatically generate all required icon sizes for Android and iOS.

## ✅ Manual Setup (Alternative)

If you prefer to manually add icons:

### Android Icons:
Place in `android/app/src/main/res/`:
- `mipmap-mdpi/ic_launcher.png` (48x48)
- `mipmap-hdpi/ic_launcher.png` (72x72)
- `mipmap-xhdpi/ic_launcher.png` (96x96)
- `mipmap-xxhdpi/ic_launcher.png` (144x144)
- `mipmap-xxxhdpi/ic_launcher.png` (192x192)

### iOS Icons:
Place in `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

## 🎯 Quick Setup

1. Create `assets/icon/` folder
2. Add `app_icon.png` (1024x1024) with gradient background and white 'f'
3. Run: `flutter pub run flutter_native_splash:create`
4. Done! ✅


# App Icon Generation Guide

## 🎨 App Icon Requirements

App icon ke liye yeh design chahiye:
- **Shape:** Circular
- **Background:** Pink to Purple Gradient (top to bottom)
- **Logo:** White 'f' letter (stylized, flowing design)
- **Size:** 1024x1024 pixels minimum

## 📝 Steps to Generate Icons

### Option 1: Using flutter_native_splash (Recommended)

1. **Create app_icon.png:**
   - Size: 1024x1024 pixels
   - Format: PNG with transparency
   - Design: Circular gradient with white 'f' logo
   - Save in: `assets/icon/app_icon.png`

2. **Update pubspec.yaml:**
   ```yaml
   flutter_native_splash:
     color: "#7B2CBF"
     image: assets/icon/app_icon.png
     android: true
     ios: true
     android_12:
       color: "#7B2CBF"
       image: assets/icon/app_icon.png
   ```

3. **Generate icons:**
   ```bash
   flutter pub get
   flutter pub run flutter_native_splash:create
   ```

### Option 2: Manual Icon Generation

Use online tools like:
- https://www.appicon.co/
- https://icon.kitchen/
- https://makeappicon.com/

Upload your 1024x1024 icon and download all sizes.

## 🎯 Icon Design Specifications

### Colors:
- **Pink (Top):** #FF6B9D
- **Light Purple (Middle):** #C77DFF
- **Deep Purple (Bottom):** #7B2CBF
- **White (Logo):** #FFFFFF

### Logo:
- White 'f' letter
- Stylized, flowing design
- Centered in circle
- Soft, rounded edges

## 📂 Required Icon Sizes

### Android:
- mdpi: 48x48
- hdpi: 72x72
- xhdpi: 96x96
- xxhdpi: 144x144
- xxxhdpi: 192x192

### iOS:
- Various sizes from 20x20 to 1024x1024



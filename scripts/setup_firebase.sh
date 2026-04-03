#!/bin/bash

# Firebase Migration Setup Script
# This script helps set up Firebase for the new project

echo "🔥 Firebase Migration Setup"
echo "============================"
echo ""

# Check if FlutterFire CLI is installed
if ! command -v flutterfire &> /dev/null; then
    echo "📦 Installing FlutterFire CLI..."
    flutter pub global activate flutterfire_cli
    echo "✅ FlutterFire CLI installed"
else
    echo "✅ FlutterFire CLI already installed"
fi

echo ""
echo "📋 Next Steps:"
echo "1. Go to Firebase Console and create/select project 'instaflow'"
echo "2. Enable Authentication, Firestore, Storage, Cloud Messaging"
echo "3. Register Android app with package: com.Instaflow.app"
echo "4. Download google-services.json to android/app/"
echo "5. Run: flutterfire configure --project=instaflow"
echo ""
echo "✅ Setup script complete!"


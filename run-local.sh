#!/bin/bash

echo "🚀 Starting Insta Analyzer locally..."

# Check if nodemon is available
if command -v nodemon &> /dev/null; then
    NODEMON_CMD="nodemon"
else
    NODEMON_CMD="node"
    echo "⚠️  nodemon not found, using node instead (install with: npm install -g nodemon)"
fi

# Start backend
echo ""
echo "📦 Starting backend..."
cd backend || exit
if [ ! -d "node_modules" ]; then
    echo "Installing backend dependencies..."
    npm ci
fi

echo "Backend will run on http://localhost:4000"
$NODEMON_CMD index.js &
BACKEND_PID=$!

cd ..

# Setup Flutter app
echo ""
echo "📱 Setting up Flutter app..."
cd flutter_app || exit
flutter pub get
echo ""
echo "ℹ️  Note: The app is configured for Android Emulator (10.0.2.2:4000)"
echo "   For physical device, update _baseUrl in lib/screens/analyze_screen.dart"
echo "   to use your computer's local IP (e.g., 192.168.1.100:4000)"
cd ..

echo ""
echo "✅ Setup complete!"
echo "Backend PID: $BACKEND_PID"
echo ""
echo "To start Flutter app, run in another terminal:"
echo "  cd flutter_app && flutter run"
echo ""
echo "Press Ctrl+C to stop the backend"

# Wait for Ctrl+C
trap "kill $BACKEND_PID 2>/dev/null; exit" INT TERM
wait


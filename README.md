# Insta Analyzer

A full-stack application for analyzing public Instagram profiles, built with Node.js (Express) backend and Flutter mobile frontend.

## Project Structure

```
.
├── backend/          # Node.js Express API server
├── flutter_app/      # Flutter mobile application
├── run-local.sh      # Helper script to run backend locally
└── README.md         # This file
```

## Features

- **Profile Analysis**: Fetch and display Instagram profile data including followers, engagement rate, and top posts
- **Top Posts Gallery**: Browse recent posts with likes and comments
- **Engagement Charts**: Visualize likes distribution across top posts
- **Scheduler**: Coming soon feature for post scheduling and engagement tracking

## How to Test Locally

### Prerequisites

- Node.js 16+ installed
- Flutter SDK installed
- Android Studio / iOS Simulator or physical device

### Quick Start

1. **Start the Backend**:
```bash
cd backend
npm install
cp .env.example .env
# Edit .env and add your SCRAPER_API_KEY (optional)
node index.js
```

The backend will run on `http://localhost:4000`

2. **Run Flutter App**:

   **For Android Emulator** (default configuration):
   ```bash
   cd flutter_app
   flutter pub get
   flutter run
   ```
   The app uses `http://10.0.2.2:4000` which maps to `localhost` on the emulator.

   **For Physical Device**:
   - Find your computer's local IP address (e.g., `192.168.1.100`)
   - Update `_baseUrl` in `flutter_app/lib/screens/analyze_screen.dart`:
     ```dart
     final String _baseUrl = 'http://192.168.1.100:4000';
     ```
   - Make sure your device and computer are on the same network
   - Run `flutter run`

3. **Test with Sample Usernames**:
   - `natgeo` - National Geographic
   - `instagram` - Instagram official
   - `nasa` - NASA
   - Any public Instagram username

### Using the Helper Script

Run the helper script to automatically start the backend:
```bash
chmod +x run-local.sh
./run-local.sh
```

Then in another terminal:
```bash
cd flutter_app && flutter run
```

## Backend API

### GET /api/analyze?username=<username>

Analyzes an Instagram profile.

**Example:**
```bash
curl "http://localhost:4000/api/analyze?username=natgeo"
```

**Response:**
```json
{
  "ok": true,
  "profile": {
    "id": "...",
    "username": "natgeo",
    "full_name": "National Geographic",
    "followers": 250000000,
    "engagement_rate": "2.50",
    "top_posts": [...]
  }
}
```

See `backend/README.md` for detailed API documentation.

## Important Notes

⚠️ **Instagram Terms of Service**: This tool only accesses publicly available data. Please respect Instagram's Terms of Service and rate limits. Do not use for automated scraping or any malicious purposes.

- The backend uses polite headers and reasonable timeouts
- If `SCRAPER_API_KEY` is provided, it uses a scraping provider; otherwise falls back to direct HTTP requests (may be rate-limited)
- Only public profiles can be analyzed
- All parsing is defensive and handles missing fields gracefully

## Development

- **Backend**: Node.js 16+, Express, Cheerio, Axios
- **Frontend**: Flutter stable, Material Design dark theme
- **Backend Port**: 4000 (configurable via `.env`)
- **Frontend Backend URL**: `http://10.0.2.2:4000` for Android emulator (update for physical devices)

## License

MIT

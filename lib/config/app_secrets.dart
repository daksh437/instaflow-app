/// App Secrets Configuration
/// 
/// TODO: Replace these values with your actual API credentials.
/// 
/// For production, use --dart-define flags:
///   flutter run --dart-define=AI_API_KEY=your_key_here
///   flutter build apk --dart-define=AI_API_KEY=your_key_here
/// 
/// Or use a .env file with flutter_dotenv package.
class AppSecrets {
  /// AI API Base URL
  /// TODO: Replace with your AI provider endpoint
  /// Examples:
  ///   - OpenAI: 'https://api.openai.com/v1'
  ///   - Custom API: 'https://your-api-domain.com/api'
  ///   - Backend API: 'https://insta-flow-backend.onrender.com'
  static const String aiApiBaseUrl = String.fromEnvironment(
    'AI_API_BASE_URL',
    defaultValue: 'https://insta-flow-backend.onrender.com',
  );

  /// AI API Key
  /// TODO: Add your API key here
  /// Set via --dart-define=AI_API_KEY=your_key_here when running/building
  static const String aiApiKey = String.fromEnvironment(
    'AI_API_KEY',
    defaultValue: '',
  );

  /// Firebase Functions Base URL (if using Firebase Functions)
  /// This is kept separate in case you use Firebase Functions as a proxy
  /// Defaults to Render backend for main API calls
  static const String functionsBaseUrl = String.fromEnvironment(
    'FUNCTIONS_BASE_URL',
    defaultValue: 'https://insta-flow-backend.onrender.com',
  );

  /// ElevenLabs API Key for AI voice (text-to-speech).
  /// Set via --dart-define=ELEVENLABS_API_KEY=your_key when running/building.
  static const String elevenLabsApiKey = String.fromEnvironment(
    'ELEVENLABS_API_KEY',
    defaultValue: '',
  );

  static bool get isElevenLabsConfigured => elevenLabsApiKey.isNotEmpty;

  /// TTS proxy URL: backend endpoint that forwards to Google Cloud Text-to-Speech.
  /// App sends POST with { "text": "...", "languageCode": "en-IN" }; server calls
  /// Google TTS with API key and returns { "audioContent": "base64..." }.
  /// Do not put Google API key in the app; keep it only on the server.
  static const String ttsProxyBaseUrl = String.fromEnvironment(
    'TTS_PROXY_BASE_URL',
    defaultValue: 'https://insta-flow-backend.onrender.com',
  );

  static bool get isTtsProxyConfigured => ttsProxyBaseUrl.isNotEmpty;

  /// Check if AI API is configured
  static bool get isAiConfigured => aiApiKey.isNotEmpty || functionsBaseUrl.isNotEmpty;

  /// Get API key for headers (if needed)
  static Map<String, String> getApiHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (aiApiKey.isNotEmpty) {
      // Adjust header name based on your API provider
      // OpenAI: 'Authorization: Bearer $key'
      // Custom: 'X-API-Key: $key' or 'Authorization: $key'
      headers['Authorization'] = 'Bearer $aiApiKey';
    }

    return headers;
  }
}


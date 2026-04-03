# TTS Proxy (Google Cloud Text-to-Speech)

The app does **not** send the Google API key. It calls your backend; the backend calls Google TTS.

## App request

- **Method:** POST  
- **URL:** `{TTS_PROXY_BASE_URL}/api/tts`  
- **Body:** `{ "text": "Hello world", "languageCode": "en-IN" }`  
- **Response:** `{ "audioContent": "<base64 MP3>" }`

## Backend (Node/Express example)

Store `GOOGLE_APPLICATION_CREDENTIALS` or the API key in env. Example with API key:

```js
// POST /api/tts
app.post('/api/tts', async (req, res) => {
  const { text, languageCode = 'en-IN' } = req.body || {};
  if (!text || typeof text !== 'string') {
    return res.status(400).json({ error: 'text required' });
  }
  const voiceName = languageCode.startsWith('hi') ? 'hi-IN-Neural2-A' : 'en-IN-Neural2-A';
  const response = await fetch('https://texttospeech.googleapis.com/v1/text:synthesize', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': process.env.GOOGLE_CLOUD_API_KEY,
    },
    body: JSON.stringify({
      input: { text: text.slice(0, 5000) },
      voice: { languageCode: languageCode.slice(0, 10), name: voiceName },
      audioConfig: {
        audioEncoding: 'MP3',
        speakingRate: 1.0,
        pitch: 0.5,
      },
    }),
  });
  if (!response.ok) {
    const err = await response.text();
    return res.status(response.status).json({ error: err });
  }
  const data = await response.json();
  res.json({ audioContent: data.audioContent });
});
```

## Flutter config

Run with your proxy URL:

```bash
flutter run --dart-define=TTS_PROXY_BASE_URL=https://your-backend.com
```

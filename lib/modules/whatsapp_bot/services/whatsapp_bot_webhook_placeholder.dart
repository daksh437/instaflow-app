/// Placeholder for Meta WhatsApp Cloud API webhook integration.
///
/// Backend: [backend/routes/webhook.js] — `GET /webhook` verification and
/// `POST /webhook` receiver. Set `VERIFY_TOKEN` in server `.env` to match
/// the token configured in the Meta developer app.
///
/// Future work:
/// - Register public HTTPS URL + verify token in Meta Business settings.
/// - Map incoming `entry[].changes[]` payloads to app state or Firestore.
/// - Optionally forward events to `/whatsapp-bot/events` for processing.
class WhatsAppBotWebhookPlaceholder {
  WhatsAppBotWebhookPlaceholder._();

  /// Meta sends GET /webhook?hub.mode=subscribe&hub.verify_token=...&hub.challenge=...
  static const String metaWebhookPath = '/webhook';

  /// Environment key on the server (see backend `.env`).
  static const String verifyTokenEnvKey = 'VERIFY_TOKEN';
}

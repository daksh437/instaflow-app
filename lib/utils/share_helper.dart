import 'package:share_plus/share_plus.dart';

/// Shares AI-generated content with a subtle InstaFlow branding footer, so every
/// share doubles as free promotion (viral loop). Use this for the "Share" action
/// on AI results — NOT for "Copy" (copy should stay clean for the user's own post).
class ShareHelper {
  static const String playUrl =
      'https://play.google.com/store/apps/details?id=com.instaflow';

  static const String _brandFooter =
      '\n\n✨ Made with InstaFlow — AI captions, hashtags & reel scripts for Instagram.\n👉 $playUrl';

  /// Share [text] plus the branding footer.
  static Future<void> shareResult(String text, {String? subject}) async {
    final content = '${text.trim()}$_brandFooter';
    await Share.share(content, subject: subject ?? 'Made with InstaFlow ✨');
  }

  /// Invite/promote the app directly (for a "Share InstaFlow" button).
  static Future<void> shareApp() async {
    await Share.share(
      'I\'m using InstaFlow to write viral Instagram captions, hashtags & reel '
      'scripts with AI — it\'s 🔥\n\nTry it: $playUrl',
      subject: 'Check out InstaFlow ✨',
    );
  }
}

import 'package:flutter/material.dart';

/// Privacy Policy Screen for InstaFlow
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: const Color(0xFF7B2CBF),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy Policy',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last Updated: ${_getLastUpdatedDate()}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),

            _buildSection(
              '1. Introduction',
              'Welcome to InstaFlow ("we," "our," or "us"). This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application InstaFlow (the "App").\n\n'
              'We are committed to protecting your privacy and ensuring the security of your personal information. By using the App, you agree to the collection and use of information in accordance with this Privacy Policy.',
            ),

            _buildSection(
              '2. Information We Collect',
              'We collect the following types of information:\n\n'
              'PERSONAL INFORMATION:\n'
              '• Email address (required for account creation)\n'
              '• Display name and profile photo (optional, via Firebase Authentication or Google Sign-In)\n'
              '• Instagram username (optional, if you choose to connect)\n'
              '• Subscription status and payment information (processed securely through payment providers)\n\n'
              'CONTENT DATA:\n'
              '• Captions, hashtags, post ideas, and other text content you generate using our AI tools\n'
              '• Reels scripts, bio drafts, and calendar entries you create\n'
              '• History of generated content (if you choose to save it)\n\n'
              'USAGE DATA:\n'
              '• Features accessed and frequency of use\n'
              '• Tool usage statistics (for enforcing free tier limits)\n'
              '• App performance and error logs\n\n'
              'AUTHENTICATION:\n'
              '• We do not store or have access to your passwords\n'
              '• Authentication is handled securely by Firebase/Google Sign-In\n'
              '• OAuth tokens for Google Calendar (if connected) are stored securely',
            ),

            _buildSection(
              '3. How We Use Your Information',
              'We use the collected information for the following purposes:\n\n'
              '• To provide and maintain the App\'s functionality\n'
              '• To generate AI-powered content based on your inputs\n'
              '• To manage your subscription and enforce usage limits\n'
              '• To improve the App\'s features and user experience\n'
              '• To send you notifications (welcome, trial expiry, subscription updates)\n'
              '• To respond to your inquiries and provide customer support\n'
              '• To detect and prevent fraud, abuse, or security issues\n'
              '• To comply with legal obligations',
            ),

            _buildSection(
              '4. AI Services & Data Processing',
              'Our App uses Google Gemini AI and other third-party AI services to generate content:\n\n'
              '• Your text inputs (captions, topics, descriptions, scripts) are sent to AI service providers for processing\n'
              '• AI service providers may temporarily store your inputs to generate responses\n'
              '• We do not publicly share, sell, or distribute your content to third parties\n'
              '• AI-generated content is provided for your use only\n'
              '• We do not train AI models using your personal content without your explicit consent\n'
              '• AI service providers are bound by their own privacy policies and data protection measures\n\n'
              'By using the App, you consent to your inputs being processed by AI service providers.',
            ),

            _buildSection(
              '5. Data Storage and Security',
              'SECURITY MEASURES:\n'
              '• Your data is stored securely using Firebase and Google Cloud services\n'
              '• We implement industry-standard security measures including encryption\n'
              '• Data is encrypted in transit (HTTPS) and at rest\n'
              '• Access to your data is restricted to authorized personnel only\n'
              '• We regularly update our security practices to protect against threats\n\n'
              'DATA RETENTION:\n'
              '• We retain your data for as long as your account is active or as needed to provide services\n'
              '• Saved content history is retained until you delete it or your account is deleted\n'
              '• Upon account deletion, we will delete your personal data within 30 days\n'
              '• Some data may be retained for legal compliance or dispute resolution\n\n'
              'DATA DELETION:\n'
              '• You may request deletion of your data at any time by contacting us\n'
              '• You can delete saved content history directly from the App',
            ),

            _buildSection(
              '6. Third-Party Services',
              'We use the following third-party services that may collect or process your data:\n\n'
              'FIREBASE (Google):\n'
              '• Authentication, Firestore database, Cloud Functions, Cloud Messaging\n'
              '• Your data is stored on Google Cloud infrastructure\n'
              '• Subject to Google\'s Privacy Policy\n\n'
              'GOOGLE GEMINI AI:\n'
              '• AI content generation services\n'
              '• Your inputs are processed by Google\'s AI models\n'
              '• Subject to Google\'s Privacy Policy and API Terms\n\n'
              'GOOGLE CALENDAR API:\n'
              '• Calendar integration for scheduling content\n'
              '• Requires OAuth authentication\n'
              '• We only create events that you explicitly request\n\n'
              'GOOGLE MOBILE ADS:\n'
              '• Ad serving for free tier users\n'
              '• May collect device information and usage data\n'
              '• Subject to Google\'s Privacy Policy\n\n'
              'PAYMENT PROCESSORS:\n'
              '• Payment information is processed securely by payment providers\n'
              '• We do not store your full payment card details\n\n'
              'These services have their own privacy policies governing data handling. We encourage you to review them.',
            ),

            _buildSection(
              '7. Your Privacy Rights',
              'You have the following rights regarding your personal data:\n\n'
              '• ACCESS: Request a copy of your personal data\n'
              '• CORRECTION: Correct inaccurate or incomplete data\n'
              '• DELETION: Request deletion of your account and data\n'
              '• PORTABILITY: Export your data in a portable format\n'
              '• OPT-OUT: Opt-out of non-essential data collection (e.g., analytics)\n'
              '• WITHDRAW CONSENT: Withdraw consent for data processing (may affect App functionality)\n\n'
              'To exercise these rights, contact us at instaflow38@gmail.com. We will respond within 30 days.\n\n'
              'You can also:\n'
              '• Delete saved content history directly from the App\n'
              '• Disconnect Google Calendar integration from your account settings\n'
              '• Cancel your subscription to stop payment data collection',
            ),

            _buildSection(
              '8. Data Sharing & Disclosure',
              'We do not sell, rent, or trade your personal information to third parties. We may share your data only in the following circumstances:\n\n'
              '• With AI service providers (Google Gemini) to generate content\n'
              '• With cloud service providers (Firebase, Google Cloud) for App functionality\n'
              '• With payment processors to process subscription payments\n'
              '• If required by law, court order, or government regulation\n'
              '• To protect our rights, property, or safety, or that of our users\n'
              '• In connection with a business transfer (merger, acquisition, etc.)\n\n'
              'We require all third parties to maintain appropriate security measures and use your data only for specified purposes.',
            ),

            _buildSection(
              '9. Children\'s Privacy',
              'InstaFlow is not intended for users under the age of 13 (or the minimum age in your jurisdiction). We do not knowingly collect personal information from children under 13.\n\n'
              'If you are a parent or guardian and believe your child has provided us with personal information, please contact us immediately at instaflow38@gmail.com. We will delete such information promptly.\n\n'
              'If you are between 13 and 18 years old, you must have your parent\'s or guardian\'s permission to use the App.',
            ),

            _buildSection(
              '10. International Data Transfers',
              'Your information may be transferred to and processed in countries other than your country of residence. These countries may have data protection laws that differ from those in your country.\n\n'
              'By using the App, you consent to the transfer of your information to:\n'
              '• Google Cloud servers (which may be located in various countries)\n'
              '• AI service providers\' servers\n\n'
              'We ensure that appropriate safeguards are in place to protect your data during international transfers.',
            ),

            _buildSection(
              '11. Cookies & Tracking Technologies',
              'The App may use the following technologies:\n\n'
              '• Firebase Analytics: To understand app usage and improve features\n'
              '• Google Mobile Ads: To serve ads to free tier users\n'
              '• Local Storage: To store your preferences and saved content\n\n'
              'You can opt-out of analytics tracking through your device settings, though this may affect some App features.',
            ),

            _buildSection(
              '12. Changes to This Privacy Policy',
              'We may update this Privacy Policy from time to time to reflect changes in our practices or legal requirements. We will notify you of any material changes by:\n\n'
              '• Posting the updated Privacy Policy in the App\n'
              '• Updating the "Last Updated" date\n'
              '• Sending a notification (for significant changes)\n\n'
              'Your continued use of the App after changes are posted constitutes acceptance of the new Privacy Policy. If you do not agree to the changes, you should stop using the App and delete your account.',
            ),

            _buildSection(
              '13. Contact Us',
              'If you have questions, concerns, or complaints about this Privacy Policy or our data practices, please contact us:\n\n'
              'Email: instaflow38@gmail.com\n'
              'Instagram: @instaflow__app\n\n'
              'We will respond to your inquiry within 48 hours during business days.\n\n'
              'For data protection inquiries or to exercise your privacy rights, please include "Privacy Request" in your email subject line.',
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7B2CBF),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  String _getLastUpdatedDate() {
    return 'January 2026';
  }
}


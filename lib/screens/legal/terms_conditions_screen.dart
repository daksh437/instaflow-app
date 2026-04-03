import 'package:flutter/material.dart';

/// Terms & Conditions Screen for InstaFlow
class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
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
              'Terms & Conditions',
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
              '1. Acceptance of Terms',
              'By downloading, installing, accessing, or using InstaFlow ("the App", "we", "us", or "our"), you agree to be bound by these Terms and Conditions ("Terms"). If you do not agree to these Terms, please do not use the App.\n\n'
              'InstaFlow is an AI-powered social media content creation tool designed to help users create Instagram captions, reels scripts, hashtags, and other content. By using the App, you acknowledge that you have read, understood, and agree to be bound by these Terms.',
            ),

            _buildSection(
              '2. Description of Service',
              'InstaFlow provides the following features:\n\n'
              '• AI Captions Generator: Generate unique Instagram captions using artificial intelligence\n'
              '• Reels Script Writer: Create engaging video scripts for Instagram Reels\n'
              '• Hashtag Generator: Generate relevant hashtags for your content\n'
              '• Bio Maker: Create professional Instagram bios\n'
              '• Post Ideas Generator: Get creative content ideas\n'
              '• AI Calendar Generator: Plan and schedule your content calendar\n'
              '• Growth Strategy: AI-powered strategies for Instagram growth\n'
              '• Niche Analysis: Analyze your niche and audience\n'
              '• Viral Hook Creator: Create attention-grabbing hooks\n'
              '• Comment AI Reply: Generate intelligent replies to comments\n'
              '• Carousel Writer: Create multi-slide carousel post content\n'
              '• Trend Finder: Discover trending hashtags and topics\n\n'
              'Some features are available only to Premium subscribers.',
            ),

            _buildSection(
              '3. Use of the App',
              'You agree to use the App only for lawful purposes and in accordance with these Terms. You agree NOT to:\n\n'
              '• Use the App to create or distribute spam, harassment, hate speech, or illegal content\n'
              '• Violate any local, state, national, or international laws or regulations\n'
              '• Infringe on intellectual property rights, including copyrights, trademarks, or patents\n'
              '• Attempt to reverse engineer, decompile, disassemble, or hack the App\n'
              '• Use automated systems, bots, or scripts to access or use the App\n'
              '• Share your account credentials with others or create multiple accounts to circumvent usage limits\n'
              '• Use the App to generate content that violates Instagram\'s Terms of Service or Community Guidelines\n'
              '• Resell, redistribute, or commercially exploit AI-generated content beyond your personal or business use\n'
              '• Interfere with or disrupt the App\'s servers, networks, or security features',
            ),

            _buildSection(
              '4. AI-Generated Content',
              'The App uses artificial intelligence (including Google Gemini AI) to generate content:\n\n'
              '• AI-generated content is provided "as is" and may not be 100% accurate, original, or suitable for all purposes\n'
              '• You are solely responsible for reviewing, editing, and verifying all AI-generated content before use\n'
              '• You are responsible for ensuring that AI-generated content complies with all applicable laws and platform policies\n'
              '• We do not guarantee that AI-generated content will be unique, error-free, or meet your specific needs\n'
              '• AI-generated content may occasionally contain errors, inaccuracies, or inappropriate suggestions\n'
              '• You retain ownership of your original input content, but AI-generated output is provided for your use\n'
              '• We are not liable for any consequences, legal issues, or damages resulting from your use of AI-generated content\n'
              '• You may not claim that AI-generated content is entirely human-written or misrepresent its origin',
            ),

            _buildSection(
              '5. Premium Subscriptions & Free Trial',
              'InstaFlow offers subscription plans with the following terms:\n\n'
              'FREE TRIAL:\n'
              '• New users receive a 7-day free trial upon registration\n'
              '• During the trial, you have unlimited access to all features\n'
              '• After the trial expires, Basic users have limited access:\n'
              '  - AI Tools: 2 uses per day per tool\n'
              '  - AI Marketing Tools: Completely blocked\n'
              '  - Ads will be shown\n\n'
              'SUBSCRIPTION PLANS:\n'
              '• Premium plans are available for 1 month, 3 months, 6 months, or 1 year\n'
              '• Premium subscribers get unlimited access to all features\n'
              '• Premium subscribers do not see ads\n'
              '• Subscription pricing is subject to change with notice\n'
              '• All payments are processed securely through Google Play Billing\n'
              '• Subscription management is handled through your Google Play Store account\n\n'
              'AUTO-RENEWAL:\n'
              '• Payment will be charged to your Google Play account at confirmation of purchase\n'
              '• Subscriptions automatically renew unless auto-renew is turned off at least 24 hours before the end of the current period\n'
              '• Your account will be charged for renewal within 24 hours prior to the end of the current period\n'
              '• You can cancel your subscription at any time through Google Play Store settings\n'
              '• To cancel: Open Google Play Store → Menu → Subscriptions → Select InstaFlow → Cancel\n'
              '• Cancellation takes effect at the end of the current billing period\n'
              '• You will continue to have access to premium features until the period ends\n\n'
              'REFUNDS:\n'
              '• Refunds are subject to our Refund Policy (see separate section)\n'
              '• We do not guarantee specific results, follower growth, or engagement metrics\n'
              '• Subscription does not entitle you to unlimited or uninterrupted service',
            ),

            _buildSection(
              '6. Third-Party Services & Integrations',
              'InstaFlow integrates with the following third-party services:\n\n'
              'GOOGLE CALENDAR:\n'
              '• You may connect your Google Calendar to schedule content\n'
              '• This requires OAuth authentication and grants us permission to create calendar events\n'
              '• You can disconnect your Google Calendar at any time\n'
              '• We only create events that you explicitly request\n\n'
              'INSTAGRAM:\n'
              '• You may provide your Instagram username for account linking\n'
              '• We do not access your Instagram account or post content on your behalf\n'
              '• Instagram username is used for identification and analytics purposes only\n\n'
              'FIREBASE & GOOGLE SERVICES:\n'
              '• We use Firebase for authentication, data storage, and cloud functions\n'
              '• Your data is stored securely on Google Cloud infrastructure\n'
              '• Authentication is handled by Firebase/Google Sign-In',
            ),

            _buildSection(
              '7. Intellectual Property',
              '• The InstaFlow App, including its design, logo, features, and AI algorithms, are owned by InstaFlow and protected by copyright and trademark laws\n'
              '• AI-generated content is provided for your personal or commercial use, but you may not resell it as a service\n'
              '• You retain ownership of your original input content (captions, topics, descriptions)\n'
              '• You may not redistribute, resell, reverse engineer, or claim ownership of our AI algorithms, system design, or proprietary technology\n'
              '• You may use AI-generated content for your Instagram posts, but you may not claim it as entirely human-written\n'
              '• Any feedback, suggestions, or ideas you provide may be used by InstaFlow without compensation',
            ),

            _buildSection(
              '8. Limitation of Liability',
              'TO THE MAXIMUM EXTENT PERMITTED BY LAW:\n\n'
              '• InstaFlow is provided "AS IS" and "AS AVAILABLE" without warranties of any kind, either express or implied\n'
              '• We do not guarantee that the App will be error-free, uninterrupted, secure, or meet your specific requirements\n'
              '• We are not liable for any indirect, incidental, special, consequential, or punitive damages\n'
              '• We are not responsible for any loss of data, revenue, profits, or business opportunities\n'
              '• We are not liable for any issues arising from your use of AI-generated content on Instagram or other platforms\n'
              '• Our total liability shall not exceed the amount you paid for the subscription in the past 12 months, or the minimum amount permitted by law (whichever is greater)\n'
              '• We are not responsible for third-party services (Google Calendar, Instagram, Firebase) or their availability',
            ),

            _buildSection(
              '9. Indemnification',
              'You agree to indemnify, defend, and hold harmless InstaFlow, its officers, directors, employees, and agents from any claims, damages, losses, liabilities, costs, or expenses (including legal fees) arising from:\n\n'
              '• Your use or misuse of the App\n'
              '• Your violation of these Terms\n'
              '• Content you post using AI-generated material\n'
              '• Your violation of any third-party rights (including Instagram\'s Terms of Service)\n'
              '• Any third-party claims related to your use of the App or AI-generated content',
            ),

            _buildSection(
              '10. Account Termination',
              'We may terminate or suspend your account immediately, without prior notice, if:\n\n'
              '• You violate these Terms or our Privacy Policy\n'
              '• You engage in fraudulent, abusive, or illegal activity\n'
              '• You attempt to hack, reverse engineer, or disrupt the App\n'
              '• Required by law or court order\n'
              '• You fail to pay subscription fees (for Premium users)\n\n'
              'You may cancel your subscription at any time through your account settings. Upon cancellation, you will retain access until the end of your current billing period.',
            ),

            _buildSection(
              '11. Changes to Terms',
              'We reserve the right to modify these Terms at any time. We will notify you of any material changes by:\n\n'
              '• Posting the updated Terms in the App\n'
              '• Updating the "Last Updated" date\n'
              '• Sending a notification (if significant changes are made)\n\n'
              'Your continued use of the App after changes are posted constitutes acceptance of the new Terms. If you do not agree to the changes, you must stop using the App and cancel your subscription.',
            ),

            _buildSection(
              '12. Governing Law & Dispute Resolution',
              'These Terms are governed by and construed in accordance with the laws of India, without regard to its conflict of law provisions.\n\n'
              'Any disputes arising from these Terms or your use of the App shall be subject to the exclusive jurisdiction of the courts in India.\n\n'
              'If any provision of these Terms is found to be unenforceable, the remaining provisions will remain in full effect.',
            ),

            _buildSection(
              '13. Contact Information',
              'If you have questions, concerns, or complaints about these Terms, please contact us:\n\n'
              'Email: instaflow38@gmail.com\n'
              'Instagram: @instaflow__app\n\n'
              'We will respond to your inquiry within 48 hours during business days.',
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


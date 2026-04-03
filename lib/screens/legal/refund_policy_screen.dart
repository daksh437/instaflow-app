import 'package:flutter/material.dart';

/// Refund & Cancellation Policy Screen
/// 
/// TODO: Update the content below with your payment provider details:
/// - Replace "InstaFlow" with your actual app/company name
/// - Update refund period (currently 7 days)
/// - Update contact email
/// - Customize based on your payment gateway (Google Play, Razorpay, etc.)
class RefundPolicyScreen extends StatelessWidget {
  const RefundPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Refund Policy'),
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
              'Refund & Cancellation Policy',
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
              '1. Overview',
              'InstaFlow is a digital service application. All purchases are considered final unless explicitly stated otherwise in this policy. Refunds are handled based on the platform through which you made your purchase.',
            ),

            _buildSection(
              '2. Google Play Store Purchases',
              'If you purchased a subscription through Google Play Store:\n\n'
              '• Refunds are handled according to Google Play\'s refund policy\n'
              '• You can request refunds directly through Google Play Store\n'
              '• Refund eligibility is determined by Google Play policies\n'
              '• Generally, refunds are available within 48 hours of purchase\n'
              '• For issues beyond 48 hours, contact Google Play support',
            ),

            _buildSection(
              '3. Direct Payment Gateway Purchases',
              'If you purchased directly through our payment gateway (e.g., Razorpay):\n\n'
              '• Refunds are only available for technical issues within 7 days of purchase\n'
              '• You must provide proof of the technical issue\n'
              '• Refund requests are subject to review and approval\n'
              '• Approved refunds will be processed within 5-10 business days\n'
              '• Refunds will be issued to the original payment method',
            ),

            _buildSection(
              '4. When Refunds Are NOT Available',
              'Refunds will NOT be provided for:\n\n'
              '• Dissatisfaction with AI-generated content quality\n'
              '• User error or misunderstanding of features\n'
              '• Violation of Terms of Service resulting in account termination\n'
              '• Failure to achieve desired results (follower growth, engagement, etc.)\n'
              '• Change of mind after using the service\n'
              '• Requests made after the refund period has expired',
            ),

            _buildSection(
              '5. Cancellation Policy',
              'You can cancel your subscription at any time:\n\n'
              '• Cancellation takes effect at the end of your current billing period\n'
              '• You will continue to have access to premium features until the period ends\n'
              '• No partial refunds for unused time in the current billing period\n'
              '• To cancel, go to your account settings or contact support',
            ),

            _buildSection(
              '6. Technical Issues',
              'If you experience technical issues that prevent you from using the App:\n\n'
              '• Contact our support team immediately at instaflow38@gmail.com\n'
              '• We will attempt to resolve the issue within 48 hours\n'
              '• If the issue cannot be resolved, we may offer a refund or credit\n'
              '• Refund decisions are made on a case-by-case basis',
            ),

            _buildSection(
              '7. Processing Time',
              '• Refund requests are reviewed within 3-5 business days\n'
              '• Approved refunds are processed within 5-10 business days\n'
              '• The refunded amount may take additional time to appear in your account, depending on your payment provider',
            ),

            _buildSection(
              '8. Contact for Refunds',
              'To request a refund, please contact us at:\n\n'
              'Email: instaflow38@gmail.com\n'
              'Subject: Refund Request - [Your Order/Transaction ID]\n\n'
              'Please include:\n'
              '• Your account email\n'
              '• Purchase date and amount\n'
              '• Reason for refund request\n'
              '• Transaction ID or receipt',
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


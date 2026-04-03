import 'package:flutter/material.dart';

import 'webview_screen.dart' show WebViewScreen;

class WhatsAppBotConnectScreen extends StatelessWidget {
  const WhatsAppBotConnectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const appBarGreen = Color(0xFF075E54);
    const accentGreen = Color(0xFF25D366);
    const warnYellow = Color(0xFFFFC107);
    const infoBlue = Color(0xFFE3F2FD);
    const buttonBlue = Color(0xFF1877F2);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: appBarGreen,
        elevation: 0,
        title: const Text(
          'Number Connect',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Step indicator
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: appBarGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: appBarGreen.withValues(alpha: 0.25),
                  ),
                ),
                child: const Text(
                  'Step 1 of 3',
                  style: TextStyle(
                    color: Color(0xFF0B0B0B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Requirements
              Card(
                elevation: 4,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: appBarGreen.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Connect requirements',
                        style: TextStyle(
                          color: Color(0xFF0B0B0B),
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _requirementRow(
                        iconColor: accentGreen,
                        icon: Icons.check_circle_rounded,
                        text: 'WhatsApp Business number',
                      ),
                      _requirementRow(
                        iconColor: accentGreen,
                        icon: Icons.check_circle_rounded,
                        text: 'Facebook account',
                      ),
                      _requirementRow(
                        iconColor: warnYellow,
                        icon: Icons.warning_amber_rounded,
                        text: 'Personal WhatsApp not allowed',
                      ),
                      _requirementRow(
                        iconColor: warnYellow,
                        icon: Icons.warning_amber_rounded,
                        text: 'OTP required',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Info card (light blue)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: infoBlue,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.lightBlue.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock_outline_rounded,
                        color: Color(0xFF0B4F70)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Meta ka secure login hoga',
                        style: TextStyle(
                          color: const Color(0xFF0B4F70),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Blue button
              FilledButton.icon(
                onPressed: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const WebViewScreen(),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: buttonBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 3,
                ),
                icon: const Icon(Icons.link_rounded),
                label: const Text(
                  'Facebook se Connect Karo',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),

              const SizedBox(height: 18),
              const Text(
                'Help: Meta OTP enter karke continue karein. Personal WhatsApp number use na karein.',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _requirementRow({
    required Color iconColor,
    required IconData icon,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: const Color(0xFF111827),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


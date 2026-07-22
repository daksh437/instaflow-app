import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'google_calendar_coming_soon_screen.dart';

// TODO: Enable after OAuth + verification complete — restore ApiService + OAuth browser flow.

/// Legacy route `/google-connect` — Google Calendar connect is temporarily disabled.
class GoogleConnectScreen extends StatelessWidget {
  const GoogleConnectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Calendar'),
        backgroundColor: const Color(0xFF7B2CBF),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF8F6FF),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline_rounded,
                    size: 72, color: Colors.deepPurple.shade300),
                const SizedBox(height: 20),
                Text(
                  'Coming Soon',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  "We're working on Google Calendar auto scheduling. Stay tuned!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: () {
                    GoogleCalendarComingSoonScreen.showComingSoonSnackBar(
                        context);
                    GoogleCalendarComingSoonScreen.showComingSoonDialog(
                        context);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7B2CBF),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                  ),
                  child: const Text('Learn more'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

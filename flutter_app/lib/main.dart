import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/ai_captions_screen.dart';
import 'screens/ai_calendar_screen.dart';
import 'screens/ai_strategy_screen.dart';
import 'screens/google_connect_screen.dart';

void main() {
  runApp(const InstaFlowApp());
}

class InstaFlowApp extends StatelessWidget {
  const InstaFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'InstaFlow',
      theme: _theme(),
      initialRoute: '/',
      routes: {
        '/': (_) => const HomeScreen(),
        '/captions': (_) => const AICaptionsScreen(),
        '/calendar': (_) => const AICalendarScreen(),
        '/strategy': (_) => const AIStrategyScreen(),
        '/google-connect': (_) => const GoogleConnectScreen(),
      },
    );
  }

  ThemeData _theme() {
    const primary = Color(0xFF7B2CBF);
    const secondary = Color(0xFF9D4EDD);
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        ),
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 4,
        shadowColor: primary.withOpacity(0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'screens/analyze_screen.dart';

void main() {
  runApp(const InstaAnalyzerApp());
}

class InstaAnalyzerApp extends StatelessWidget {
  const InstaAnalyzerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Insta Analyzer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: Colors.purple,
          secondary: Colors.pink,
          surface: const Color(0xFF1E1E1E),
          background: const Color(0xFF121212),
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E1E),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const AnalyzeScreen(),
    );
  }
}


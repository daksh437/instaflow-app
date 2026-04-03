import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Theme Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Choose your preferred theme',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: RadioListTile<ThemeMode>(
              title: const Text('Light Mode'),
              subtitle: const Text('Bright and clean interface'),
              value: ThemeMode.light,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                themeProvider.setTheme(false);
              },
              secondary: const Icon(Icons.light_mode),
            ),
          ),
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: RadioListTile<ThemeMode>(
              title: const Text('Dark Mode'),
              subtitle: const Text('Easy on the eyes'),
              value: ThemeMode.dark,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                themeProvider.setTheme(true);
              },
              secondary: const Icon(Icons.dark_mode),
            ),
          ),
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: RadioListTile<ThemeMode>(
              title: const Text('System Default'),
              subtitle: const Text('Follow system theme'),
              value: ThemeMode.system,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                themeProvider.setThemeMode(ThemeMode.system);
              },
              secondary: const Icon(Icons.brightness_auto),
            ),
          ),
          const SizedBox(height: 32),
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Theme changes will be applied immediately',
                      style: TextStyle(color: Colors.blue.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


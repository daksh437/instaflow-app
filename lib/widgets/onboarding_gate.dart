import 'package:flutter/material.dart';
import '../screens/onboarding_screen.dart';

/// Shows onboarding on first launch, then [child]. Uses SharedPreferences seen_onboarding.
class OnboardingGate extends StatefulWidget {
  const OnboardingGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  bool? _showOnboarding; // null = loading

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    final seen = await OnboardingScreen.hasSeenOnboarding();
    if (!mounted) return;
    setState(() => _showOnboarding = !seen);
  }

  void _onDone() {
    setState(() => _showOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }
    if (_showOnboarding == true) {
      return OnboardingScreen(onDone: _onDone);
    }
    return widget.child;
  }
}

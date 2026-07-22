import 'package:flutter/material.dart';

class MainNavigationWrapper extends StatefulWidget {
  final Widget child;
  final int currentIndex;
  final Widget? floatingActionButton;

  const MainNavigationWrapper({
    super.key,
    required this.child,
    required this.currentIndex,
    this.floatingActionButton,
  });

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  void _onItemTapped(int index) {
    if (index == widget.currentIndex) return;

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/ai-tools');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/premium-hub');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      floatingActionButton: widget.floatingActionButton,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF7B61FF),
          unselectedItemColor: Colors.grey[400],
          currentIndex: widget.currentIndex,
          elevation: 0,
          selectedFontSize: 12,
          unselectedFontSize: 11,
          type: BottomNavigationBarType.fixed,
          onTap: _onItemTapped,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded, size: 24),
              activeIcon: Icon(Icons.home_rounded, size: 24),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_awesome, size: 24),
              activeIcon: Icon(Icons.auto_awesome, size: 24),
              label: 'AI Tools',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.workspace_premium_outlined, size: 24),
              activeIcon: Icon(Icons.workspace_premium_rounded, size: 24),
              label: 'Premium',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded, size: 24),
              activeIcon: Icon(Icons.person_rounded, size: 24),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

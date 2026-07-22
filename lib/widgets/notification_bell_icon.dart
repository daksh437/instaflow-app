import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';

/// Bell for notifications. Use [lightBackground] on light/pastel headers (purple icon).
class NotificationBellIcon extends StatelessWidget {
  const NotificationBellIcon({super.key, this.lightBackground = true});

  final bool lightBackground;

  static const Color _purple = Color(0xFF7B61FF);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    BoxDecoration deco() {
      if (lightBackground) {
        return BoxDecoration(
          color: const Color(0xFFF0EDFF),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFFE4DCFF), width: 1),
          boxShadow: [
            BoxShadow(
              color: _purple.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        );
      }
      return BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
      );
    }

    final iconColor = lightBackground ? _purple : Colors.white;

    if (uid == null) {
      return GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/notifications'),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: deco(),
          child: Icon(Icons.notifications_none_rounded, color: iconColor, size: 24),
        ),
      );
    }

    return StreamBuilder<int>(
      stream: NotificationService().unreadCountStream(uid),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/notifications'),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: deco(),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.notifications_none_rounded, color: iconColor, size: 24),
                if (count > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE53935),
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

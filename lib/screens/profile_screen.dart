import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/plan_manager.dart';
import '../utils/admin_guard.dart';
import '../utils/app_error_handler.dart';
import '../utils/review_helper.dart';
import '../utils/share_helper.dart';
import 'refer_earn_screen.dart';
import '../widgets/main_navigation_wrapper.dart';
import 'instagram_connect_screen.dart';

/// Profile: account, Instagram, AI usage, app settings, support, danger zone.
/// No subscription / premium marketing UI.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const double _kRadius = 16;
  static const String _prefNotifications = 'profile_notifications_enabled';

  final _firestore = FirebaseFirestore.instance;

  String? _instaUsername;
  bool _loadingUser = true;
  bool _uploadingPhoto = false;
  bool _notificationsEnabled = true;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    PlanManager.instance.refresh();
    _loadPrefs();
    _loadUserData();
    _loadVersion();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = prefs.getBool(_prefNotifications) ?? true;
    });
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = info.version);
    } catch (_) {}
  }

  Future<void> _loadUserData() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      if (mounted) setState(() => _loadingUser = false);
      return;
    }

    try {
      final doc = await _firestore.collection('users').doc(firebaseUser.uid).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (!mounted) return;
        setState(() {
          _instaUsername = data['instaUsername'] as String?;
          _loadingUser = false;
        });
      } else {
        final now = DateTime.now();
        final trialEnd = now.add(const Duration(days: 7));
        final today =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        await _firestore.collection('users').doc(firebaseUser.uid).set({
          'email': firebaseUser.email ?? '',
          'displayName': firebaseUser.displayName,
          'photoURL': firebaseUser.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'preferences': {},
          'planType': 'trial',
          'trialStartDate': Timestamp.fromDate(now),
          'trialEndDate': Timestamp.fromDate(trialEnd),
          'dailyAiUsed': 0,
          'dailyAiDate': today,
        }, SetOptions(merge: true));

        final newDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();
        if (!mounted) return;
        if (newDoc.exists && newDoc.data() != null) {
          setState(() {
            _instaUsername = newDoc.data()?['instaUsername'] as String?;
            _loadingUser = false;
          });
        } else {
          setState(() => _loadingUser = false);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loadingUser = false);
    }
  }

  String _displayName(User? user) {
    if (user == null) return 'User';
    if ((user.displayName ?? '').trim().isNotEmpty) return user.displayName!.trim();
    final email = user.email ?? '';
    if (email.contains('@')) {
      final local = email.split('@').first;
      return local
          .replaceAll('.', ' ')
          .split(' ')
          .where((s) => s.isNotEmpty)
          .map((e) => '${e[0].toUpperCase()}${e.substring(1)}')
          .join(' ');
    }
    return 'User';
  }

  /// OAuth profile under `instagram_data/profile`.
  Stream<DocumentSnapshot<Map<String, dynamic>>> _instagramProfileStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Stream.empty();
    }
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('instagram_data')
        .doc('profile')
        .snapshots();
  }

  String? _igDisplayUsername(Map<String, dynamic>? oauth, String? manual) {
    final u = oauth?['username']?.toString().trim();
    if (u != null && u.isNotEmpty) return u;
    final m = manual?.trim();
    if (m != null && m.isNotEmpty) return m.replaceFirst(RegExp(r'^@'), '');
    return null;
  }

  Future<void> _pickAndUploadAvatar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 88,
    );
    if (picked == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final ref = FirebaseStorage.instance.ref().child('users').child(user.uid).child('profile_avatar.jpg');
      await ref.putFile(File(picked.path));
      final url = await ref.getDownloadURL();
      await user.updatePhotoURL(url);
      await user.reload();
      await _firestore.collection('users').doc(user.uid).set(
        {'photoURL': url, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated')),
      );
    } catch (e) {
      if (mounted) {
        AppErrorHandler.log('ProfileAvatar', e);
        AppErrorHandler.show(context, e);
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _setNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefNotifications, value);
    if (mounted) setState(() => _notificationsEnabled = value);
  }

  void _openInstagramConnect() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const InstagramConnectScreen()),
    );
  }

  Future<void> _showDeleteAccountDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kRadius)),
        title: const Text('Delete account'),
        content: const Text(
          'This permanently deletes your data from our servers and signs you out. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (confirmed != true || firebaseUser == null || !mounted) return;
    try {
      await _firestore.collection('users').doc(firebaseUser.uid).delete();
      AdminGuard().clearCache();
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      if (mounted) {
        AppErrorHandler.log('ProfileDelete', e);
        AppErrorHandler.show(context, e);
      }
    }
  }

  Future<void> _logout() async {
    AdminGuard().clearCache();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  static DateTime? _parseResetUtc(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateTime.parse(raw).toLocal();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return MainNavigationWrapper(
      currentIndex: 3,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.userChanges(),
          builder: (context, userSnap) {
            final user = userSnap.data ?? FirebaseAuth.instance.currentUser;
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _instagramProfileStream(),
              builder: (context, igSnap) {
                final igData = igSnap.data?.data();
                final oauthConnected = igData != null && igData.isNotEmpty;
                final igUser = _igDisplayUsername(igData, _instaUsername);

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeader(context, user, igUser, oauthConnected)),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          if (_loadingUser)
                            const Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else ...[
                            _sectionLabel(context, 'Account'),
                            _card(
                              context,
                              children: [
                                _tile(
                                  context,
                                  icon: Icons.face_retouching_natural_outlined,
                                  title: 'Change avatar',
                                  subtitle: 'Pick a new profile photo',
                                  onTap: _uploadingPhoto ? null : _pickAndUploadAvatar,
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _sectionLabel(context, 'Instagram'),
                            _card(
                              context,
                              children: [
                                if (igUser != null)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                                    child: Row(
                                      children: [
                                        Icon(Icons.alternate_email_rounded, color: cs.primary, size: 22),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            '@$igUser',
                                            style: theme.textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: _openInstagramConnect,
                                      icon: Icon(oauthConnected ? Icons.refresh_rounded : Icons.link_rounded),
                                      label: Text(oauthConnected ? 'Reconnect Instagram' : 'Connect Instagram'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _sectionLabel(context, 'AI usage'),
                            _card(
                              context,
                              child: ValueListenableBuilder<PlanState?>(
                                valueListenable: PlanManager.instance.state,
                                builder: (_, plan, __) {
                                  final used = plan?.dailyUsed;
                                  final resetAt = _parseResetUtc(plan?.resetAtUtc);
                                  final resetStr = resetAt != null
                                      ? DateFormat('h:mm a, MMM d').format(resetAt)
                                      : '—';
                                  final usesLine = used != null ? '$used' : '—';
                                  return Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.auto_awesome_outlined, color: cs.primary, size: 22),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                'AI uses today: $usesLine',
                                                style: theme.textTheme.bodyLarge?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Icon(Icons.schedule_rounded, color: cs.outline, size: 20),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Reset time: $resetStr',
                                                style: theme.textTheme.bodyMedium,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                            _sectionLabel(context, 'App settings'),
                            _card(
                              context,
                              children: [
                                SwitchListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  secondary: Icon(
                                    _notificationsEnabled
                                        ? Icons.notifications_active_outlined
                                        : Icons.notifications_off_outlined,
                                    color: cs.onSurfaceVariant,
                                  ),
                                  title: const Text('Notifications'),
                                  subtitle: const Text('In-app alerts and reminders'),
                                  value: _notificationsEnabled,
                                  onChanged: _setNotifications,
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _sectionLabel(context, 'Support & legal'),
                            _card(
                              context,
                              children: [
                                _tile(
                                  context,
                                  icon: Icons.card_giftcard_rounded,
                                  title: 'Refer & Earn',
                                  subtitle: 'Invite a friend — you both get 5 days Premium free',
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const ReferEarnScreen()),
                                  ),
                                ),
                                _divider(context),
                                _tile(
                                  context,
                                  icon: Icons.star_rounded,
                                  title: 'Rate InstaFlow',
                                  subtitle: 'Love the app? Leave a ⭐ review',
                                  onTap: () => ReviewHelper.openStoreListing(),
                                ),
                                _divider(context),
                                _tile(
                                  context,
                                  icon: Icons.ios_share_rounded,
                                  title: 'Share InstaFlow',
                                  subtitle: 'Invite a friend to grow with AI',
                                  onTap: () => ShareHelper.shareApp(),
                                ),
                                _divider(context),
                                _tile(
                                  context,
                                  icon: Icons.feedback_outlined,
                                  title: 'Feedback',
                                  subtitle: 'Send feedback or report a problem',
                                  onTap: () => Navigator.pushNamed(context, '/feedback'),
                                ),
                                _divider(context),
                                _tile(
                                  context,
                                  icon: Icons.description_outlined,
                                  title: 'Terms & Conditions',
                                  onTap: () => Navigator.pushNamed(context, '/terms-conditions'),
                                ),
                                _divider(context),
                                _tile(
                                  context,
                                  icon: Icons.privacy_tip_outlined,
                                  title: 'Privacy Policy',
                                  onTap: () => Navigator.pushNamed(context, '/privacy-policy'),
                                ),
                                _divider(context),
                                _tile(
                                  context,
                                  icon: Icons.support_agent_outlined,
                                  title: 'Contact support',
                                  onTap: () => Navigator.pushNamed(context, '/contact-support'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _sectionLabel(context, 'Danger zone', danger: true),
                            _card(
                              context,
                              children: [
                                _tile(
                                  context,
                                  icon: Icons.delete_forever_outlined,
                                  title: 'Delete account',
                                  subtitle: 'Remove your data and sign out',
                                  onTap: _showDeleteAccountDialog,
                                  danger: true,
                                ),
                                _divider(context),
                                _tile(
                                  context,
                                  icon: Icons.logout_rounded,
                                  title: 'Log out',
                                  subtitle: 'Sign out on this device',
                                  onTap: _logout,
                                  danger: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: Text(
                                _appVersion.isEmpty ? 'InstaFlow' : 'InstaFlow v$_appVersion',
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ]),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    User? user,
    String? igUsername,
    bool oauthConnected,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final top = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, top + 16, 24, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary, cs.primary.withValues(alpha: 0.85), cs.tertiary.withValues(alpha: 0.9)],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _uploadingPhoto ? null : _pickAndUploadAvatar,
                  customBorder: const CircleBorder(),
                  child: Ink(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: Colors.white24,
                      backgroundImage: user != null && (user.photoURL ?? '').isNotEmpty
                          ? NetworkImage(user.photoURL!)
                          : null,
                      child: _uploadingPhoto
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : (user == null || (user.photoURL ?? '').isEmpty)
                              ? Text(
                                  (user?.email ?? '?').isNotEmpty
                                      ? (user!.email![0].toUpperCase())
                                      : '?',
                                  style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
                                )
                              : null,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(Icons.camera_alt_rounded, size: 18, color: cs.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _displayName(user),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.email_outlined, size: 16, color: Colors.white.withValues(alpha: 0.9)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  user?.email ?? '',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.95)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (igUsername != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    oauthConnected ? Icons.check_circle_rounded : Icons.tag_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '@$igUsername',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text, {bool danger = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
              color: danger ? Colors.red.shade700 : Theme.of(context).hintColor,
            ),
      ),
    );
  }

  Widget _card(BuildContext context, {Widget? child, List<Widget>? children}) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      elevation: 0,
      borderRadius: BorderRadius.circular(_kRadius),
      clipBehavior: Clip.antiAlias,
      child: child ??
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: children ?? [],
          ),
    );
  }

  Widget _divider(BuildContext context) {
    return Divider(height: 1, thickness: 1, indent: 56, color: Theme.of(context).dividerColor.withValues(alpha: 0.35));
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    bool danger = false,
  }) {
    final theme = Theme.of(context);
    final color = danger ? Colors.red.shade700 : theme.colorScheme.onSurface;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: danger ? Colors.red.shade600 : theme.colorScheme.primary),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
      subtitle: subtitle != null
          ? Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor))
          : null,
      trailing: onTap != null ? Icon(Icons.chevron_right_rounded, color: theme.hintColor) : null,
      onTap: onTap,
    );
  }
}

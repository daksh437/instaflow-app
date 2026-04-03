import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/main_navigation_wrapper.dart';
import '../models/user_model.dart';
import '../services/plan_manager.dart';
import '../services/premium_service.dart';
import '../utils/admin_guard.dart';
import '../utils/app_error_handler.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  String? _instaUsername;
  bool _isLoading = true;
  UserModel? _userModel;
  final PremiumService _premiumService = PremiumService();

  @override
  void initState() {
    super.initState();
    PlanManager.instance.refresh();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      await _premiumService.checkAndUpdateTrialExpiry(user!.uid);
      if (!mounted) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
        final userModel = UserModel.fromFirestore(data, user!.uid);
        if (!mounted) return;
        setState(() {
          _instaUsername = doc.data()?['instaUsername'] as String?;
          _userModel = userModel;
          _isLoading = false;
        });
        }
      } else {
        // User document doesn't exist - create it with free trial
        // This handles cases where registration didn't complete properly
        try {
          final now = DateTime.now();
          final trialEnd = now.add(const Duration(days: 7));
          final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user!.uid)
              .set({
            'email': user!.email,
            'displayName': user!.displayName,
            'photoURL': user!.photoURL,
            'createdAt': FieldValue.serverTimestamp(),
            'preferences': {},
            'planType': 'trial',
            'trialStartDate': Timestamp.fromDate(now),
            'trialEndDate': Timestamp.fromDate(trialEnd),
            'dailyAiUsed': 0,
            'dailyAiDate': today,
          }, SetOptions(merge: true));
          
          // Reload the document
          final newDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user!.uid)
              .get();
          
          if (newDoc.exists) {
            final newData = newDoc.data();
            if (newData != null) {
            final userModel = UserModel.fromFirestore(newData, user!.uid);
            if (!mounted) return;
            setState(() {
              _instaUsername = newDoc.data()?['instaUsername'] as String?;
              _userModel = userModel;
              _isLoading = false;
            });
            }
          } else {
            if (!mounted) return;
            setState(() {
              _userModel = UserModel(
                uid: user!.uid,
                email: user!.email ?? '',
                displayName: user!.displayName,
                photoURL: user!.photoURL,
                createdAt: DateTime.now(),
                isTrialActive: true,
                trialStart: now,
                trialEnd: trialEnd,
              );
              _isLoading = false;
            });
          }
        } catch (createError) {
          if (!mounted) return;
          setState(() {
            _userModel = UserModel(
              uid: user!.uid,
              email: user!.email ?? '',
              displayName: user!.displayName,
              photoURL: user!.photoURL,
              createdAt: DateTime.now(),
            );
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _userModel = user != null ? UserModel(
          uid: user!.uid,
          email: user!.email ?? '',
          displayName: user!.displayName,
          photoURL: user!.photoURL,
          createdAt: DateTime.now(),
        ) : null;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveInstaUsername(String username) async {
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .set({
        'uid': user!.uid,
        'email': user!.email,
        'instaUsername': username,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        _instaUsername = username;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Instagram username saved!'),
          backgroundColor: Color(0xFF7B2CBF),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppErrorHandler.log('ProfileSaveInsta', e);
      AppErrorHandler.show(context, e);
    }
  }

  Future<void> _showDeleteDataDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete my data'),
        content: const Text(
          'This will permanently delete your user data from our servers and sign you out. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || user == null || !mounted) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).delete();
      AdminGuard().clearCache();
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      if (mounted) {
        AppErrorHandler.log('ProfileDeleteData', e);
        AppErrorHandler.show(context, e);
      }
    }
  }

  void _showInstaUsernameDialog() {
    final controller = TextEditingController(text: _instaUsername ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Instagram Username'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter your Instagram username',
            prefixText: '@',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              controller.dispose();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final username = controller.text.trim();
              if (username.isNotEmpty) {
                _saveInstaUsername(username);
              }
              Navigator.pop(context);
              controller.dispose();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B2CBF),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  /// Subscription card from PlanManager (backend /check-ai-access). No Firestore plan reads, no ?? 2.
  Widget _buildSubscriptionCard(BuildContext context) {
    return ValueListenableBuilder<PlanState?>(
      valueListenable: PlanManager.instance.state,
      builder: (_, PlanState? planState, __) {
        if (planState == null) {
          return _subscriptionCardShell(context, title: 'Subscription', subtitle: 'Loading...', isPremium: false);
        }
        final String subtitle;
        if (planState.isTrial) {
          subtitle = planState.trialEndDate != null
              ? 'Trial ends on ${_formatDDMMMYYYY(planState.trialEndDate!)}'
              : 'Free Trial';
        } else if (planState.isPremium) {
          subtitle = planState.premiumExpiry != null
              ? 'Premium active until ${_formatDDMMMYYYY(planState.premiumExpiry!)}'
              : 'Premium Active';
        } else {
          subtitle = 'Free Plan — 2 AI per day';
        }
        return _subscriptionCardShell(
          context,
          title: planState.isPremium ? 'Premium Active' : 'Subscription',
          subtitle: subtitle,
          isPremium: planState.isPremium,
        );
      },
    );
  }

  static const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static String _formatDDMMMYYYY(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = _months[d.month - 1];
    return '$day $month ${d.year}';
  }

  Widget _subscriptionCardShell(BuildContext context, {required String title, required String subtitle, required bool isPremium}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD), Color(0xFFC77DFF)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B2CBF).withOpacity(0.4),
            blurRadius: 25,
            offset: const Offset(0, 10),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.white.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 3)),
                  ],
                ),
                child: Icon(
                  isPremium ? Icons.workspace_premium_rounded : Icons.star_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/premium'),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPremium ? 'Unlimited Access' : 'Upgrade Now',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isPremium ? 'Enjoy all premium features' : 'Unlock all AI tools & features',
                          style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.9)),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.9), size: 20),
                ],
              ),
            ),
          ),
          if (!isPremium) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/premium'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF7B2CBF),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.workspace_premium_rounded, size: 22),
                    SizedBox(width: 10),
                    Text('Upgrade to Premium', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isConnected = _instaUsername != null && _instaUsername!.isNotEmpty;

    return MainNavigationWrapper(
      currentIndex: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F6FF),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Enhanced Header with User Profile
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  24,
                  MediaQuery.of(context).padding.top + 12,
                  24,
                  30,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF7B2CBF),
                      Color(0xFF9D4EDD),
                      Color(0xFFC77DFF),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7B2CBF).withOpacity(0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    ValueListenableBuilder<PlanState?>(
                      valueListenable: PlanManager.instance.state,
                      builder: (_, planState, __) {
                        if (planState == null || !planState.shouldShowCounter || planState.dailyLimit == null) return const SizedBox.shrink();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          child: Text(
                            '${planState.remainingToday} / ${planState.dailyLimit}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        );
                      },
                    ),
                    
                    // User Avatar with Enhanced Design
                    Stack(
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white,
                                Color(0xFFF8F6FF),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white,
                              width: 4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 42,
                            backgroundColor: Colors.transparent,
                            child: user != null && ((user?.photoURL) ?? '').isNotEmpty
                                ? ClipOval(
                                    child: Image.network(
                                      (user?.photoURL) ?? '',
                                      width: 84,
                                      height: 84,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return _buildAvatarInitials();
                                      },
                                    ),
                                  )
                                : _buildAvatarInitials(),
                          ),
                        ),
                        // Edit Button
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFF7B2CBF),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    
                    // User Name with Better Typography
                    Text(
                      user?.displayName ?? 
                      ((user?.email ?? '').contains('@')
                        ? (user?.email ?? '').split('@')[0].replaceAll('.', ' ').split(' ').map((e) => e.isEmpty ? '' : e[0].toUpperCase() + e.substring(1)).join(' ')
                        : null) ?? 
                      'User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                        shadows: [
                          Shadow(
                            color: Colors.black12,
                            offset: Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    
                    // User Email with Icon
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.email_outlined,
                          color: Colors.white.withOpacity(0.9),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            user?.email ?? '',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    
                    // Instagram Connection Status
                    if (isConnected) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '@$_instaUsername',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Content Section
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(60),
                        child: CircularProgressIndicator(
                          color: Color(0xFF7B2CBF),
                        ),
                      ),
                    )
                  else ...[
                    // Quick Actions Section
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.settings_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Quick Actions',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A),
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          
                          // Instagram Account
                          if (!isConnected) ...[
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF7B2CBF).withOpacity(0.1),
                                    const Color(0xFF9D4EDD).withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFF7B2CBF).withOpacity(0.2),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 24,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Connect Instagram',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1A1A1A),
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Link your Instagram account',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: _showInstaUsernameDialog,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF7B2CBF),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: const Text(
                                      'Connect',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            _ProfileCard(
                              icon: Icons.camera_alt_rounded,
                              title: 'Instagram Account',
                              subtitle: '@$_instaUsername',
                              onTap: _showInstaUsernameDialog,
                              isConnected: true,
                            ),
                          ],
                          const SizedBox(height: 12),
                          
                          // Email
                          _ProfileCard(
                            icon: Icons.email_rounded,
                            title: 'Email Address',
                            subtitle: user?.email ?? 'No email',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Premium Subscription Card — live Firestore data only
                    _buildSubscriptionCard(context),
                    const SizedBox(height: 20),

                    // Legal & Support Section
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.info_outline_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Legal & Support',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A),
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _ProfileCard(
                            icon: Icons.feedback_outlined,
                            title: 'Feedback',
                            subtitle: 'Send feedback or report a problem',
                            onTap: () => Navigator.pushNamed(context, '/feedback'),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                      // Terms & Conditions
                      _ProfileCard(
                        icon: Icons.description_outlined,
                        title: 'Terms & Conditions',
                        subtitle: 'Read our terms of service',
                        onTap: () {
                          Navigator.pushNamed(context, '/terms-conditions');
                        },
                      ),
                      const SizedBox(height: 12),

                      // Privacy Policy
                      _ProfileCard(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy Policy',
                        subtitle: 'How we handle your data',
                        onTap: () {
                          Navigator.pushNamed(context, '/privacy-policy');
                        },
                      ),
                      const SizedBox(height: 12),

                      // Contact Support
                      _ProfileCard(
                        icon: Icons.support_agent_outlined,
                        title: 'Contact Support',
                        subtitle: 'Get help and reach out to us',
                        onTap: () {
                          Navigator.pushNamed(context, '/contact-support');
                        },
                      ),
                      const SizedBox(height: 12),

                      // Delete my data
                      _ProfileCard(
                        icon: Icons.delete_forever_outlined,
                        title: 'Delete my data',
                        subtitle: 'Delete account data and sign out',
                        onTap: () => _showDeleteDataDialog(context),
                        isLogout: false,
                      ),

                      const SizedBox(height: 24),

                      // Logout Card
                      _ProfileCard(
                        icon: Icons.logout_rounded,
                        title: 'Logout',
                        subtitle: 'Sign out from your account',
                        onTap: () async {
                          AdminGuard().clearCache();
                          await FirebaseAuth.instance.signOut();
                          if (!mounted) return;
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                        isLogout: true,
                      ),

                      const SizedBox(height: 24),

                      // App Version
                      Center(
                        child: Text(
                          'InstaFlow v1.0.0',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildAvatarInitials() {
    final displayName = user?.displayName;
    final email = user?.email;
    final String initial = (displayName != null && displayName.isNotEmpty)
        ? displayName.substring(0, 1).toUpperCase()
        : (email != null && email.isNotEmpty)
            ? email.substring(0, 1).toUpperCase()
            : 'U';
    
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF9D4EDD),
            Color(0xFFC77DFF),
          ],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isLogout;
  final bool isConnected;

  const _ProfileCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.isLogout = false,
    this.isConnected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLogout 
              ? (Colors.red[200] ?? Colors.red)
              : isConnected
                  ? const Color(0xFF7B2CBF).withOpacity(0.3)
                  : (Colors.grey[200] ?? Colors.grey),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    gradient: isLogout
                        ? null
                        : isConnected
                            ? const LinearGradient(
                                colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                              )
                            : const LinearGradient(
                                colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                              ),
                    color: isLogout ? Colors.red[50] : null,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: isLogout
                        ? null
                        : [
                            BoxShadow(
                              color: const Color(0xFF7B2CBF).withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                  ),
                  child: Icon(
                    icon,
                    color: isLogout ? Colors.red[600] : Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: isLogout ? Colors.red[700] : const Color(0xFF1A1A1A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.grey[500],
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

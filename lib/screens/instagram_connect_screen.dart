import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/instagram_service.dart';

class InstagramConnectScreen extends StatefulWidget {
  const InstagramConnectScreen({super.key});

  @override
  State<InstagramConnectScreen> createState() => _InstagramConnectScreenState();
}

class _InstagramConnectScreenState extends State<InstagramConnectScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final InstagramService _instagramService = InstagramService();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  bool _isConnecting = false;
  Map<String, dynamic>? _instagramData;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _listener;

  @override
  void initState() {
    super.initState();
    _listenForUpdates();
  }

  @override
  void dispose() {
    _listener?.cancel();
    super.dispose();
  }

  void _listenForUpdates() {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final docRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('instagram_data')
        .doc('profile');

    _listener = docRef.snapshots().listen((snapshot) {
      setState(() {
        _instagramData = snapshot.data();
        _isLoading = false;
      });
    });
  }

  Future<void> _startInstagramOAuth() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in first.')),
      );
      return;
    }

    setState(() => _isConnecting = true);

    try {
      await _instagramService.connectInstagram(user.uid, null, null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Instagram account connected successfully.',
          ),
          duration: Duration(seconds: 5),
          backgroundColor: Color(0xFF6C5CE7),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Instagram connection failed: $error')),
      );
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _disconnectInstagram() async {
    final user = _auth.currentUser;
    if (user == null || _instagramData == null) return;

    await Future.wait([
      _firestore
          .collection('users')
          .doc(user.uid)
          .collection('instagram_data')
          .doc('profile')
          .delete()
          .catchError((_) {}),
      _firestore.collection('instagram_users').doc(user.uid).delete().catchError((_) {}),
    ]);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Instagram disconnected.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Instagram Analytics'),
        actions: [
          if (_instagramData != null)
            IconButton(
              onPressed: _disconnectInstagram,
              icon: const Icon(Icons.link_off_outlined),
              tooltip: 'Disconnect Instagram',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _instagramData == null
              ? _ConnectCard(
                  isConnecting: _isConnecting,
                  onConnect: _startInstagramOAuth,
                )
              : _ProfileCard(data: _instagramData!),
    );
  }
}

class _ConnectCard extends StatelessWidget {
  const _ConnectCard({required this.isConnecting, required this.onConnect});

  final bool isConnecting;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.analytics_outlined,
                    size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Connect your Instagram',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Unlock real-time analytics, monitor engagement, and track your best-performing posts.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(Icons.link_outlined),
                  onPressed: isConnecting ? null : onConnect,
                  label: Text(isConnecting ? 'Opening...' : 'Connect Instagram'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/schedule-post'),
                  icon: const Icon(Icons.schedule_send_outlined),
                  label: const Text('Schedule Post'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final username = data['username']?.toString() ?? 'unknown';
    final followers = (data['followers_count'] ?? 0) as num;
    final reach = (data['reach'] ?? 0) as num;
    final engagement = (data['engagement_rate'] ?? 0.0) as num;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '@$username',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StatChip(
                        label: 'Followers',
                        value: followers,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      _StatChip(
                        label: 'Reach',
                        value: reach,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(width: 12),
                      _StatChip(
                        label: 'Engagement',
                        value: '${engagement.toStringAsFixed(2)}%',
                        color: theme.colorScheme.tertiary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Latest sync: ${(data['updated_at'] as Timestamp?)?.toDate().toLocal() ?? '–'}',
                    style: theme.textTheme.bodySmall,
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

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final Object value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/instagram_service.dart';

class InstagramScreen extends StatefulWidget {
  const InstagramScreen({super.key});

  @override
  State<InstagramScreen> createState() => _InstagramScreenState();
}

class _InstagramScreenState extends State<InstagramScreen> {
  final InstagramService _instagramService = InstagramService();
  bool _isConnecting = false;
  bool _isConnected = false;
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Check if Instagram is already connected
    // In production, check Firestore for access token
    setState(() {
      _isConnected = false; // Default to false for demo
    });
  }

  Future<void> _connectInstagram() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isConnecting = true);

    try {
      // Check if user already has an Instagram account connected
      final hasExisting = await _instagramService.hasExistingInstagramAccount(user.uid);
      if (hasExisting) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only one Instagram account can be linked. Please log out the previous account to continue.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
        setState(() => _isConnecting = false);
        return;
      }

      // Instagram OAuth Flow
      // Step 1: Redirect to Instagram OAuth URL
      // In production, use actual Instagram App ID and redirect URI
      const oauthUrl = 'https://api.instagram.com/oauth/authorize?'
          'client_id=YOUR_CLIENT_ID&'
          'redirect_uri=YOUR_REDIRECT_URI&'
          'scope=user_profile,user_media&'
          'response_type=code';

      final uri = Uri.parse(oauthUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      // In production, handle the OAuth callback and exchange code for token
      // For now, simulate connection
      await Future.delayed(const Duration(seconds: 2));

      // Use the new connectInstagram method which checks for existing accounts
      final result = await _instagramService.connectInstagram(user.uid, 'mock_token');
      
      if (!mounted) return;
      
      if (result['success'] == true) {
        // Simulate fetching profile
        final profile = await _instagramService.getUserProfile('mock_token');
        
        setState(() {
          _isConnected = true;
          _profileData = profile;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Instagram connected successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Failed to connect Instagram account'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  Future<void> _disconnectInstagram() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // In production, remove access token from Firestore
    setState(() {
      _isConnected = false;
      _profileData = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Instagram disconnected')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Instagram Integration'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.camera_alt,
              size: 80,
              color: Colors.purple,
            ),
            const SizedBox(height: 16),
            const Text(
              'Connect Your Instagram Account',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Connect your Instagram to access analytics, schedule posts, and more!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),

            if (_isConnected && _profileData != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.purple,
                        child: Icon(Icons.person, size: 40, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _profileData!['username'] ?? 'Instagram User',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Account Type: ${_profileData!['account_type'] ?? 'PERSONAL'}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _disconnectInstagram,
                icon: const Icon(Icons.link_off),
                label: const Text('Disconnect Instagram'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ] else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.info_outline, size: 50, color: Colors.blue),
                      const SizedBox(height: 16),
                      const Text(
                        'What you\'ll get:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      _featureItem('📊 Access to detailed analytics'),
                      _featureItem('📅 Schedule posts directly'),
                      _featureItem('📈 Track post performance'),
                      _featureItem('🎯 Get AI-powered insights'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isConnecting ? null : _connectInstagram,
                icon: _isConnecting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link),
                label: Text(_isConnecting ? 'Connecting...' : 'Connect Instagram'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _featureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}


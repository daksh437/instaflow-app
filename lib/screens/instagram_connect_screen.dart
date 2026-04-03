import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class InstagramConnectScreen extends StatefulWidget {
  const InstagramConnectScreen({super.key});

  @override
  State<InstagramConnectScreen> createState() => _InstagramConnectScreenState();
}

class _InstagramConnectScreenState extends State<InstagramConnectScreen> {
  static const String _functionsBaseUrl = String.fromEnvironment(
    'FUNCTIONS_BASE_URL',
    defaultValue: 'https://insta-flow-backend.onrender.com',
  );

  static const String _oauthCallbackUrl =
      'https://insta-flow-backend.onrender.com/instagramOAuthCallback';

  final FirebaseAuth _auth = FirebaseAuth.instance;

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

  // Extract code from OAuth redirect URL
  String? _extractCodeFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final code = uri.queryParameters['code'];
      // ignore: avoid_print
      print('OAuth redirect URL: $url');
      // ignore: avoid_print
      print('Extracted Instagram code: $code');
      return code;
    } catch (e) {
      // ignore: avoid_print
      print('Error extracting code from URL: $e');
      return null;
    }
  }

  // Call Firebase function with the extracted code
  Future<void> _exchangeCodeWithFirebase(String instaAuthCode) async {
    // ignore: avoid_print
    print('Calling Firebase function with code: $instaAuthCode');
    
    try {
      final response = await http.post(
        Uri.parse('$_functionsBaseUrl/exchangeInstagramCode'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'code': instaAuthCode}),
      );

      // ignore: avoid_print
      print('Firebase function response status: ${response.statusCode}');
      // ignore: avoid_print
      print('Firebase function response body: ${response.body}');

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        // ignore: avoid_print
        print('✅ Instagram code exchanged successfully: $body');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Instagram connected successfully!'),
            backgroundColor: Color(0xFF6C5CE7),
          ),
        );
      } else {
        throw Exception(
          'Failed to exchange code (${response.statusCode}): ${response.body}',
        );
      }
    } catch (error) {
      // ignore: avoid_print
      print('❌ Error exchanging code with Firebase: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect Instagram: $error')),
      );
      rethrow;
    }
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

    // Log which endpoint we're calling (for easy debugging in console)
    // ignore: avoid_print
    print('[Instagram] Using Functions endpoint: $_functionsBaseUrl');

    setState(() => _isConnecting = true);

    try {
      // Build Instagram OAuth URL
      // Note: Replace these placeholders with your actual Instagram App credentials
      const String instagramClientId = 'YOUR_INSTAGRAM_CLIENT_ID';
      const String instagramRedirectUri = 'instaflow://oauth/callback'; // Custom scheme for mobile
      
      // For web, use a different redirect URI
      final String redirectUri = kIsWeb 
          ? '${Uri.base.origin}/instagram/callback'
          : instagramRedirectUri;
      
      final authUrl = Uri.https('api.instagram.com', '/oauth/authorize', {
        'client_id': instagramClientId,
        'redirect_uri': redirectUri,
        'scope': 'user_profile,user_media',
        'response_type': 'code',
      });

      // ignore: avoid_print
      print('Opening Instagram OAuth URL: $authUrl');

      if (kIsWeb) {
        // For web, we'll use a popup and listen for messages
        // This is a simplified approach - in production, you might want to use
        // a more robust solution with a dedicated callback page
        final launched = await launchUrl(
          authUrl,
          webOnlyWindowName: '_blank',
          mode: LaunchMode.externalApplication,
        );
        if (!launched) {
          throw Exception('Unable to open Instagram login.');
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Complete the Instagram login in the opened tab. Check the URL for the code parameter.'),
            duration: Duration(seconds: 10),
          ),
        );
        // Note: For web, you'll need to manually extract the code from the callback URL
        // or implement a proper callback handler page
        unawaited(_pollForConnection(user.uid));
      } else {
        // Mobile: Use WebView and intercept the redirect
        String? extractedCode;
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          isDismissible: false,
          builder: (context) {
            final controller = WebViewController()
              ..setJavaScriptMode(JavaScriptMode.unrestricted)
              ..setNavigationDelegate(
                NavigationDelegate(
                  onNavigationRequest: (request) {
                    final url = request.url;
                    // Check if URL contains the code parameter
                    final code = _extractCodeFromUrl(url);
                    
                    if (code != null) {
                      extractedCode = code;
                      Navigator.of(context).pop();
                      
                      // Exchange code with Firebase
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Instagram authorization complete. Connecting...'),
                          ),
                        );
                        unawaited(_exchangeCodeWithFirebase(code));
                      }
                      return NavigationDecision.prevent;
                    }
                    
                    return NavigationDecision.navigate;
                  },
                  onPageFinished: (url) {
                    // Also check onPageFinished as a fallback
                    final code = _extractCodeFromUrl(url);
                    if (code != null && extractedCode == null) {
                      extractedCode = code;
                      Navigator.of(context).pop();
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Instagram authorization complete. Connecting...'),
                          ),
                        );
                        unawaited(_exchangeCodeWithFirebase(code));
                      }
                    }
                  },
                ),
              )
              ..loadRequest(authUrl);

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.9,
                child: Column(
                  children: [
                    AppBar(
                      title: const Text('Instagram Login'),
                      leading: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    Expanded(
                      child: WebViewWidget(controller: controller),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    } catch (error) {
      // ignore: avoid_print
      print('❌ Instagram OAuth error: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Instagram connection failed: $error')),
      );
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _pollForConnection(String uid) async {
    const pollInterval = Duration(seconds: 3);
    const maxDuration = Duration(minutes: 2);
    var elapsed = Duration.zero;

    while (elapsed < maxDuration) {
      await Future.delayed(pollInterval);
      elapsed += pollInterval;

      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('instagram_data')
          .doc('profile')
          .get();

      if (doc.exists && doc.data()?['access_token'] != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Instagram account connected successfully!'),
            backgroundColor: Color(0xFF6C5CE7),
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Instagram login timed out. Please try again.'),
      ),
    );
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
    final theme = Theme.of(context);
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
          color: color.withOpacity(0.12),
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


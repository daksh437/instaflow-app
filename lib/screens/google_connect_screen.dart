import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';

class GoogleConnectScreen extends StatefulWidget {
  const GoogleConnectScreen({super.key});

  @override
  State<GoogleConnectScreen> createState() => _GoogleConnectScreenState();
}

class _GoogleConnectScreenState extends State<GoogleConnectScreen> {
  final _api = ApiService();
  bool _isConnected = false;
  bool _isChecking = false;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _checkConnectionStatus();
  }

  Future<void> _checkConnectionStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isChecking = true);
    try {
      final connected = await _api.getAuthStatus();
      setState(() {
        _isConnected = connected;
        _isChecking = false;
      });
    } catch (e) {
      setState(() => _isChecking = false);
      if (!mounted) return;
      
      // Don't show error if it's a connection/timeout issue (phone disconnected)
      if (e.toString().contains('CONNECTION_ERROR') || 
          e.toString().contains('TIMEOUT_ERROR')) {
        return; // Silently fail when phone is disconnected
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot check connection: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _connectGoogle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isConnecting = true);
    try {
      final url = await _api.getAuthUrl();
      if (url == null || url.isEmpty) {
        if (!mounted) return;
        setState(() => _isConnecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to get OAuth URL from backend. Please check server logs.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      // Try to launch URL directly - canLaunchUrl can give false negatives
      try {
        final uri = Uri.parse(url);
        
        // Check if URL can be launched (optional check)
        final canLaunch = await canLaunchUrl(uri);
        if (!canLaunch) {
          // Still try to launch - sometimes it works even if canLaunchUrl returns false
          print('Warning: canLaunchUrl returned false, but trying to launch anyway');
        }
        
        // Launch URL in external browser
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        
        if (launched) {
          // Wait a bit then check status
          await Future.delayed(const Duration(seconds: 2));
          _checkConnectionStatus();
        } else {
          if (!mounted) return;
          setState(() => _isConnecting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open browser. Please open this URL manually:\n$url'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 10),
            ),
          );
        }
      } catch (launchError) {
        if (!mounted) return;
        setState(() => _isConnecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening URL. Please try manually:\n$url'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    } catch (e) {
      setState(() => _isConnecting = false);
      if (!mounted) return;
      
      // Don't show error if it's a connection/timeout issue (phone disconnected)
      if (e.toString().contains('CONNECTION_ERROR') || 
          e.toString().contains('TIMEOUT_ERROR')) {
        return; // Silently fail when phone is disconnected
      }
      
      // Extract error message from response
      String errorMessage = 'Cannot connect to Google Calendar';
      if (e.toString().contains('Google OAuth not configured')) {
        errorMessage = 'Google Calendar integration is not configured on the server. Please contact support.';
      } else if (e.toString().contains('Missing userId')) {
        errorMessage = 'Please login first to connect Google Calendar.';
      } else {
        errorMessage = 'Cannot connect to Google Calendar: ${e.toString().replaceAll('Exception: ', '').replaceAll('Request failed: ', '')}';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      setState(() => _isConnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Calendar Connect'),
        backgroundColor: const Color(0xFF7B2CBF),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF8F6FF),
              Colors.white,
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: MediaQuery.of(context).padding.top + 20,
              bottom: 20,
            ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                // Status Card
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7B2CBF).withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _isConnected
                              ? const Color(0xFF7B2CBF).withOpacity(0.1)
                              : Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isConnected ? Icons.check_circle : Icons.calendar_today,
                          size: 64,
                          color: _isConnected ? const Color(0xFF7B2CBF) : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _isConnected ? 'Connected!' : 'Not Connected',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _isConnected ? const Color(0xFF7B2CBF) : Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isConnected
                            ? 'Your Google Calendar is connected. You can now schedule posts directly to your calendar.'
                            : 'Connect your Google Calendar to schedule AI-generated content directly to your calendar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Action Buttons
                if (!_isConnected)
                  ElevatedButton(
                    onPressed: _isConnecting ? null : _connectGoogle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7B2CBF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: _isConnecting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.link, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Connect Google Calendar',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ),

                const SizedBox(height: 16),

                // Refresh Button
                OutlinedButton(
                  onPressed: _isChecking ? null : _checkConnectionStatus,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF7B2CBF),
                    side: const BorderSide(color: Color(0xFF7B2CBF), width: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isChecking
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7B2CBF)),
                          ),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh, size: 20),
                            SizedBox(width: 8),
                            Text('Refresh Status', style: TextStyle(fontSize: 16)),
                          ],
                        ),
                ),

                const SizedBox(height: 20),

                // Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7B2CBF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFF7B2CBF)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'After connecting, you can schedule AI-generated content directly to your Google Calendar from the Calendar Generator screen.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'If you see a security warning:',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange[800],
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '1. Click "Advanced"\n2. Click "Go to InstaFlow (unsafe)"\n3. This is safe - app is in testing mode',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.orange[900],
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20), // Bottom padding
              ],
            ),
          ),
        ),
      ),
    );
  }
}


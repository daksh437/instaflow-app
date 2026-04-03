import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../config/app_secrets.dart';
import '../models/whatsapp_bot_storage.dart';
import '../services/whatsapp_bot_api_service.dart';
import 'shop_info_screen.dart' show ShopInfoScreen;

// Android-specific WebView configuration (mixed content mode).
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Facebook/Meta OAuth often redirects to custom schemes the WebView cannot load.
/// Open them in the Facebook app or system handler instead of crashing.
bool _isFacebookExternalScheme(String url) {
  final u = url.trim().toLowerCase();
  return u.startsWith('fb://') ||
      u.startsWith('facebook://') ||
      u.startsWith('intent://');
}

/// Tries to open [url] externally. Always returns [NavigationDecision.prevent]
/// for custom schemes so the WebView does not handle them.
Future<NavigationDecision> _openExternalCustomScheme(String url) async {
  try {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('[WebView] External scheme launch failed: $e');
      debugPrint('$st');
    }
  }
  return NavigationDecision.prevent;
}

/// Meta WhatsApp Business OAuth dialog URL (Facebook Login for Business).
/// [AppSecrets.metaFacebookAppId] must match your Meta app (replace default or use dart-define).
String _metaWhatsAppOAuthUrl() {
  final oauthUrl =
      'https://www.facebook.com/v19.0/dialog/oauth?'
      'client_id=${AppSecrets.metaFacebookAppId}'
      '&redirect_uri=${Uri.encodeComponent(AppSecrets.metaFacebookOAuthRedirectUri)}'
      '&scope=${Uri.encodeComponent('whatsapp_business_management,whatsapp_business_messaging')}'
      '&response_type=code';
  return oauthUrl;
}

/// Backend redirect after OAuth — must match [AppSecrets.metaFacebookOAuthRedirectUri].
bool _isAuthCallbackUrl(String url) {
  return url.toLowerCase().contains('/auth/callback');
}

/// Production-style Meta / Facebook OAuth WebView for WhatsApp Bot onboarding.
/// - Loads Facebook OAuth dialog (WhatsApp Business scopes).
/// - Detects redirect to `/auth/callback`, extracts `code`, then navigates to [ShopInfoScreen].
class WebViewScreen extends StatefulWidget {
  const WebViewScreen({
    super.key,
    /// Optional full OAuth URL (defaults to [_metaWhatsAppOAuthUrl]).
    this.oauthUrl,
  });

  /// If non-null, used instead of the built-in Meta WhatsApp OAuth URL.
  final String? oauthUrl;

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;

  /// Resolved OAuth URL (Meta dialog or [WebViewScreen.oauthUrl] override).
  late final String _oauthUrl;

  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _callbackHandled = false;

  @override
  void initState() {
    super.initState();
    _oauthUrl = widget.oauthUrl ?? _metaWhatsAppOAuthUrl();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            final urlStr = url.toString();
            debugPrint('Meta WebView onPageStarted: $urlStr');
            if (_callbackHandled) return;
            setState(() {
              _isLoading = true;
              _hasError = false;
              _errorMessage = null;
            });
            if (_isAuthCallbackUrl(urlStr)) {
              _handleCallback(urlStr);
            }
          },
          onPageFinished: (url) async {
            if (_callbackHandled) return;
            final urlStr = url.toString();
            debugPrint('Meta WebView onPageFinished: $urlStr');

            if (_isAuthCallbackUrl(urlStr)) {
              await _handleCallback(urlStr);
              return;
            }

            final finishedUri = Uri.tryParse(urlStr);
            if (finishedUri?.queryParameters.containsKey('error') ?? false) {
              setState(() {
                _isLoading = false;
                _hasError = true;
                _errorMessage = finishedUri!.queryParameters['error_description'] ??
                    finishedUri.queryParameters['error'] ??
                    'Something went wrong during login.';
              });
              return;
            }

            setState(() => _isLoading = false);
          },
          onNavigationRequest: (request) async {
            final url = request.url;
            debugPrint('Meta WebView onNavigationRequest: $url');
            if (_isFacebookExternalScheme(url)) {
              return _openExternalCustomScheme(url);
            }
            if (_isAuthCallbackUrl(url)) {
              _handleCallback(url);
              return NavigationDecision.prevent;
            }
            final navUri = Uri.tryParse(url);
            if (navUri?.queryParameters.containsKey('error') ?? false) {
              setState(() {
                _hasError = true;
                _errorMessage = navUri!.queryParameters['error_description'] ??
                    navUri.queryParameters['error'] ??
                    'Login failed. Please try again.';
              });
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            debugPrint(
              'Meta WebView onWebResourceError: ${error.errorCode} - ${error.description}',
            );
            if (_callbackHandled) return;
            setState(() {
              _isLoading = false;
              _hasError = true;
              _errorMessage = error.description.isNotEmpty
                  ? error.description
                  : 'Failed to load the page.';
            });
          },
        ),
      );

    _configureAndroidSettingsAndLoad();
  }

  Future<void> _handleCallback(String callbackUrl) async {
    if (_callbackHandled) return;
    _callbackHandled = true;

    final uri = Uri.tryParse(callbackUrl);
    final query = uri?.queryParameters ?? <String, String>{};

    final code = query['code'];
    if (code != null && code.isNotEmpty) {
      debugPrint('[Meta OAuth] authorization code: $code');
    } else {
      debugPrint('[Meta OAuth] callback without code: $callbackUrl');
    }

    final tokenFromQuery =
        query['access_token'] ?? query['token'] ?? code;

    final mockToken = (tokenFromQuery != null && tokenFromQuery.isNotEmpty)
        ? tokenFromQuery
        : 'mock_token_${DateTime.now().millisecondsSinceEpoch}';

    final prev = await WhatsAppBotStorage.load();
    await WhatsAppBotStorage.save(prev.copyWith(connected: true));

    try {
      await WhatsAppBotApiService().connectWhatsApp(
        accessToken: mockToken,
        code: code,
      ).timeout(const Duration(seconds: 12));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[WebView] connectWhatsApp backend (non-fatal): $e');
      }
    }

    if (!mounted) return;

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const ShopInfoScreen(),
      ),
    );
  }

  Future<void> _configureAndroidSettingsAndLoad() async {
    try {
      await (_controller as dynamic).setDomStorageEnabled(true);
      debugPrint('Meta WebView DOM storage enabled');
    } catch (e) {
      debugPrint('Meta WebView DOM storage skipped: $e');
    }

    try {
      await (_controller as dynamic).setMixedContentMode(
        MixedContentMode.alwaysAllow,
      );
    } catch (e) {
      debugPrint('Meta WebView mixed content skipped: $e');
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });
    await _controller.loadRequest(Uri.parse(_oauthUrl));
  }

  void _retry() {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
      _callbackHandled = false;
    });
    _controller.loadRequest(Uri.parse(_oauthUrl));
  }

  Future<void> _confirmLeave() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel login?'),
        content: const Text(
          'Do you want to stop the Meta / Facebook login flow?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (shouldLeave == true && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _onPopInvoked(bool didPop, dynamic result) async {
    if (didPop) return;
    await _confirmLeave();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF25D366);
    const barBg = Color(0xFF0B0B10);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPopInvoked,
      child: Scaffold(
        backgroundColor: barBg,
        appBar: AppBar(
          backgroundColor: barBg,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text('Meta Login'),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: _confirmLeave,
            tooltip: 'Close',
          ),
        ),
        body: _hasError
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded, size: 48, color: accent),
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage ?? 'Failed to load.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _retry,
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('Retry'),
                      ),
                      TextButton(
                        onPressed: _confirmLeave,
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: WebViewWidget(controller: _controller),
                  ),
                  if (_isLoading && !_callbackHandled)
                    ColoredBox(
                      color: const Color(0x33000000),
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(accent),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class WhatsAppBotWebViewScreen extends StatefulWidget {
  const WhatsAppBotWebViewScreen({
    super.key,
    required this.url,
    this.redirectUrlContains = '/callback',
  });

  final String url;
  final String redirectUrlContains;

  @override
  State<WhatsAppBotWebViewScreen> createState() =>
      _WhatsAppBotWebViewScreenState();
}

class _WhatsAppBotWebViewScreenState extends State<WhatsAppBotWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _error = false;
  String? _errorMessage;
  bool _callbackHandled = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            final urlStr = url.toString();
            debugPrint('WhatsAppBot WebView onPageStarted: $urlStr');
            setState(() {
              _loading = true;
              _error = false;
              _errorMessage = null;
            });

            // If needed later: you can detect success URLs here.
          },
          onPageFinished: (url) async {
            if (_error) return;
            final urlStr = url.toString();
            debugPrint('WhatsAppBot WebView onPageFinished: $urlStr');

            if (_isCallbackUrl(urlStr)) {
              await _handleCallback(urlStr);
              return;
            }

            if (urlStr.toLowerCase().contains('error')) {
              setState(() {
                _loading = false;
                _error = true;
                _errorMessage = 'Something went wrong during login.';
              });
              return;
            }

            setState(() => _loading = false);
          },
          onNavigationRequest: (request) async {
            final url = request.url;
            debugPrint('WhatsAppBot WebView onNavigationRequest: $url');
            if (_isFacebookExternalScheme(url)) {
              return _openExternalCustomScheme(url);
            }
            if (_isCallbackUrl(url)) {
              await _handleCallback(url);
              return NavigationDecision.prevent;
            }
            if (url.toLowerCase().contains('error')) {
              setState(() {
                _error = true;
                _errorMessage = 'Login failed. Please try again.';
              });
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            debugPrint(
              'WhatsAppBot WebView onWebResourceError: ${error.errorCode} - ${error.description}',
            );
            setState(() {
              _loading = false;
              _error = true;
              _errorMessage = error.description.isNotEmpty
                  ? error.description
                  : 'Failed to load the page.';
            });
          },
        ),
      )
      ;

    _configureAndroidSettingsAndLoad();
  }

  Future<void> _configureAndroidSettingsAndLoad() async {
    // Android-only settings: enable DOM storage and allow mixed content.
    // If unsupported, we log and continue (still loads the URL).
    try {
      await (_controller as dynamic).setDomStorageEnabled(true);
      debugPrint('WhatsAppBot DOM storage enabled ✅');
    } catch (e) {
      debugPrint('WhatsAppBot DOM storage enable skipped (not supported): $e');
    }

    try {
      await (_controller as dynamic).setMixedContentMode(
        MixedContentMode.alwaysAllow,
      );
      debugPrint('WhatsAppBot mixed content mode alwaysAllow ✅');
    } catch (e) {
      debugPrint('WhatsAppBot mixed content enable skipped (not supported): $e');
    }

    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = false;
      _errorMessage = null;
    });

    await _controller.loadRequest(Uri.parse(widget.url));
  }

  bool _isCallbackUrl(String url) {
    return url.contains(widget.redirectUrlContains);
  }

  Future<void> _handleCallback(String callbackUrl) async {
    if (_callbackHandled) return;
    _callbackHandled = true;

    // Extract token mock for now.
    final uri = Uri.tryParse(callbackUrl);
    final query = uri?.queryParameters ?? <String, String>{};

    final tokenFromQuery =
        query['access_token'] ?? query['token'] ?? query['code'];

    // Extract token mock for now (kept for debugging only).
    final mockToken = (tokenFromQuery != null && tokenFromQuery.isNotEmpty)
        ? tokenFromQuery
        : 'mock_token_${DateTime.now().millisecondsSinceEpoch}';
    // ignore: avoid_print
    debugPrint('WhatsApp callback token (mock): $mockToken');

    // Persist minimal onboarding state locally.
    final prev = await WhatsAppBotStorage.load();
    await WhatsAppBotStorage.save(
      prev.copyWith(
        connected: true,
      ),
    );

    try {
      await WhatsAppBotApiService().connectWhatsApp(
        accessToken: mockToken,
        code: query['code'],
      ).timeout(const Duration(seconds: 12));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[WebView alt] connectWhatsApp backend (non-fatal): $e');
      }
    }

    if (!mounted) return;

    // Go next step (replace this screen).
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const ShopInfoScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF25D366);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text('WhatsApp Login'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => _confirmCancel(),
          tooltip: 'Cancel',
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _error
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 34,
                              color: accent,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _errorMessage ?? 'Login failed.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF111111),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 14),
                            FilledButton(
                              onPressed: () {
                                setState(() {
                                  _error = false;
                                  _errorMessage = null;
                                  _loading = true;
                                });
                                _controller.loadRequest(
                                  Uri.parse(widget.url),
                                );
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text('Try again'),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => _confirmCancel(),
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Stack(
                      children: [
                        Positioned.fill(
                          child: WebViewWidget(controller: _controller),
                        ),
                        if (_loading)
                          IgnorePointer(
                            child: Center(
                              child: CircularProgressIndicator(
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(
                                  accent,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancel() async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF14141A),
        title: const Text(
          'Cancel login?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Do you want to stop the WhatsApp login flow?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Keep going',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (shouldCancel == true && Navigator.of(context).canPop()) {
      Navigator.pop(context);
    }
  }
}


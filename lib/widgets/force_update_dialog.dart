import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/remote_config_service.dart';
import '../utils/app_error_handler.dart';

/// Shows a non-dismissible force-update dialog when Remote Config min_app_version > current version.
class ForceUpdateGate extends StatefulWidget {
  final Widget child;

  const ForceUpdateGate({super.key, required this.child});

  @override
  State<ForceUpdateGate> createState() => _ForceUpdateGateState();
}

class _ForceUpdateGateState extends State<ForceUpdateGate> {
  bool _checkDone = false;
  bool _forceUpdateRequired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForceUpdate());
  }

  Future<void> _checkForceUpdate() async {
    try {
      final required = await RemoteConfigService()
          .isForceUpdateRequired()
          .timeout(const Duration(seconds: 5));
      if (!mounted) return;
      setState(() {
        _checkDone = true;
        _forceUpdateRequired = required;
      });
      if (required) _showForceUpdateDialog();
    } catch (e) {
      if (mounted) setState(() => _checkDone = true);
    }
  }

  void _showForceUpdateDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Update required'),
        content: const Text(
          'A new version of the app is available. Please update to continue using InstaFlow.',
        ),
        actions: [
          TextButton(
            onPressed: () => _openStore(),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _openStore() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final uri = Uri.parse(
        'https://play.google.com/store/apps/details?id=${info.packageName}',
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        AppErrorHandler.log('ForceUpdateOpenStore', e);
        AppErrorHandler.show(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

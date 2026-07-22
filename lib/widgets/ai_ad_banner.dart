import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ad_service.dart';

/// Bottom banner ad for AI tool screens. Shows for non-premium users
/// (trial + free), renders nothing for active premium. Self-contained — loads
/// its own banner so it can appear on many screens at once. Drop it into a
/// screen's `bottomNavigationBar` (or at the end of a Column).
class AiAdBanner extends StatefulWidget {
  const AiAdBanner({super.key});

  @override
  State<AiAdBanner> createState() => _AiAdBannerState();
}

class _AiAdBannerState extends State<AiAdBanner> {
  // Production banner unit (same as AdService).
  static const String _adUnitId = 'ca-app-pub-6637437102244163/3436045994';

  BannerAd? _ad;
  bool _loaded = false;
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _maybeLoad();
  }

  Future<void> _maybeLoad() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final show = await AdService().shouldShowAdsAsync(uid);
      if (!show || !mounted) return;
      setState(() => _show = true);
      final ad = BannerAd(
        adUnitId: _adUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) {
            if (mounted) setState(() => _loaded = true);
          },
          onAdFailedToLoad: (ad, _) => ad.dispose(),
        ),
      );
      _ad = ad;
      await ad.load();
    } catch (_) {
      // Never let an ad error break the screen.
    }
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_show || !_loaded || _ad == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: SizedBox(
        height: _ad!.size.height.toDouble(),
        width: double.infinity,
        child: AdWidget(ad: _ad!),
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'analytics_service.dart';

/// AdMob Service - Manages banner, interstitial and rewarded ads
/// Production-ready service with proper user segmentation
/// 
/// Rules:
/// - Show ads for: new users, trial users, free users (after trial), any non-premium.
/// - Do NOT show ads only when: user.isPremium == true AND premiumExpiry is in the future.
/// - Payment flow: NO ads (disabled during checkout).
/// - Interstitial: after each successful AI generation for non-premium users.
class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();
  
  /// Initialize AdMob (called from main.dart)
  static Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize();
      if (kDebugMode) debugPrint('[AdService] ✅ AdMob initialized successfully');
    } catch (e) {
      if (kDebugMode) debugPrint('[AdService] ⚠️ AdMob initialization failed: $e');
      // Fail-safe: App continues normally even if ads fail to initialize
    }
  }
  
  /// Set payment flow state (prevents ads during checkout)
  void setPaymentFlowActive(bool isActive) {
    _isPaymentFlowActive = isActive;
    if (isActive) {
      // Dispose any loaded ads when entering payment flow
      _interstitialAd?.dispose();
      _interstitialAd = null;
      _isInterstitialAdLoaded = false;
      if (kDebugMode) debugPrint('[AdService] Payment flow active - ads disabled');
    }
  }
  
  /// No-op kept for app startup compatibility.
  void resetSession() {
    if (kDebugMode) debugPrint('[AdService] Session reset');
  }

  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  bool _isBannerAdLoaded = false;
  bool _isInterstitialAdLoaded = false;
  bool _isRewardedAdLoaded = false;
  
  // Flag to prevent ads during payment flow
  bool _isPaymentFlowActive = false;

  // Production AdMob ad unit IDs
  static const String _bannerAdUnitId = 'ca-app-pub-6637437102244163/3436045994'; // PRODUCTION
  static const String _interstitialAdUnitId = 'ca-app-pub-6637437102244163/3158281181'; // PRODUCTION
  static const String _rewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917'; // TEST ID - Not currently used in app. Replace with production ID if implemented in future.

  /// Sync: should show ads? Block when premium active or during payment flow.
  bool shouldShowAds(UserModel? userModel) {
    if (_isPaymentFlowActive) return false;
    if (userModel == null) return true;
    final now = DateTime.now();
    final isPremiumActive = userModel.isPremium &&
        userModel.premiumExpiry != null &&
        (userModel.premiumExpiry?.isAfter(now) ?? false);
    return !isPremiumActive;
  }

  /// Async: fetch user and return whether to show ads (false only for active premium / payment flow).
  Future<bool> shouldShowAdsAsync(String? userId) async {
    try {
      if (_isPaymentFlowActive) {
        if (kDebugMode) debugPrint('[AdService] shouldShowAds: payment flow active → false (no ads)');
        return false;
      }
      if (userId == null) {
        if (kDebugMode) debugPrint('[AdService] shouldShowAds: userId null → true (show ads)');
        return true;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (!userDoc.exists) {
        if (kDebugMode) debugPrint('[AdService] shouldShowAds: no user doc (new user) → true (show ads)');
        return true;
      }

      final data = userDoc.data();
      if (data == null) return true;
      final userModel = UserModel.fromFirestore(data, userId);
      return shouldShowAds(userModel);
    } catch (e) {
      if (kDebugMode) debugPrint('[AdService] shouldShowAdsAsync: error $e → true (show ads, safe fallback)');
      return true;
    }
  }

  /// Load interstitial ad (pre-loads in background, non-blocking)
  /// Only loads for free/trial users, never for premium or during payment
  Future<void> loadInterstitialAd() async {
    try {
      // Never load during payment flow
      if (_isPaymentFlowActive) {
        return;
      }
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Check if user should see ads
      final shouldShow = await shouldShowAdsAsync(user.uid);
      if (!shouldShow) {
        // Premium user - don't load ads
        if (kDebugMode) debugPrint('[AdService] Skipping interstitial load - premium user');
        return;
      }

      // Don't reload if already loaded
      if (_isInterstitialAdLoaded || _interstitialAd != null) {
        return;
      }

      if (kDebugMode) debugPrint('[AdService] Loading interstitial ad...');
      await InterstitialAd.load(
        adUnitId: _interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            _interstitialAd = ad;
            _isInterstitialAdLoaded = true;
            if (kDebugMode) debugPrint('[AdService] ✅ Interstitial ad loaded successfully');
          },
          onAdFailedToLoad: (LoadAdError error) {
            if (kDebugMode) debugPrint('[AdService] ❌ Interstitial ad failed to load: $error');
            _interstitialAd = null;
            _isInterstitialAdLoaded = false;
            // Fail-safe: App continues normally
          },
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[AdService] ❌ Error loading interstitial ad: $e');
      // Fail-safe: App continues normally
    }
  }

  /// Show interstitial ad (non-blocking, fails gracefully)
  /// Rules:
  /// - Only for non-premium users (trial + free)
  /// - Never during payment flow
  /// - Never blocks UI while loading
  Future<bool> showInterstitialAd() async {
    try {
      if (_isPaymentFlowActive) {
        if (kDebugMode) debugPrint('[AdService] Skipping interstitial - payment flow active');
        return false;
      }
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return false;
      }

      // Double-check: User should see ads
      final shouldShow = await shouldShowAdsAsync(user.uid);
      if (!shouldShow) {
        if (kDebugMode) debugPrint('[AdService] Skipping interstitial - user is premium');
        return false;
      }
      
      // Check if ad is loaded and ready
      if (!_isInterstitialAdLoaded || _interstitialAd == null) {
        if (kDebugMode) debugPrint('[AdService] Interstitial not loaded yet - preloading for next time');
        // Preload for next time (non-blocking)
        loadInterstitialAd();
        return false;
      }

      if (kDebugMode) debugPrint('[AdService] Showing interstitial ad...');
      
      final interstitialAd = _interstitialAd;
      if (interstitialAd == null) return false;
      interstitialAd.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (InterstitialAd ad) {
          if (kDebugMode) debugPrint('[AdService] ✅ Interstitial ad dismissed');
          ad.dispose();
          _interstitialAd = null;
          _isInterstitialAdLoaded = false;
          loadInterstitialAd();
        },
        onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
          if (kDebugMode) debugPrint('[AdService] ❌ Interstitial ad failed to show: $error');
          ad.dispose();
          _interstitialAd = null;
          _isInterstitialAdLoaded = false;
          // Fail-safe: Continue normally
        },
      );

      await interstitialAd.show();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[AdService] ❌ Error showing interstitial ad: $e');
      // Fail-safe: App continues normally
      return false;
    }
  }

  /// Load rewarded ad
  Future<void> loadRewardedAd() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Check if user should see ads
      final shouldShow = await shouldShowAdsAsync(user.uid);
      if (!shouldShow) {
        // Premium user - don't load ads
        return;
      }

      if (_isRewardedAdLoaded) return;

      await RewardedAd.load(
        adUnitId: _rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            _rewardedAd = ad;
            _isRewardedAdLoaded = true;
            if (kDebugMode) debugPrint('[AdService] ✅ Rewarded ad loaded');
          },
          onAdFailedToLoad: (LoadAdError error) {
            if (kDebugMode) debugPrint('[AdService] ❌ Rewarded ad failed to load: $error');
            _rewardedAd = null;
            _isRewardedAdLoaded = false;
          },
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[AdService] ❌ Error loading rewarded ad: $e');
    }
  }

  /// Show rewarded ad (if loaded and user should see ads)
  Future<bool> showRewardedAd({
    required Function() onReward,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Check if user should see ads
      final shouldShow = await shouldShowAdsAsync(user.uid);
      final rewardedAd = _rewardedAd;
      if (!shouldShow || !_isRewardedAdLoaded || rewardedAd == null) {
        return false;
      }

      rewardedAd.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (RewardedAd ad) {
          ad.dispose();
          _rewardedAd = null;
          _isRewardedAdLoaded = false;
          // Reload for next use
          loadRewardedAd();
        },
        onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
          if (kDebugMode) debugPrint('[AdService] ❌ Rewarded ad failed to show: $error');
          ad.dispose();
          _rewardedAd = null;
          _isRewardedAdLoaded = false;
        },
      );

      rewardedAd.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          if (kDebugMode) debugPrint('[AdService] ✅ User earned reward: ${reward.amount} ${reward.type}');
          AnalyticsService.logRewardedAdCompleted(
            rewardType: reward.type,
            rewardAmount: reward.amount.toInt(),
          );
          AnalyticsService.logRewardedAdUsed();
          onReward();
        },
      );
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[AdService] ❌ Error showing rewarded ad: $e');
      return false;
    }
  }

  /// Load banner ad (for free/trial users only, never for premium)
  /// Safe to call multiple times - only loads once
  Future<void> loadBannerAd() async {
    try {
      // Never load during payment flow
      if (_isPaymentFlowActive) {
        return;
      }
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Check if user should see ads
      final shouldShow = await shouldShowAdsAsync(user.uid);
      if (!shouldShow) {
        if (kDebugMode) debugPrint('[AdService] Skipping banner load - premium user');
        return;
      }

      // Don't reload if already loaded
      if (_isBannerAdLoaded || _bannerAd != null) {
        return;
      }

      if (kDebugMode) debugPrint('[AdService] Loading banner ad...');
      _bannerAd = BannerAd(
        adUnitId: _bannerAdUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) {
            _isBannerAdLoaded = true;
            if (kDebugMode) debugPrint('[AdService] ✅ Banner ad loaded successfully');
          },
          onAdFailedToLoad: (ad, error) {
            if (kDebugMode) debugPrint('[AdService] ❌ Banner ad failed to load: $error');
            ad.dispose();
            _bannerAd = null;
            _isBannerAdLoaded = false;
            // Fail-safe: App continues normally, UI just won't show banner
          },
        ),
      );

      _bannerAd?.load();
    } catch (e) {
      if (kDebugMode) debugPrint('[AdService] ❌ Error loading banner ad: $e');
      // Fail-safe: App continues normally
    }
  }

  /// Get banner ad widget (if loaded and user should see ads)
  /// Returns null if:
  /// - Ad not loaded
  /// - User is premium
  /// - Payment flow is active
  Future<Widget?> getBannerAdWidget() async {
    // Never show during payment flow
    if (_isPaymentFlowActive) {
      return null;
    }
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    
    // Double-check: User should see ads
    final shouldShow = await shouldShowAdsAsync(user.uid);
    if (!shouldShow) {
      return null;
    }
    
    final bannerAd = _bannerAd;
    if (_isBannerAdLoaded && bannerAd != null) {
      return AdWidget(ad: bannerAd);
    }
    return null;
  }
  
  /// Check if banner ad is loaded (for UI optimization)
  bool isBannerAdLoaded() {
    return _isBannerAdLoaded && _bannerAd != null;
  }

  /// Dispose all ads and reset state
  /// Call this when app is closing or user logs out
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _bannerAd = null;
    _interstitialAd = null;
    _rewardedAd = null;
    _isBannerAdLoaded = false;
    _isInterstitialAdLoaded = false;
    _isRewardedAdLoaded = false;
    _isPaymentFlowActive = false;
    if (kDebugMode) debugPrint('[AdService] All ads disposed and state reset');
  }
}


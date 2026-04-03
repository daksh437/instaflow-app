import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'api_service.dart';

/// Backend is single source of truth. PlanManager calls /check-ai-access and maps response directly.
/// Never compute plan locally; never override planType or dailyLimit.
class PlanState {
  const PlanState({
    required this.planType,
    this.dailyUsed,
    this.dailyLimit,
    this.trialEndDate,
    this.premiumExpiry,
    this.resetAtUtc,
    this.allowed = true,
    this.trialDaysLeft,
  });

  final String planType;
  final int? dailyUsed;
  final int? dailyLimit;
  final DateTime? trialEndDate;
  final DateTime? premiumExpiry;
  final String? resetAtUtc;
  final bool allowed;
  final int? trialDaysLeft;

  bool get isTrial => planType == 'trial';
  bool get isPremium => planType == 'premium';
  bool get isFree => planType == 'free';

  /// Remaining today. Only meaningful for free plan when dailyLimit is set by backend.
  int get remainingToday {
    if (planType != 'free' || dailyLimit == null || dailyUsed == null) return 0;
    return (dailyLimit! - dailyUsed!).clamp(0, dailyLimit!);
  }

  /// Show daily counter only for free plan.
  bool get shouldShowCounter => planType == 'free' && dailyLimit != null;
}

/// Fetches /check-ai-access and exposes PlanState. No local fallbacks.
class PlanManager {
  PlanManager({ApiService? api}) : _api = api ?? ApiService();

  static PlanManager? _instance;
  static PlanManager get instance => _instance ??= PlanManager();

  final ApiService _api;
  final ValueNotifier<PlanState?> _state = ValueNotifier<PlanState?>(null);

  PlanState? get currentState => _state.value;
  ValueNotifier<PlanState?> get state => _state;

  static DateTime? _parseTrialEndDate(dynamic v) {
    if (v == null) return null;
    if (v is String) {
      try {
        return DateTime.parse(v);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Refresh from backend. Map response directly; no planType ?? 'free', no dailyLimit ?? 2.
  Future<PlanState> refresh() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      final s = PlanState(planType: 'free', allowed: false, dailyUsed: 0, dailyLimit: 2);
      _state.value = s;
      return s;
    }
    try {
      final data = await _api.checkAiAccess();
      final planType = data['planType'] is String ? (data['planType'] as String).trim().toLowerCase() : 'free';
      final trialEndDate = _parseTrialEndDate(data['trialEndDate']);
      final trialDaysLeft = data['trialDaysLeft'] is int ? data['trialDaysLeft'] as int : null;
      final resetAtUtc = data['resetAtUtc'] is String ? data['resetAtUtc'] as String? : null;

      if (planType == 'trial') {
        final s = PlanState(
          planType: 'trial',
          dailyUsed: 0,
          dailyLimit: null,
          trialEndDate: trialEndDate,
          resetAtUtc: null,
          allowed: true,
          trialDaysLeft: trialDaysLeft ?? 0,
        );
        _state.value = s;
        return s;
      }

      if (planType == 'premium') {
        final premiumExpiry = _parseTrialEndDate(data['premiumExpiry']);
        final s = PlanState(
          planType: 'premium',
          dailyUsed: null,
          dailyLimit: null,
          trialEndDate: null,
          premiumExpiry: premiumExpiry,
          resetAtUtc: null,
          allowed: true,
          trialDaysLeft: null,
        );
        _state.value = s;
        return s;
      }

      final dailyUsed = data['dailyUsed'] is int ? data['dailyUsed'] as int : 0;
      final dailyLimit = data['dailyLimit'] is int ? data['dailyLimit'] as int : null;
      final allowed = data['allowed'] == true;
      final s = PlanState(
        planType: 'free',
        dailyUsed: dailyLimit != null ? dailyUsed : 0,
        dailyLimit: dailyLimit,
        trialEndDate: null,
        resetAtUtc: resetAtUtc,
        allowed: allowed,
        trialDaysLeft: null,
      );
      _state.value = s;
      return s;
    } catch (e) {
      if (kDebugMode) debugPrint('[PlanManager] refresh failed: $e');
      final s = PlanState(planType: 'free', allowed: false, dailyUsed: 0, dailyLimit: null);
      _state.value = s;
      return s;
    }
  }

  /// Stream that periodically refreshes and emits latest PlanState.
  Stream<PlanState> get planStream async* {
    await refresh();
    final current = _state.value;
    if (current != null) yield current;
    await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
      await refresh();
      final s = _state.value;
      if (s != null) yield s;
    }
  }

  void dispose() {
    if (identical(this, _instance)) _instance = null;
  }
}

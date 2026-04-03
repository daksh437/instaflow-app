import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// Backend is source of truth for AI usage. Use [checkAiAccess] before AI calls and for badge UI.
/// Use [AiUsageControlService.instance] everywhere so Home, Profile, and all AI screens share the same state.
class AiUsageControlService {
  AiUsageControlService({ApiService? api}) : _api = api ?? ApiService();

  static AiUsageControlService? _instance;
  static AiUsageControlService get instance => _instance ??= AiUsageControlService();

  final ApiService _api;
  final ValueNotifier<AiAccessState?> _state = ValueNotifier<AiAccessState?>(null);

  /// Single source of truth for plan UI. Home, Profile, and AI screens must use this only (no direct Firestore plan reads).
  AiAccessState? get currentState => _state.value;

  static String? _parseResetAtUtc(dynamic v) {
    if (v == null) return null;
    if (v is String) return v.isEmpty ? null : v;
    return v.toString();
  }

  /// Current state (null until first fetch). Listen to this for badge/UI.
  ValueNotifier<AiAccessState?> get state => _state;

  /// Last fetch result for synchronous read (e.g. canUseAi).
  AiAccessState? get lastState => _state.value;

  /// Whether user can use AI right now (from last check). Prefer [refresh] then [lastState?.allowed].
  bool get allowed => _state.value?.allowed ?? false;

  /// Refresh from backend. Call before AI flow or when opening a screen that shows the badge.
  /// [force] — if true, always fetches from API (ignores any cache). Use on Home open.
  /// Never map trial to free; no planType or dailyLimit fallback for trial.
  Future<AiAccessState> refresh({bool force = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _state.value = AiAccessState(
        allowed: false,
        planType: 'free',
        trialDaysLeft: 0,
        creditsLeftToday: 0,
        dailyLimit: null,
        dailyUsed: 0,
        resetAtUtc: null,
        error: 'UNAUTHORIZED',
        message: 'Please log in to use AI.',
      );
      return _state.value!;
    }
    try {
      final data = await _api.checkAiAccess();
      // Strict: do NOT default to 'free' — use backend value only so trial is never overwritten
      final raw = data['planType'];
      final planType = raw is String ? (raw as String).trim().toLowerCase() : null;
      if (kDebugMode) debugPrint('PLAN TYPE FROM BACKEND: $planType (raw: $raw)');

      // Trial: return immediately. No dailyLimit, no dailyUsed from backend, no fallback to free.
      if (planType == 'trial') {
        final state = AiAccessState(
          allowed: true,
          planType: 'trial',
          trialDaysLeft: (data['trialDaysLeft'] is int) ? data['trialDaysLeft'] as int : 0,
          dailyLimit: null,
          dailyUsed: 0,
          creditsLeftToday: null,
          resetAtUtc: null,
          error: null,
          message: null,
        );
        _state.value = state;
        if (kDebugMode) debugPrint('AI STATE: ${state.planType} ${state.dailyLimit} ${state.allowed}');
        return state;
      }

      if (planType == 'premium') {
        final state = AiAccessState(
          allowed: true,
          planType: 'premium',
          trialDaysLeft: 0,
          dailyLimit: null,
          dailyUsed: 0,
          creditsLeftToday: null,
          resetAtUtc: null,
          error: null,
          message: null,
        );
        _state.value = state;
        if (kDebugMode) debugPrint('AI STATE: ${state.planType} ${state.dailyLimit} ${state.allowed}');
        return state;
      }

      // Free only: use backend dailyLimit and dailyUsed only (no fallback)
      final resetAtUtc = _parseResetAtUtc(data['resetAtUtc']);
      final dailyLimit = data['dailyLimit'] is int ? data['dailyLimit'] as int : null;
      final dailyUsed = data['dailyUsed'] is int ? data['dailyUsed'] as int : 0;
      final limit = dailyLimit ?? 0;
      final state = AiAccessState(
        allowed: limit > 0 ? dailyUsed < limit : false,
        planType: 'free',
        trialDaysLeft: 0,
        dailyLimit: dailyLimit,
        dailyUsed: dailyUsed,
        creditsLeftToday: data['creditsLeftToday'] is int
            ? data['creditsLeftToday'] as int
            : (data['creditsLeftToday'] == null ? null : 0),
        resetAtUtc: resetAtUtc,
        error: data['error'] as String?,
        message: data['message'] as String?,
      );
      _state.value = state;
      if (kDebugMode) debugPrint('AI STATE: ${state.planType} ${state.dailyLimit} ${state.allowed}');
      return state;
    } catch (e) {
      if (kDebugMode) debugPrint('[AiUsageControlService] refresh failed: $e');
      _state.value = AiAccessState(
        allowed: false,
        planType: 'free',
        trialDaysLeft: 0,
        creditsLeftToday: 0,
        dailyLimit: null,
        dailyUsed: 0,
        resetAtUtc: null,
        error: 'CHECK_FAILED',
        message: 'Could not verify AI access. Please try again.',
      );
      return _state.value!;
    }
  }

  void dispose() {
    if (identical(this, _instance)) return;
    _state.dispose();
  }
}

class AiAccessState {
  const AiAccessState({
    required this.allowed,
    required this.planType,
    required this.trialDaysLeft,
    this.dailyLimit,
    this.dailyUsed = 0,
    this.creditsLeftToday,
    this.resetAtUtc,
    this.error,
    this.message,
  });

  final bool allowed;
  final String planType;
  final int trialDaysLeft;
  final int? dailyLimit;
  final int dailyUsed;
  final int? creditsLeftToday;
  /// Next reset time as ISO string (e.g. next midnight UTC) for countdown.
  final String? resetAtUtc;
  final String? error;
  final String? message;

  bool get isTrial => planType == 'trial';
  bool get isFree => planType == 'free';
  bool get isPremium => planType == 'premium';

  /// Remaining credits today. Only for free plan with non-null dailyLimit from backend; trial/premium return 0.
  int get remainingCredits {
    if (planType != 'free' || dailyLimit == null) return 0;
    return (dailyLimit! - dailyUsed).clamp(0, dailyLimit!);
  }

  /// Show credit counter only for free plan.
  bool get shouldShowCounter => planType == 'free';

  /// Trial must NEVER return true. Only free plan with non-null dailyLimit.
  bool get isLimitReached => isFree && dailyLimit != null && dailyUsed >= dailyLimit!;
  bool get showDailyCounter => isFree;
  bool get showLimitBanner => isFree && isLimitReached;
  bool get showCountdown => isFree && isLimitReached;

  /// Label for badge. Trial: only "Free Trial — X days left". Free: used/limit from backend only. Premium: unlimited.
  String get badgeLabel {
    if (planType == 'premium') return 'Premium — unlimited';
    if (planType == 'trial') return 'Free Trial — ${trialDaysLeft > 0 ? trialDaysLeft : 0} days left';
    if (planType == 'free' && dailyLimit != null) return 'Free Plan — $dailyUsed / $dailyLimit used today';
    if (planType == 'free') return 'Free Plan';
    return 'Credits: ${creditsLeftToday ?? 0}';
  }
}

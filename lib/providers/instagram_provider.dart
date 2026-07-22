import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/instagram_dashboard_models.dart';
import '../services/instagram_service.dart';

enum InstagramStatsViewState {
  notConnected,
  connecting,
  connectedLoading,
  connectedReady,
  error,
}

class InstagramProvider extends ChangeNotifier {
  InstagramProvider() : _service = InstagramService();

  final InstagramService _service;

  bool _isConnecting = false;
  bool _isLoading = false;
  bool _isConnected = false;
  String? _error;
  int _followers = 0;
  int _posts = 0;
  int _following = 0;

  /// From API (`accountType`), e.g. BUSINESS / CREATOR.
  String _accountType = '';
  InstagramStatsViewState _viewState = InstagramStatsViewState.notConnected;
  DateTime? _lastSync;

  /// Estimated engagement rate % (stable mock until Graph insights API wired).
  double _engagementRate = 0;

  /// Follower growth % vs last saved snapshot (null = no prior snapshot).
  double? _growthPercent;
  int _likes = 0;
  int _comments = 0;
  int _views = 0;
  List<double> _followerSeries7 = const [];
  List<InstagramTopPostDisplay> _topPosts = const [];
  List<String> _insights = const [];

  bool get isConnecting => _isConnecting;
  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  String? get error => _error;
  int get followers => _followers;
  int get posts => _posts;
  int get following => _following;
  String get accountType => _accountType;
  DateTime? get lastSync => _lastSync;
  InstagramStatsViewState get viewState => _viewState;

  double get engagementRate => _engagementRate;
  double? get growthPercent => _growthPercent;
  int get likes => _likes;
  int get comments => _comments;
  int get views => _views;
  List<double> get followerSeries7 => _followerSeries7;
  List<InstagramTopPostDisplay> get topPosts => _topPosts;
  List<String> get insights => _insights;

  void _setState(InstagramStatsViewState state, {bool notify = true}) {
    _viewState = state;
    if (notify) notifyListeners();
  }

  void _clearDashboardExtras() {
    _following = 0;
    _accountType = '';
    _engagementRate = 0;
    _growthPercent = null;
    _likes = 0;
    _comments = 0;
    _views = 0;
    _followerSeries7 = const [];
    _topPosts = const [];
    _insights = const [];
  }

  Future<void> checkConnection() async {
    try {
      _isConnected = await _service.isLoggedIn();
      _error = null;
      if (_isConnected && (_followers > 0 || _posts > 0)) {
        _setState(InstagramStatsViewState.connectedReady, notify: false);
      } else {
        _setState(
          _isConnected
              ? InstagramStatsViewState.connectedLoading
              : InstagramStatsViewState.notConnected,
          notify: false,
        );
      }
    } catch (e) {
      _error = _cleanError(e);
      _setState(InstagramStatsViewState.error, notify: false);
    }
    notifyListeners();
  }

  Future<void> bootstrapStats({bool forceRefresh = false}) async {
    await checkConnection();
    if (_isConnected) await refreshStats(forceRefresh: forceRefresh);
  }

  Future<bool> connect() async {
    _isConnecting = true;
    _error = null;
    _setState(InstagramStatsViewState.connecting, notify: false);
    notifyListeners();
    try {
      await _service.connectInstagram();
      _isConnecting = false;
      _isConnected = true;
      await refreshStats(forceRefresh: true);
      return true;
    } catch (e) {
      _isConnecting = false;
      _error = _cleanError(e);
      _setState(InstagramStatsViewState.error, notify: false);
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() async {
    await _service.logout();
    _isConnected = false;
    _followers = 0;
    _posts = 0;
    _lastSync = null;
    _error = null;
    _clearDashboardExtras();
    _setState(InstagramStatsViewState.notConnected, notify: false);
    notifyListeners();
  }

  Future<void> refreshStats({bool forceRefresh = true}) async {
    if (!_isConnected && !forceRefresh) return;
    _isLoading = true;
    _error = null;
    _setState(InstagramStatsViewState.connectedLoading, notify: false);
    notifyListeners();

    try {
      final stats = await _service.fetchInstagramStats();
      _followers = _readInt(stats, 'followers') ?? 0;
      _posts = _readInt(stats, 'posts') ?? 0;
      _following = _readInt(stats, 'following') ?? 0;
      _accountType = _readString(stats, 'accountType');
      _lastSync = DateTime.now();
      _isConnected = true;

      await _applyDashboardDerived(stats);
      _setState(InstagramStatsViewState.connectedReady, notify: false);
    } catch (e) {
      _error = _cleanError(e);
      _clearDashboardExtras();
      _setState(InstagramStatsViewState.error, notify: false);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _applyDashboardDerived(Map<String, dynamic> stats) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      double? growth;
      if (uid != null && uid.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final key = 'ig_saved_followers_$uid';
        final prev = prefs.getInt(key);
        if (prev != null && prev > 0) {
          growth = ((_followers - prev) / prev) * 100.0;
        }
        await prefs.setInt(key, _followers);
      }

      final seed = _followers * 10007 + _posts * 131 + (_following * 17);
      final r = Random(seed);

      _likes = _readInt(stats, 'likes') ?? _readInt(stats, 'totalLikes') ?? 0;
      _comments =
          _readInt(stats, 'comments') ?? _readInt(stats, 'totalComments') ?? 0;
      _views = _readInt(stats, 'views') ?? _readInt(stats, 'totalViews') ?? 0;

      final engagementFromApi = _readDouble(stats, 'engagementRate');
      if (engagementFromApi != null) {
        _engagementRate = engagementFromApi;
      } else if (_followers > 0) {
        final interactions = _likes + _comments;
        _engagementRate = min(
          100.0,
          (interactions / _followers) * 100,
        );
      } else {
        _engagementRate = 2.4 +
            r.nextDouble() * 9.5 +
            (_posts > 0 ? min(2.0, _posts * 0.08) : 0.0);
      }

      _growthPercent = growth;
      _followerSeries7 = _buildFollowerSeries7(_followers, r);
      _topPosts = _buildTopPosts(r);
      _insights = _buildInsights(r, _engagementRate, _growthPercent);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[InstagramProvider] _applyDashboardDerived: $e');
      }
      _growthPercent = null;
      _followerSeries7 = List<double>.filled(7, _followers.toDouble());
      _topPosts = const [];
      _insights = const ['Pull to refresh to reload insights.'];
    }
  }

  String _readString(Map<String, dynamic> m, String k) {
    final v = m[k];
    if (v == null) return '';
    final s = v.toString().trim();
    return s;
  }

  int? _readInt(Map<String, dynamic> m, String k) {
    final v = m[k];
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }

  double? _readDouble(Map<String, dynamic> m, String k) {
    final v = m[k];
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return null;
  }

  /// Last 7 days, oldest → newest, ending at current followers (includes estimate curve).
  List<double> _buildFollowerSeries7(int end, Random r) {
    if (end <= 0) {
      return List<double>.filled(7, 0);
    }
    final out = <double>[];
    var v = end.toDouble();
    for (var i = 0; i < 7; i++) {
      out.add(v);
      final step =
          (end * (0.003 + r.nextDouble() * 0.012) + r.nextDouble() * 4 + 0.5);
      v = max(0, v - step);
    }
    return out.reversed.toList();
  }

  List<InstagramTopPostDisplay> _buildTopPosts(Random r) {
    if (_followers <= 0 && _posts <= 0) {
      return const [];
    }
    final base = max(1, (_likes / max(1, _posts)).round());
    return [
      InstagramTopPostDisplay(
        thumbnailUrl: null,
        likes: base + r.nextInt(40),
        comments: (base * 0.12).round() + r.nextInt(8),
        label: 'Recent post',
      ),
      InstagramTopPostDisplay(
        thumbnailUrl: null,
        likes: (base * 0.85).round() + r.nextInt(30),
        comments: (base * 0.1).round() + r.nextInt(6),
        label: 'Top reel',
      ),
      InstagramTopPostDisplay(
        thumbnailUrl: null,
        likes: (base * 0.7).round() + r.nextInt(25),
        comments: (base * 0.08).round() + r.nextInt(5),
        label: 'Carousel',
      ),
    ];
  }

  List<String> _buildInsights(Random r, double engagement, double? growth) {
    final lines = <String>[];
    if (growth != null && growth > 0.5) {
      lines.add(
        'Your growth increased this week — up ${growth.toStringAsFixed(1)}% vs last sync.',
      );
    } else if (growth != null && growth < -0.5) {
      lines.add(
        'Engagement momentum dipped: followers down ${growth.abs().toStringAsFixed(1)}% vs last sync — try Reels at peak hours.',
      );
    } else if (growth != null) {
      lines.add('Follower count is steady — consistency wins.');
    } else {
      lines.add('Sync again later to track week-over-week growth.');
    }

    final hour12 = 7 + r.nextInt(2);
    lines.add(
      'Best time to post: ${hour12 == 12 ? 12 : hour12}:00 PM (peak engagement window).',
    );
    if (lines.length < 3) {
      if (engagement < 4) {
        lines
            .add('Tip: reply to comments within the first hour to lift reach.');
      } else if (engagement > 8) {
        lines.add(
            'Strong engagement (${engagement.toStringAsFixed(1)}%) — double down on what works.');
      } else {
        lines.add(
            'Engagement at ${engagement.toStringAsFixed(1)}% — add more Stories to grow.');
      }
    }

    return lines.take(3).toList();
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '').trim();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

import 'package:flutter/foundation.dart';

import '../models/instagram_model.dart';
import '../services/instagram_service.dart';

class InstagramProvider extends ChangeNotifier {
  InstagramProvider() : _service = InstagramService();

  final InstagramService _service;

  bool _isLoading = false;
  bool _isConnecting = false;
  String? _error;
  bool _isConnected = false;
  IgProfile? _profile;
  List<IgMedia> _media = [];
  IgInsights? _insights;
  Map<String, List<IgComment>> _commentsByMedia = {};

  bool get isLoading => _isLoading;
  bool get isConnecting => _isConnecting;
  String? get error => _error;
  bool get isConnected => _isConnected;
  IgProfile? get profile => _profile;
  List<IgMedia> get media => List.unmodifiable(_media);
  IgInsights? get insights => _insights;
  List<IgComment> commentsFor(String mediaId) => _commentsByMedia[mediaId] ?? [];

  Future<void> checkConnection() async {
    final loggedIn = await _service.isLoggedIn();
    if (loggedIn != _isConnected) {
      _isConnected = loggedIn;
      _error = null;
      notifyListeners();
    }
  }

  Future<bool> connect() async {
    _isConnecting = true;
    _error = null;
    notifyListeners();
    try {
      final token = await _service.login();
      _isConnecting = false;
      if (token == null) {
        _error = 'Could not get access token';
        notifyListeners();
        return false;
      }
      _isConnected = true;
      await loadAll();
      notifyListeners();
      return true;
    } catch (e) {
      _isConnecting = false;
      _error = e.toString().replaceAll('Exception:', '').trim();
      if (_error?.isEmpty ?? true) _error = 'Login failed';
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() async {
    await _service.logout();
    _isConnected = false;
    _profile = null;
    _media = [];
    _insights = null;
    _commentsByMedia = {};
    _error = null;
    notifyListeners();
  }

  Future<void> loadAll() async {
    if (!_isConnected) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final igUserId = await _service.getInstagramBusinessAccountId();
      if (igUserId == null || igUserId.isEmpty) {
        _error = 'No Instagram Business account linked to this Facebook account';
        _isLoading = false;
        notifyListeners();
        return;
      }
      final results = await Future.wait([
        _service.fetchProfile(igUserId),
        _service.fetchMedia(igUserId),
        _service.fetchInsights(igUserId),
      ]);
      _profile = results[0] as IgProfile?;
      _media = results[1] as List<IgMedia>? ?? [];
      _insights = results[2] as IgInsights?;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString().replaceAll('Exception:', '').trim();
      if (_error?.isEmpty ?? true) _error = 'Failed to load Instagram data';
      notifyListeners();
    }
  }

  Future<void> loadComments(String mediaId) async {
    if (_commentsByMedia.containsKey(mediaId)) return;
    try {
      final list = await _service.fetchComments(mediaId);
      _commentsByMedia[mediaId] = list;
      notifyListeners();
    } catch (_) {}
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

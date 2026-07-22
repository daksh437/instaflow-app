import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/daily_mission_model.dart';
import 'api_service.dart';
import 'analytics_event_service.dart';
import 'notification_service.dart';

class RetentionService {
  RetentionService._();
  static final RetentionService instance = RetentionService._();

  final ApiService _api = ApiService();
  final AnalyticsEventService _analytics = AnalyticsEventService();

  Future<DailyMissionModel?> fetchTodayMission() async {
    try {
      final data = await _api.retentionMissionToday();
      final mission = data['mission'] as Map<String, dynamic>?;
      if (mission == null) return null;
      _analytics.logAppEvent('mission_viewed');
      return DailyMissionModel.fromMap(mission);
    } catch (e) {
      if (kDebugMode) debugPrint('[RetentionService] fetchTodayMission: $e');
      return null;
    }
  }

  Future<DailyMissionModel?> completeMissionTask(String taskType) async {
    try {
      final data = await _api.retentionMissionCompleteTask(taskType: taskType);
      final mission = data['mission'] as Map<String, dynamic>?;
      if (mission == null) return null;
      _analytics.logAppEvent('mission_task_completed', {'taskType': taskType});
      if (data['rewardGrantedNow'] == true) {
        _analytics.logAppEvent('mission_completed');
        _analytics.logAppEvent('streak_incremented');
      }
      return DailyMissionModel.fromMap(mission);
    } catch (e) {
      if (kDebugMode) debugPrint('[RetentionService] completeMissionTask: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchRecommendations() async {
    try {
      final data = await _api.retentionRecommendations();
      return data['data'] as Map<String, dynamic>?;
    } catch (e) {
      if (kDebugMode) debugPrint('[RetentionService] fetchRecommendations: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchWeeklyReport() async {
    try {
      final data = await _api.retentionWeeklyReport();
      final report = data['data'] as Map<String, dynamic>?;
      if (report != null) _analytics.logAppEvent('weekly_report_viewed');
      return report;
    } catch (e) {
      if (kDebugMode) debugPrint('[RetentionService] fetchWeeklyReport: $e');
      return null;
    }
  }

  Future<void> markToolUsed({
    required String tool,
    String? inputSnippet,
  }) async {
    try {
      await _api.retentionMarkToolUsed(tool: tool, inputSnippet: inputSnippet ?? '');
    } catch (e) {
      if (kDebugMode) debugPrint('[RetentionService] markToolUsed: $e');
    }
  }

  /// True when GET /retention/health succeeds (deployed backend includes retention routes).
  Future<bool> isRetentionBackendAvailable() async {
    return _api.retentionBackendAvailable();
  }

  Future<void> runSmartNotificationHints() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final mission = await fetchTodayMission();
      if (mission == null) return;
      if (!mission.isCompleted) {
        await NotificationService().showNotification(
          title: 'Keep your streak alive',
          body: 'Complete today\'s AI mission in InstaFlow.',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[RetentionService] runSmartNotificationHints: $e');
    }
  }
}

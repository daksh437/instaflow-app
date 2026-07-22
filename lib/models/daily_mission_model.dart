class DailyMissionTask {
  const DailyMissionTask({
    required this.id,
    required this.type,
    required this.completed,
  });

  final String id;
  final String type;
  final bool completed;

  factory DailyMissionTask.fromMap(Map<String, dynamic> m) {
    return DailyMissionTask(
      id: (m['id'] ?? '').toString(),
      type: (m['type'] ?? '').toString(),
      completed: m['completed'] == true,
    );
  }
}

class DailyMissionModel {
  const DailyMissionModel({
    required this.date,
    required this.tasks,
    required this.completedCount,
    required this.isCompleted,
    required this.rewardGranted,
  });

  final String date;
  final List<DailyMissionTask> tasks;
  final int completedCount;
  final bool isCompleted;
  final bool rewardGranted;

  factory DailyMissionModel.fromMap(Map<String, dynamic> map) {
    final rawTasks = (map['tasks'] as List?) ?? const [];
    return DailyMissionModel(
      date: (map['date'] ?? '').toString(),
      tasks: rawTasks
          .whereType<Map>()
          .map((e) => DailyMissionTask.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      completedCount: (map['completedCount'] is num) ? (map['completedCount'] as num).toInt() : 0,
      isCompleted: map['isCompleted'] == true,
      rewardGranted: map['rewardGranted'] == true,
    );
  }
}

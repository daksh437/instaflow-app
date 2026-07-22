class AiAdviceModel {
  const AiAdviceModel({
    required this.diagnosis,
    required this.whyItMatters,
    required this.actionSteps,
    required this.expectedOutcome,
    required this.avoidThis,
    required this.confidenceNote,
    required this.quickWin,
  });

  final String diagnosis;
  final String whyItMatters;
  final List<String> actionSteps;
  final String expectedOutcome;
  final String avoidThis;
  final String confidenceNote;
  final String quickWin;

  bool get isUsable =>
      diagnosis.isNotEmpty &&
      whyItMatters.isNotEmpty &&
      actionSteps.length >= 3 &&
      expectedOutcome.isNotEmpty;

  factory AiAdviceModel.fromMap(Map<String, dynamic> map) {
    final steps = ((map['action_steps'] as List?) ?? const [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return AiAdviceModel(
      diagnosis: (map['diagnosis'] ?? '').toString().trim(),
      whyItMatters: (map['why_it_matters'] ?? '').toString().trim(),
      actionSteps: steps,
      expectedOutcome: (map['expected_outcome'] ?? '').toString().trim(),
      avoidThis: (map['avoid_this'] ?? '').toString().trim(),
      confidenceNote: (map['confidence_note'] ?? '').toString().trim(),
      quickWin: (map['quick_win'] ?? '').toString().trim(),
    );
  }
}

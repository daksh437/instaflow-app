import 'dart:io';

/// One image slot in the schedule carousel (editable + reorderable).
class SchedulePostMediaSlot {
  SchedulePostMediaSlot({
    required this.id,
    required this.file,
    this.rotationQuarter = 0,
    this.filterIndex = 0,
    this.filterIntensity = 1.0,
    this.brightness = 0.0,
    this.contrast = 1.0,
    this.saturation = 1.0,
    this.warmth = 0.0,
  });

  final String id;
  File file;
  int rotationQuarter;
  int filterIndex;
  /// 0.0 … 1.0 — how strongly the selected filter is applied.
  double filterIntensity;
  /// -1.0 … 1.0 (UI); mapped on export.
  double brightness;
  /// ~0.5 … 1.5 (UI); 1.0 = neutral.
  double contrast;
  /// 0.0 … 2.0; 1.0 = neutral.
  double saturation;
  /// -1.0 … 1.0; 0.0 = neutral (+ warmer, - cooler).
  double warmth;

  /// Multiplicative brightness factor used by the matrix pipeline.
  double get brightnessFactor => (1.0 + brightness * 0.35).clamp(0.2, 2.0);

  SchedulePostMediaSlot copyWith({
    File? file,
    int? rotationQuarter,
    int? filterIndex,
    double? filterIntensity,
    double? brightness,
    double? contrast,
    double? saturation,
    double? warmth,
  }) {
    return SchedulePostMediaSlot(
      id: id,
      file: file ?? this.file,
      rotationQuarter: rotationQuarter ?? this.rotationQuarter,
      filterIndex: filterIndex ?? this.filterIndex,
      filterIntensity: filterIntensity ?? this.filterIntensity,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      warmth: warmth ?? this.warmth,
    );
  }
}

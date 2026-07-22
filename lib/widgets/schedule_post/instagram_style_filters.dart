import 'package:flutter/material.dart';

/// Display-only color matrices (paired with export in [schedule_post_image_export.dart]).
class InstagramStyleFilters {
  static const names = ['Normal', 'Vivid', 'B&W', 'Sepia', 'Soft'];

  static List<List<double>> get matrices => [
        // identity
        [
          1, 0, 0, 0, 0,
          0, 1, 0, 0, 0,
          0, 0, 1, 0, 0,
          0, 0, 0, 1, 0,
        ],
        // vivid
        [
          1.15, 0.05, 0.05, 0, 0,
          0.05, 1.12, 0.05, 0, 0,
          0.05, 0.05, 1.1, 0, 0,
          0, 0, 0, 1, 0,
        ],
        // grayscale
        [
          0.33, 0.59, 0.11, 0, 0,
          0.33, 0.59, 0.11, 0, 0,
          0.33, 0.59, 0.11, 0, 0,
          0, 0, 0, 1, 0,
        ],
        // sepia-ish
        [
          0.45, 0.35, 0.15, 0, 0,
          0.35, 0.45, 0.15, 0, 0,
          0.25, 0.25, 0.35, 0, 0,
          0, 0, 0, 1, 0,
        ],
        // soft / cool
        [
          0.95, 0.05, 0.08, 0, 8,
          0.05, 0.98, 0.05, 0, 6,
          0.08, 0.05, 1.02, 0, 4,
          0, 0, 0, 1, 0,
        ],
      ];

  static Widget wrap(int index, Widget child) {
    final i = index.clamp(0, matrices.length - 1);
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(matrices[i]),
      child: child,
    );
  }
}

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// Instagram-style photo filters + adjustments as **4x5 colour matrices**.
///
/// A single matrix is the source of truth for BOTH the live preview
/// (`ColorFilter.matrix`) and the exported JPEG (`applyMatrixToImage`), so what
/// the user sees is exactly what gets posted. Each filter is defined as a small
/// set of parameters (saturation / contrast / brightness / warmth / tint) and
/// compiled into a matrix, which keeps the looks readable and drift-free.
class PhotoFilter {
  const PhotoFilter(
    this.name, {
    this.saturation = 1.0,
    this.contrast = 1.0,
    this.brightness = 1.0,
    this.warmth = 0.0,
    this.tintR = 0.0,
    this.tintG = 0.0,
    this.tintB = 0.0,
  });

  final String name;
  final double saturation; // 1.0 = neutral
  final double contrast; // 1.0 = neutral
  final double brightness; // 1.0 = neutral (multiplicative)
  final double warmth; // -1..1 (+ warmer)
  final double tintR; // additive 0..255 space
  final double tintG;
  final double tintB;

  /// The filter's own look as a 4x5 matrix (no user adjustments).
  List<double> build() {
    var m = _identity();
    m = _mul(_warmthM(warmth), m);
    m = _mul(_saturationM(saturation), m);
    m = _mul(_contrastM(contrast), m);
    m = _mul(_brightnessM(brightness), m);
    m = _mul(_tintM(tintR, tintG, tintB), m);
    return m;
  }
}

/// Curated filter presets (index 0 must stay "Normal").
const List<PhotoFilter> kPhotoFilters = [
  PhotoFilter('Normal'),
  PhotoFilter('Clarendon', saturation: 1.25, contrast: 1.12, warmth: -0.15, tintB: 6),
  PhotoFilter('Juno', saturation: 1.3, contrast: 1.06, warmth: 0.2, tintR: 6),
  PhotoFilter('Lark', saturation: 1.12, brightness: 1.06, warmth: -0.1, tintB: 4),
  PhotoFilter('Gingham', saturation: 0.85, contrast: 0.92, brightness: 1.05, warmth: 0.08),
  PhotoFilter('Reyes', saturation: 0.75, contrast: 0.9, brightness: 1.1, warmth: 0.18, tintR: 8, tintG: 4),
  PhotoFilter('Moon', saturation: 0.0, contrast: 1.1, brightness: 1.02),
  PhotoFilter('Willow', saturation: 0.2, contrast: 1.05, brightness: 1.04, tintB: 6),
  PhotoFilter('Crema', saturation: 0.9, contrast: 1.02, warmth: 0.1, tintR: 5, tintG: 3),
  PhotoFilter('Ludwig', saturation: 1.15, contrast: 1.08, brightness: 1.02, warmth: -0.05),
  PhotoFilter('Aden', saturation: 0.85, contrast: 0.95, brightness: 1.06, warmth: 0.12, tintR: 8, tintB: 6),
  PhotoFilter('Slumber', saturation: 0.8, contrast: 0.95, brightness: 1.04, warmth: 0.15, tintR: 6),
  PhotoFilter('Vivid', saturation: 1.4, contrast: 1.12, warmth: 0.05),
  PhotoFilter('Sepia', saturation: 0.35, contrast: 1.02, warmth: 0.35, tintR: 20, tintG: 10),
];

/// Number of filters (for bounds checks).
int get kPhotoFilterCount => kPhotoFilters.length;

/// Build the FINAL matrix: the chosen filter (scaled by [intensity] toward the
/// identity) with the user's manual adjustments applied on top. Used verbatim
/// by both the preview and the exporter.
List<double> buildFinalMatrix({
  required int filterIndex,
  double intensity = 1.0,
  double brightness = 1.0, // multiplicative, 1.0 neutral
  double contrast = 1.0,
  double saturation = 1.0,
  double warmth = 0.0,
}) {
  final f = kPhotoFilters[filterIndex.clamp(0, kPhotoFilters.length - 1)];
  final filterM = _lerp(_identity(), f.build(), intensity.clamp(0.0, 1.0));
  var adj = _identity();
  adj = _mul(_warmthM(warmth), adj);
  adj = _mul(_saturationM(saturation), adj);
  adj = _mul(_contrastM(contrast), adj);
  adj = _mul(_brightnessM(brightness), adj);
  return _mul(adj, filterM);
}

/// Wrap [child] with the given colour matrix for live preview.
Widget applyMatrixWidget(List<double> matrix, Widget child) {
  return ColorFiltered(colorFilter: ColorFilter.matrix(matrix), child: child);
}

/// Apply a 4x5 colour matrix to every pixel of [src] (for export). The matrix
/// constant column is in 0..255 space, matching Flutter's ColorFilter.matrix.
img.Image applyMatrixToImage(img.Image src, List<double> m) {
  final out = img.Image.from(src);
  for (final px in out) {
    final r = px.r.toDouble();
    final g = px.g.toDouble();
    final b = px.b.toDouble();
    final a = px.a.toDouble();
    final nr = m[0] * r + m[1] * g + m[2] * b + m[3] * a + m[4];
    final ng = m[5] * r + m[6] * g + m[7] * b + m[8] * a + m[9];
    final nb = m[10] * r + m[11] * g + m[12] * b + m[13] * a + m[14];
    final na = m[15] * r + m[16] * g + m[17] * b + m[18] * a + m[19];
    px.r = nr.clamp(0, 255);
    px.g = ng.clamp(0, 255);
    px.b = nb.clamp(0, 255);
    px.a = na.clamp(0, 255);
  }
  return out;
}

/// Bytes of a filtered thumbnail (used for the live filter strip). Decodes a
/// small copy once and applies the filter matrix — cheap enough for a strip.
Uint8List? filteredThumbnailBytes(img.Image smallSrc, int filterIndex) {
  final m = buildFinalMatrix(filterIndex: filterIndex);
  final t = applyMatrixToImage(smallSrc, m);
  return Uint8List.fromList(img.encodeJpg(t, quality: 80));
}

// ── matrix primitives (4x5 row-major, implicit 5th row [0,0,0,0,1]) ──────────

List<double> _identity() => [
      1, 0, 0, 0, 0,
      0, 1, 0, 0, 0,
      0, 0, 1, 0, 0,
      0, 0, 0, 1, 0,
    ];

/// Compose: result applies [b] first, then [a].
List<double> _mul(List<double> a, List<double> b) {
  final out = List<double>.filled(20, 0);
  for (var row = 0; row < 4; row++) {
    for (var col = 0; col < 4; col++) {
      var sum = 0.0;
      for (var k = 0; k < 4; k++) {
        sum += a[row * 5 + k] * b[k * 5 + col];
      }
      out[row * 5 + col] = sum;
    }
    // translation column
    var t = a[row * 5 + 4];
    for (var k = 0; k < 4; k++) {
      t += a[row * 5 + k] * b[k * 5 + 4];
    }
    out[row * 5 + 4] = t;
  }
  return out;
}

List<double> _lerp(List<double> a, List<double> b, double t) {
  final out = List<double>.filled(20, 0);
  for (var i = 0; i < 20; i++) {
    out[i] = a[i] + (b[i] - a[i]) * t;
  }
  return out;
}

List<double> _brightnessM(double f) => [
      f, 0, 0, 0, 0,
      0, f, 0, 0, 0,
      0, 0, f, 0, 0,
      0, 0, 0, 1, 0,
    ];

List<double> _contrastM(double c) {
  final t = 128 * (1 - c);
  return [
    c, 0, 0, 0, t,
    0, c, 0, 0, t,
    0, 0, c, 0, t,
    0, 0, 0, 1, 0,
  ];
}

List<double> _saturationM(double s) {
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  final sr = (1 - s) * lr, sg = (1 - s) * lg, sb = (1 - s) * lb;
  return [
    sr + s, sg, sb, 0, 0,
    sr, sg + s, sb, 0, 0,
    sr, sg, sb + s, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

/// Warmth: push red up and blue down (or reverse for cool). [w] in -1..1.
List<double> _warmthM(double w) {
  final shift = w * 28.0;
  return [
    1, 0, 0, 0, shift,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, -shift,
    0, 0, 0, 1, 0,
  ];
}

List<double> _tintM(double r, double g, double b) => [
      1, 0, 0, 0, r,
      0, 1, 0, 0, g,
      0, 0, 1, 0, b,
      0, 0, 0, 1, 0,
    ];

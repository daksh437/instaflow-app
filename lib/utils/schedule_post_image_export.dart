import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/schedule_post_media_slot.dart';
import '../widgets/schedule_post/photo_filters.dart';

/// Applies rotation + the same colour matrix used by the live preview (filter,
/// intensity, brightness, contrast, saturation, warmth) and writes a JPEG.
Future<File> exportEditedImage(SchedulePostMediaSlot slot) async {
  final raw = await slot.file.readAsBytes();
  final decoded = img.decodeImage(raw);
  if (decoded == null) {
    throw Exception('Could not decode image');
  }
  var image = decoded;

  final q = slot.rotationQuarter % 4;
  if (q == 1) {
    image = img.copyRotate(image, angle: 90);
  } else if (q == 2) {
    image = img.copyRotate(image, angle: 180);
  } else if (q == 3) {
    image = img.copyRotate(image, angle: 270);
  }

  // Single source of truth: identical matrix to the on-screen preview.
  final matrix = buildFinalMatrix(
    filterIndex: slot.filterIndex,
    intensity: slot.filterIntensity,
    brightness: slot.brightnessFactor,
    contrast: slot.contrast.clamp(0.25, 2.0),
    saturation: slot.saturation,
    warmth: slot.warmth,
  );
  image = applyMatrixToImage(image, matrix);

  final outBytes = Uint8List.fromList(img.encodeJpg(image, quality: 92));
  final dir = await getTemporaryDirectory();
  final out = File(p.join(dir.path, 'schedule_export_${DateTime.now().millisecondsSinceEpoch}.jpg'));
  await out.writeAsBytes(outBytes, flush: true);
  return out;
}

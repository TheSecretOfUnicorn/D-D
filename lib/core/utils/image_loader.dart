import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

class ImageLoader {
  /// Charge une image depuis les assets et retourne un objet ui.Image
  /// utilisable par un CustomPainter.
  static Future<ui.Image> loadAsset(String path) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}
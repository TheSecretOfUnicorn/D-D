import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class BackgroundPatternPainter extends CustomPainter {
  final ui.Image? patternImage;
  final Color backgroundColor;

  BackgroundPatternPainter({
    this.patternImage,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. D'abord on remplit avec la couleur de fond (beige)
    // Cela évite d'avoir du noir si l'image met du temps à charger
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(rect, bgPaint);

    // 2. Ensuite, on dessine le motif répété (Tiling)
    if (patternImage != null) {
      final paint = Paint();
      
      // La magie est ici : TileMode.repeated
      paint.shader = ImageShader(
        patternImage!,
        TileMode.repeated, // Répéter horizontalement
        TileMode.repeated, // Répéter verticalement
        Matrix4.identity().storage,
      );
      
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant BackgroundPatternPainter oldDelegate) {
    return patternImage != oldDelegate.patternImage || 
           backgroundColor != oldDelegate.backgroundColor;
  }
}
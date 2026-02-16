import 'package:flutter/material.dart';
import '../../data/models/world_object_model.dart';
import '/core/utils/hex_utils.dart';

class LightingPainter extends CustomPainter {
  final Map<String, WorldObject> objects;
  final double radius; // Rayon d'un hexagone (pour l'échelle)
  final Offset offset;

  LightingPainter({
    required this.objects,
    required this.radius,
    required this.offset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);

    for (var obj in objects.values) {
      if (obj.lightRadius <= 0) continue;

      final center = HexUtils.gridToPixel(obj.position.x, obj.position.y, radius);
      
      // Rayon visuel en pixels (approximatif pour l'effet de glow)
      final pixelRadius = obj.lightRadius * (radius * 1.5);

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            Color(obj.lightColor).withValues(alpha: .6), // Centre brillant
            Color(obj.lightColor).withValues(alpha: 0.0), // Bord transparent
          ],
          stops: const [0.2, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: pixelRadius))
        ..blendMode = BlendMode.screen; // Mode de fusion pour effet lumineux

      canvas.drawCircle(center, pixelRadius, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LightingPainter oldDelegate) => true;
}
import 'package:flutter/material.dart';
import '../../data/models/map_config_model.dart';
import '/core/utils/hex_utils.dart';

class MovementPainter extends CustomPainter {
  final MapConfig config;
  final Set<String> reachableCells; // Les cases où on peut aller
  final double radius;
  final Offset offset;

  MovementPainter({
    required this.config,
    required this.reachableCells,
    required this.radius,
    required this.offset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (reachableCells.isEmpty) return;

    final paint = Paint()
      ..color = Colors.green.withValues(green: 0.3) // Vert transparent
      ..style = PaintingStyle.fill;
      
    final borderPaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final hexPath = HexUtils.getHexPath(radius);

    canvas.save();
    canvas.translate(offset.dx, offset.dy);

    for (String key in reachableCells) {
      final parts = key.split(',');
      final c = int.parse(parts[0]);
      final r = int.parse(parts[1]);
      
      final center = HexUtils.gridToPixel(c, r, radius);
      
      canvas.save();
      canvas.translate(center.dx, center.dy);
      // On réduit un peu la zone verte pour l'esthétique (marge interne)
      canvas.scale(0.9); 
      canvas.drawPath(hexPath, paint);
      canvas.drawPath(hexPath, borderPaint);
      canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MovementPainter oldDelegate) {
    return reachableCells != oldDelegate.reachableCells;
  }
}
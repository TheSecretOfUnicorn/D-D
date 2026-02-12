import 'package:flutter/material.dart';
import '../../data/models/map_config_model.dart';
import '/core/utils/hex_utils.dart';

class GridPainter extends CustomPainter {
  final MapConfig config;
  final double radius;
  final Offset offset; // AJOUT

  GridPainter({
    required this.config, 
    required this.radius,
    required this.offset, // Requis
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = config.gridColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final hexPath = HexUtils.getHexPath(radius);

    // 1. APPLIQUER LA MARGE GLOBALE
    canvas.save();
    canvas.translate(offset.dx, offset.dy);

    for (int r = 0; r < config.heightInCells; r++) {
      for (int c = 0; c < config.widthInCells; c++) {
        final center = HexUtils.gridToPixel(c, r, radius);
        
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.drawPath(hexPath, paint);
        canvas.restore();
      }
    }

    // On restaure le translate global
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    return config != oldDelegate.config || radius != oldDelegate.radius || offset != oldDelegate.offset;
  }
}
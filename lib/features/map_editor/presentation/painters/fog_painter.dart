import 'package:flutter/material.dart';
import '../../data/models/map_config_model.dart';
import '/core/utils/hex_utils.dart';

class FogPainter extends CustomPainter {
  final MapConfig config;
  final Set<String> visibleCells;
  final Set<String> exploredCells;
  final double radius;
  final Offset offset;

  FogPainter({
    required this.config,
    required this.visibleCells,
    required this.exploredCells,
    required this.radius,
    required this.offset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintHidden = Paint()..color = Colors.black;
    final paintExplored = Paint()..color = Colors.black.withValues(alpha: 0.5);
    final hexPath = HexUtils.getHexPath(radius);

    canvas.save();
    canvas.translate(offset.dx, offset.dy);

    for (int r = 0; r < config.heightInCells; r++) {
      for (int c = 0; c < config.widthInCells; c++) {
        final key = "$c,$r";
        if (visibleCells.contains(key)) continue; // Visible = Transparent

        final center = HexUtils.gridToPixel(c, r, radius);
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.scale(1.02); // Légère superposition pour éviter les trous

        if (exploredCells.contains(key)) {
          canvas.drawPath(hexPath, paintExplored);
        } else {
          canvas.drawPath(hexPath, paintHidden);
        }
        canvas.restore();
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FogPainter oldDelegate) => true;
}
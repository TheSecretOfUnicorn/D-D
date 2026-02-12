import 'package:flutter/material.dart';
import '../../data/models/map_config_model.dart';
import '/core/utils/hex_utils.dart';

class FogPainter extends CustomPainter {
  final MapConfig config;
  final Set<String> visibleCells;    // Ce qu'on voit MAINTENANT
  final Set<String> exploredCells;   // Ce qu'on a DÉJÀ vu (optionnel, pour faire du gris)
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
    final paintHidden = Paint()..color = Colors.black; // Noir total
    final paintExplored = Paint()..color = Colors.black.withValues(alpha:0.5); // Gris (Brouillard de guerre)
    
    final hexPath = HexUtils.getHexPath(radius);

    canvas.save();
    canvas.translate(offset.dx, offset.dy);

    // On parcourt TOUTE la grille
    for (int r = 0; r < config.heightInCells; r++) {
      for (int c = 0; c < config.widthInCells; c++) {
        final key = "$c,$r";
        
        // Si la case est visible actuellement, on ne dessine RIEN (c'est transparent)
        if (visibleCells.contains(key)) continue;

        final center = HexUtils.gridToPixel(c, r, radius);
        canvas.save();
        canvas.translate(center.dx, center.dy);
        
        // On agrandit un tout petit peu le masque noir pour éviter les fuites de lumière entre les hexagones
        canvas.scale(1.02); 

        if (exploredCells.contains(key)) {
          // Zone déjà vue mais pas active : Gris
          canvas.drawPath(hexPath, paintExplored);
        } else {
          // Zone jamais vue : Noir total
          canvas.drawPath(hexPath, paintHidden);
        }
        
        canvas.restore();
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FogPainter oldDelegate) {
    return visibleCells != oldDelegate.visibleCells || exploredCells != oldDelegate.exploredCells;
  }
}
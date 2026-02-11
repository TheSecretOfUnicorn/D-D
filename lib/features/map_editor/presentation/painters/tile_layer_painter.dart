import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../domain/models/map_config_model.dart';
import '../../../../core/utils/hex_utils.dart';

class TileLayerPainter extends CustomPainter {
  final MapConfig config;
  final ui.Image? tileImage;
  final Set<String> paintedCells;
  final double radius;

  TileLayerPainter({
    required this.config,
    this.tileImage,
    required this.paintedCells,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (tileImage == null) return;

    final paint = Paint();
    final hexPath = HexUtils.getHexPath(radius);
    final srcRect = Rect.fromLTWH(0, 0, tileImage!.width.toDouble(), tileImage!.height.toDouble());

    // --- CORRECTION CRITIQUE (Z-INDEX) ---
    // On convertit le Set en Liste pour pouvoir le TRIER.
    // On veut dessiner la ligne 0, puis la ligne 1, etc.
    // Ainsi, la case du DESSOUS recouvre proprement la pointe de la case du DESSUS.
    final sortedKeys = paintedCells.toList()
      ..sort((a, b) {
        final pa = a.split(',');
        final pb = b.split(',');
        final rowA = int.parse(pa[1]);
        final rowB = int.parse(pb[1]);
        
        // Tri vertical prioritaire (Y croissant)
        if (rowA != rowB) return rowA.compareTo(rowB);
        // Puis tri horizontal (X croissant)
        return int.parse(pa[0]).compareTo(int.parse(pb[0]));
      });

    for (String key in sortedKeys) {
      final parts = key.split(',');
      final center = HexUtils.gridToPixel(int.parse(parts[0]), int.parse(parts[1]), radius);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.clipPath(hexPath);
      
      // On dessine l'image très légèrement plus grande (x2.02) pour éviter les micro-fissures
      final dstRect = Rect.fromCenter(
        center: Offset.zero, 
        width: radius * 2.02, 
        height: radius * 2.02
      );
      
      canvas.drawImageRect(tileImage!, srcRect, dstRect, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant TileLayerPainter oldDelegate) {
    // --- CORRECTION RAFRAÎCHISSEMENT ---
    // On retourne 'true' temporairement pour forcer Flutter à redessiner à chaque frame
    // si jamais le Set n'est pas détecté comme modifié.
    return true; 
  }
}
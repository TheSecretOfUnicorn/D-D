import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../domain/models/map_config_model.dart';
import '../../../../core/utils/hex_utils.dart';

class TileLayerPainter extends CustomPainter {
  final MapConfig config;
  final ui.Image? tileImage;
  final Set<String> paintedCells;
  final double radius; // <--- C'EST CE CHAMP QUI MANQUE CHEZ TOI

  TileLayerPainter({
    required this.config,
    this.tileImage,
    required this.paintedCells,
    required this.radius, // <--- ET CE CONSTRUCTEUR
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (tileImage == null) return;

    final paint = Paint();
    // Utilisation du rayon reçu
    final hexPath = HexUtils.getHexPath(radius);
    
    final srcRect = Rect.fromLTWH(0, 0, tileImage!.width.toDouble(), tileImage!.height.toDouble());

    for (String key in paintedCells) {
      final parts = key.split(',');
      final int col = int.parse(parts[0]);
      final int row = int.parse(parts[1]);

      // Positionnement précis
      final center = HexUtils.gridToPixel(col, row, radius);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      
      // Découpe hexagonale
      canvas.clipPath(hexPath);

      // Dessin centré
      final dstRect = Rect.fromCenter(
        center: Offset.zero, 
        width: radius * 2, 
        height: radius * 2
      );
      canvas.drawImageRect(tileImage!, srcRect, dstRect, paint);
      
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant TileLayerPainter oldDelegate) {
    return config != oldDelegate.config || 
           tileImage != oldDelegate.tileImage ||
           paintedCells != oldDelegate.paintedCells ||
           radius != oldDelegate.radius;
  }
}
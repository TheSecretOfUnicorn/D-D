// Fichier : lib/features/map_editor/presentation/painters/tile_layer_painter.dart
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../domain/models/map_config_model.dart';
import '../../../../core/utils/hex_utils.dart';

class TileLayerPainter extends CustomPainter {
  final MapConfig config;
  final ui.Image? tileImage;
  final Set<String> paintedCells;
  final double radius;

  TileLayerPainter({required this.config, this.tileImage, required this.paintedCells, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    // Si pas d'image, on ne fait rien (ou on dessine un debug rouge)
    if (tileImage == null) return;

    final paint = Paint();
    final hexPath = HexUtils.getHexPath(radius);
    final srcRect = Rect.fromLTWH(0, 0, tileImage!.width.toDouble(), tileImage!.height.toDouble());

    // 1. TRI OBLIGATOIRE (Z-Index)
    // On trie les cases : Ligne 0 d'abord, puis Ligne 1, etc.
    // Cela garantit que la ligne du bas recouvre la ligne du haut (pas de triangles bizarres)
    final sortedKeys = paintedCells.toList()
      ..sort((a, b) {
        final pa = a.split(',');
        final pb = b.split(',');
        final rowA = int.parse(pa[1]);
        final rowB = int.parse(pb[1]);
        if (rowA != rowB) return rowA.compareTo(rowB);
        return int.parse(pa[0]).compareTo(int.parse(pb[0]));
      });

    // 2. DESSIN
    for (String key in sortedKeys) {
      final parts = key.split(',');
      final center = HexUtils.gridToPixel(int.parse(parts[0]), int.parse(parts[1]), radius);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.clipPath(hexPath);
      
      // On dessine un tout petit peu plus grand (x2.02) pour éviter les traits blancs entre les tuiles
      final dstRect = Rect.fromCenter(center: Offset.zero, width: radius * 2.02, height: radius * 2.02);
      canvas.drawImageRect(tileImage!, srcRect, dstRect, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant TileLayerPainter oldDelegate) {
    // Force le redessin si la liste change (via notre fix setState)
    return paintedCells != oldDelegate.paintedCells || 
           tileImage != oldDelegate.tileImage;
  }
}
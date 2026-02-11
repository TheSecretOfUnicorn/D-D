import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../domain/models/map_config_model.dart';
import '/core/utils/hex_utils.dart';

class TileLayerPainter extends CustomPainter {
  final MapConfig config;
  final ui.Image? tileImage;
  final Set<String> paintedCells;
  final double radius;
  final Offset offset; // AJOUT : Décalage global

  TileLayerPainter({
    required this.config,
    this.tileImage,
    required this.paintedCells,
    required this.radius,
    required this.offset, // Requis
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final hexPath = HexUtils.getHexPath(radius);

    // 1. APPLIQUER LA MARGE GLOBALE
    // On déplace tout le repère de dessin vers le bas-droite
    canvas.save();
    canvas.translate(offset.dx, offset.dy);

    // 2. TRI (Z-INDEX)
    final sortedKeys = paintedCells.toList()
      ..sort((a, b) {
        final pa = a.split(',');
        final pb = b.split(',');
        final rowA = int.parse(pa[1]);
        final rowB = int.parse(pb[1]);
        if (rowA != rowB) return rowA.compareTo(rowB);
        return int.parse(pa[0]).compareTo(int.parse(pb[0]));
      });

    // 3. DESSIN
    for (String key in sortedKeys) {
      final parts = key.split(',');
      final center = HexUtils.gridToPixel(int.parse(parts[0]), int.parse(parts[1]), radius);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.clipPath(hexPath);
      
      if (tileImage != null) {
        final srcRect = Rect.fromLTWH(0, 0, tileImage!.width.toDouble(), tileImage!.height.toDouble());
        final dstRect = Rect.fromCenter(center: Offset.zero, width: radius * 2.02, height: radius * 2.02);
        canvas.drawImageRect(tileImage!, srcRect, dstRect, paint);
      } else {
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: radius * 2, height: radius * 2), Paint()..color = Colors.grey);
      }
      canvas.restore();
    }

    // On restaure le translate global
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TileLayerPainter oldDelegate) => true;
}
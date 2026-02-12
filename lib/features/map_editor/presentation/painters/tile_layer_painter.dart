import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../data/models/map_config_model.dart';
import '/core/utils/hex_utils.dart';
// On importe le fichier de la page pour récupérer l'enum TileType
import '../../data/models/tile_type.dart'; // Assure-toi que ce fichier existe (Etape précédente)
class TileLayerPainter extends CustomPainter {
  final MapConfig config;
  final ui.Image? floorImage;
  final ui.Image? wallImage;
  final Map<String, TileType> gridData; // Accepte la Map
  final double radius;
  final Offset offset;

  TileLayerPainter({
    required this.config,
    this.floorImage,
    this.wallImage,
    required this.gridData,
    required this.radius,
    required this.offset,
    

  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final hexPath = HexUtils.getHexPath(radius);

    canvas.save();
    canvas.translate(offset.dx, offset.dy);

    // Tri Z-Index pour l'affichage correct
    final sortedKeys = gridData.keys.toList()
      ..sort((a, b) {
        final pa = a.split(',');
        final pb = b.split(',');
        final rowA = int.parse(pa[1]);
        final rowB = int.parse(pb[1]);
        if (rowA != rowB) return rowA.compareTo(rowB);
        return int.parse(pa[0]).compareTo(int.parse(pb[0]));
      });

    for (String key in sortedKeys) {
      final type = gridData[key];
      final parts = key.split(',');
      final center = HexUtils.gridToPixel(int.parse(parts[0]), int.parse(parts[1]), radius);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.clipPath(hexPath);
      
      ui.Image? imgToDraw;
      Color fallbackColor = Colors.grey;

      if (type == TileType.floor) {
        imgToDraw = floorImage;
        fallbackColor = Colors.grey;
      } else if (type == TileType.wall) {
        imgToDraw = wallImage;
        fallbackColor = Colors.brown; // Couleur marron si mur absent
      }

      if (imgToDraw != null) {
        final srcRect = Rect.fromLTWH(0, 0, imgToDraw.width.toDouble(), imgToDraw.height.toDouble());
        final dstRect = Rect.fromCenter(center: Offset.zero, width: radius * 2.02, height: radius * 2.02);
        canvas.drawImageRect(imgToDraw, srcRect, dstRect, paint);
      } else {
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: radius * 2, height: radius * 2), Paint()..color = fallbackColor);
      }
      
      canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TileLayerPainter oldDelegate) => true;
}
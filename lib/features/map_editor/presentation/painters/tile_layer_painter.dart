import 'dart:math';

import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../data/models/map_config_model.dart';
import '/core/utils/hex_utils.dart';
import '../../data/models/tile_type.dart';

class TileLayerPainter extends CustomPainter {
  final MapConfig config;
  final Map<String, ui.Image> assets; // Nouvelle gestion d'assets
  final Map<String, TileType> gridData;
  final double radius;
  final Offset offset;
  final Map<String, int> tileRotations;
  final double animationValue;

  TileLayerPainter({
    required this.config,
    required this.assets,
    required this.gridData,
    required this.tileRotations,
    required this.radius,
    required this.offset,
    required this.animationValue, // Nouvelle variable pour l'animation

  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final hexPath = HexUtils.getHexPath(radius);

    canvas.save();
    canvas.translate(offset.dx, offset.dy);

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
      final rotationIndex = tileRotations[key] ?? 0;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.clipPath(hexPath);
      
      if (rotationIndex > 0) {
        canvas.rotate(rotationIndex * (pi / 3));
      }

      canvas.clipPath(hexPath);


      // MAPPING TYPE -> ASSET
      ui.Image? img;
      Color fallbackColor = Colors.grey;

      switch (type) {
        case TileType.stoneFloor: img = assets['stone_floor']; fallbackColor = Colors.grey; break;
        case TileType.woodFloor: img = assets['wood_floor']; fallbackColor = Colors.brown.shade400; break;
        case TileType.grass: img = assets['grass']; fallbackColor = Colors.green.shade800; break;
        case TileType.dirt: img = assets['dirt']; fallbackColor = Colors.brown; break;
        case TileType.water: img = assets['water']; fallbackColor = Colors.blue; break;
        case TileType.lava: img = assets['lava']; fallbackColor = Colors.orange; break;
        case TileType.stoneWall: img = assets['stone_wall']; fallbackColor = Colors.grey.shade800; break;
        case TileType.tree: img = assets['tree']; fallbackColor = Colors.green.shade900; break;
        default: break;
      }

      if (img != null) {
        final srcRect = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
        final dstRect = Rect.fromCenter(center: Offset.zero, width: radius * 2.02, height: radius * 2.02);
        canvas.drawImageRect(img, srcRect, dstRect, paint);
        // EFFET EAU : Scintillement Bleu/Blanc
        if (type == TileType.water) {
          final opacity = 0.1 + (animationValue * 0.15); // Varie entre 0.1 et 0.25
          canvas.drawRect(
            dstRect, 
            Paint()..color = Colors.white.withValues(alpha: 0.1)..blendMode = BlendMode.overlay
          );
        }
        
        // EFFET LAVE : Pulsation Rouge/Jaune (Chaleur)
        if (type == TileType.lava) {
          final opacity = 0.2 + (animationValue * 0.3); // Varie entre 0.2 et 0.5
          // On dessine un carré rouge/orange par dessus avec un mode de fusion
          canvas.drawRect(
            dstRect, 
            Paint()..color = Colors.redAccent.withValues(alpha: 0.1)..blendMode = BlendMode.hardLight
          );
        }
      } else {
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: radius * 2, height: radius * 2), Paint()..color = fallbackColor);
      }
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TileLayerPainter oldDelegate) => 
      oldDelegate.animationValue != animationValue || 
      oldDelegate.gridData != gridData;
}
import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../data/models/map_config_model.dart';
import '/core/utils/hex_utils.dart'; 
import '../../data/models/tile_type.dart';

class TileLayerPainter extends CustomPainter {
  final MapConfig config;
  final Map<String, ui.Image> assets;
  final Map<String, TileType> gridData;
  final Map<String, int> tileRotations;
  final double radius;
  final Offset offset;
  
  // La valeur d'animation (entre 0.0 et 1.0)
  final double animationValue; 

  TileLayerPainter({
    required this.config,
    required this.assets,
    required this.gridData,
    required this.tileRotations,
    required this.radius,
    required this.offset,
    required this.animationValue, 
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final hexPath = HexUtils.getHexPath(radius);

    canvas.save();
    canvas.translate(offset.dx, offset.dy);

    // Tri pour l'affichage (Z-Index)
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

      // Rotation
      if (rotationIndex > 0) {
        canvas.rotate(rotationIndex * (pi / 3));
      }

      // Découpe
      canvas.clipPath(hexPath);
      
      ui.Image? imgToDraw;
      Color fallbackColor = Colors.grey;

      // Choix de l'image
      switch (type) {
        case TileType.stoneFloor: imgToDraw = assets['stone_floor']; fallbackColor = Colors.grey; break;
        case TileType.woodFloor: imgToDraw = assets['wood_floor']; fallbackColor = Colors.brown.shade400; break;
        case TileType.grass: imgToDraw = assets['grass']; fallbackColor = Colors.green.shade800; break;
        case TileType.dirt: imgToDraw = assets['dirt']; fallbackColor = Colors.brown; break;
        case TileType.stoneWall: imgToDraw = assets['stone_wall']; fallbackColor = Colors.grey.shade800; break;
        case TileType.tree: imgToDraw = assets['tree']; fallbackColor = Colors.green.shade900; break;
        case TileType.water: imgToDraw = assets['water']; fallbackColor = Colors.blue; break;
        case TileType.lava: imgToDraw = assets['lava']; fallbackColor = Colors.orange; break;
        default: break;
      }

      // 1. DESSIN DE LA TUILE DE BASE
      if (imgToDraw != null) {
        final srcRect = Rect.fromLTWH(0, 0, imgToDraw.width.toDouble(), imgToDraw.height.toDouble());
        final dstRect = Rect.fromCenter(center: Offset.zero, width: radius * 2.02, height: radius * 2.02);
        canvas.drawImageRect(imgToDraw, srcRect, dstRect, paint);
      } else {
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: radius * 2, height: radius * 2), Paint()..color = fallbackColor);
      }

      // 2. EFFETS D'ANIMATION AMÉLIORÉS 🌊🔥
      if (type == TileType.water) {
        // --- EFFET VAGUE (Reflet qui traverse) ---
        // On calcule une position qui bouge de gauche à droite
        // Le reflet va de -radius (gauche) à +radius (droite)
        final double wavePos = (animationValue * 2.5 * radius) - (radius * 1.25);

        final Paint wavePaint = Paint()
          ..shader = ui.Gradient.linear(
            Offset(wavePos, 0),          // Début du dégradé (mouvant)
            Offset(wavePos + radius, 0), // Fin du dégradé (mouvant)
            [
              Colors.white.withValues(alpha: 0.0), // Transparent
              Colors.white.withValues(alpha: 0.6), // Blanc bien visible (Crête de la vague)
              Colors.white.withValues(alpha: 0.0), // Transparent
            ],
            [0.0, 0.5, 1.0], // La bande blanche est au milieu du dégradé
            TileMode.clamp,
          )
          ..blendMode = BlendMode.overlay; // Incrustation pour garder le bleu dessous

        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: radius * 2, height: radius * 2),
          wavePaint
        );
      } 
      else if (type == TileType.lava) {
        // --- EFFET CHALEUR INTENSE ---
        final opacity = 0.2 + (animationValue * 0.3); // Varie de 0.2 à 0.5
        
        // Couche Rouge (Pulsation)
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: radius * 2, height: radius * 2),
          Paint()
            ..color = Colors.redAccent.withValues(alpha: opacity)
            ..blendMode = BlendMode.hardLight
        );
      }

      canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TileLayerPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || 
           oldDelegate.gridData != gridData ||
           oldDelegate.tileRotations != tileRotations;
  }
}
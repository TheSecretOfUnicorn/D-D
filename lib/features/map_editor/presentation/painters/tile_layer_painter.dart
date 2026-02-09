import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../domain/models/map_config_model.dart';

class TileLayerPainter extends CustomPainter {
  final MapConfig config;
  final ui.Image? tileImage; // L'image texture chargée

  TileLayerPainter({
    required this.config,
    this.tileImage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Si l'image n'est pas encore chargée, on ne dessine rien (ou un fond uni)
    if (tileImage == null) return;

    final paint = Paint();
    final double cellSize = config.cellSize;

    // Rectangle source (toute l'image texture)
    final srcRect = Rect.fromLTWH(
      0, 0, 
      tileImage!.width.toDouble(), 
      tileImage!.height.toDouble()
    );

    // Boucle optimisée : On dessine la tuile sur chaque case de la grille
    // Note: Plus tard, on lira une matrice pour savoir QUELLE image mettre où.
    // Pour l'instant, c'est du remplissage uniforme ("Fill").
    for (int col = 0; col < config.widthInCells; col++) {
      for (int row = 0; row < config.heightInCells; row++) {
        
        // Calcul de la position de la case
        final dstRect = Rect.fromLTWH(
          col * cellSize, 
          row * cellSize, 
          cellSize, 
          cellSize
        );

        // Dessin de l'image redimensionnée dans la case
        canvas.drawImageRect(tileImage!, srcRect, dstRect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant TileLayerPainter oldDelegate) {
    // On repeint si la config change OU si l'image vient d'être chargée
    return config != oldDelegate.config || tileImage != oldDelegate.tileImage;
  }
}
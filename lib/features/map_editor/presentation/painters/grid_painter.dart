import 'package:flutter/material.dart';
import '../../domain/models/map_config_model.dart';

class GridPainter extends CustomPainter {
  final MapConfig config;
  final double scale; // Pourra servir plus tard si on veut épaissir les lignes au zoom

  GridPainter({required this.config, this.scale = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = config.gridColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // 1. Dessiner les lignes Verticales
    // On boucle de 0 à la largeur totale, par pas de 'cellSize'
    for (double x = 0; x <= config.totalWidth; x += config.cellSize) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, config.totalHeight),
        paint,
      );
    }

    // 2. Dessiner les lignes Horizontales
    for (double y = 0; y <= config.totalHeight; y += config.cellSize) {
      canvas.drawLine(
        Offset(0, y),
        Offset(config.totalWidth, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    // On ne redessine que si la config (taille/couleur) change
    return config != oldDelegate.config;
  }
}
import 'dart:math';
import 'package:flutter/material.dart';
import '../../data/models/map_config_model.dart';
import '/core/utils/hex_utils.dart';

class TokenPainter extends CustomPainter {
  final MapConfig config;
  final Map<String, Point<int>> tokenPositions; // Où sont-ils ?
  final Map<String, dynamic> tokenDetails;      // Qui sont-ils ? (Couleur, Nom...)
  final double radius;
  final Offset offset;

  TokenPainter({
    required this.config,
    required this.tokenPositions,
    required this.tokenDetails,
    required this.radius,
    required this.offset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (var entry in tokenPositions.entries) {
      final charId = entry.key;
      final gridPoint = entry.value;
      
      // Récupération des infos (ou valeurs par défaut)
      final details = tokenDetails[charId] ?? {'color': Colors.blue, 'name': '?'};
      final Color color = details['color'] ?? Colors.blue;
      final String name = details['name'] ?? "?";
      final String initial = name.isNotEmpty ? name[0].toUpperCase() : "?";

      // Calcul du centre de la case
      final center = HexUtils.gridToPixel(gridPoint.x, gridPoint.y, radius);

      // 1. Dessiner le PION (Cercle)
      // On le fait légèrement plus petit que la case (0.8) pour voir le sol autour
      final tokenRadius = radius * 0.8;
      
      // Ombre portée
      canvas.drawCircle(
        center + const Offset(2, 2), 
        tokenRadius, 
        Paint()..color = Colors.black.withValues(alpha: 0.4)
      );

      // Bordure Blanche
      canvas.drawCircle(
        center, 
        tokenRadius, 
        Paint()..color = Colors.white
      );

      // Intérieur Coloré
      canvas.drawCircle(
        center, 
        tokenRadius - 3, // 3px de bordure
        Paint()..color = color
      );

      // 2. Dessiner la LETTRE (Initiale)
      textPainter.text = TextSpan(
        text: initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: tokenRadius, // Taille adaptative
          fontWeight: FontWeight.bold,
          shadows: const [Shadow(blurRadius: 2, color: Colors.black)],
        ),
      );
      
      textPainter.layout();
      textPainter.paint(
        canvas, 
        center - Offset(textPainter.width / 2, textPainter.height / 2)
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TokenPainter oldDelegate) {
    return tokenPositions != oldDelegate.tokenPositions || 
           tokenDetails != oldDelegate.tokenDetails;
  }
}
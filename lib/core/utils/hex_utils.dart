// Fichier : lib/features/map_editor/core/utils/hex_utils.dart
import 'dart:math';
import 'package:flutter/material.dart';

class HexUtils {
  static final double sqrt3 = sqrt(3); 

  static double width(double radius) => sqrt3 * radius;
  static double height(double radius) => 2 * radius;

  static Offset gridToPixel(int col, int row, double radius) {
    final w = width(radius);
    final h = height(radius);
    double x = (col * w) + ((row % 2) * (w / 2));
    double y = row * (h * 0.75);
    return Offset(x + w / 2, y + h / 2);
  }

  static Path getHexPath(double radius) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      double angleRad = (pi / 180) * (60.0 * i + 30);
      path.lineTo(radius * cos(angleRad), radius * sin(angleRad));
    }
    path.close();
    return path;
  }
  
  static Point<int> pixelToGrid(Offset localPosition, double radius, int maxCols, int maxRows) {
    Point<int>? bestPoint;
    double minDistance = double.infinity;
    for (int r = 0; r < maxRows; r++) {
      for (int c = 0; c < maxCols; c++) {
        final center = gridToPixel(c, r, radius);
        final dist = (center - localPosition).distance;
        if (dist < radius && dist < minDistance) {
          minDistance = dist;
          bestPoint = Point(c, r);
        }
      }
    }
    return bestPoint ?? const Point(-1, -1);
  }
}
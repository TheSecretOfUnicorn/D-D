import 'dart:math';
import 'package:flutter/material.dart';

class HexUtils {
  static final double sqrt3 = sqrt(3);

  static double width(double radius) => sqrt3 * radius;
  static double height(double radius) => 2 * radius;

  // --- 1. CONVERSION PIXEL / GRILLE ---

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
      final x = radius * cos(angleRad);
      final y = radius * sin(angleRad);
      if (i == 0) {
        path.moveTo(x, y);
      } else 
        {path.lineTo(x, y);}
    }
    path.close();
    return path;
  }
  
  static Point<int> pixelToGrid(Offset localPosition, double radius, int maxCols, int maxRows) {
    // Version optimisée possible, mais on garde la recherche brute pour l'instant (robuste)
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

  // --- 2. NOUVEAU : SYSTÈME CUBIQUE (POUR LES LIGNES DE VUE) ---
  
  // Convertit "Odd-r" (notre grille décalée) vers Cube (x, y, z)
  static HexCube offsetToCube(int col, int row) {
    var x = col - (row - (row & 1)) / 2;
    var z = row;
    var y = -x - z;
    return HexCube(x.toDouble(), y.toDouble(), z.toDouble());
  }

  // Convertit Cube vers "Odd-r" (col, row)
  static Point<int> cubeToOffset(HexCube cube) {
    var col = (cube.x + (cube.z - (cube.z.toInt() & 1)) / 2).toInt();
    var row = cube.z.toInt();
    return Point(col, row);
  }

  // Distance entre deux hexagones (en nombre de cases)
  static int distance(Point<int> a, Point<int> b) {
    var ac = offsetToCube(a.x, a.y);
    var bc = offsetToCube(b.x, b.y);
    return ((ac.x - bc.x).abs() + (ac.y - bc.y).abs() + (ac.z - bc.z).abs()) ~/ 2;
  }

  // Algorithme de tracé de ligne (Raycasting)
  // Retourne la liste des cases traversées entre Start et End
  static List<Point<int>> getLine(Point<int> start, Point<int> end) {
    var p0 = offsetToCube(start.x, start.y);
    var p1 = offsetToCube(end.x, end.y);
    var dist = distance(start, end);
    var results = <Point<int>>[];

    for (int i = 0; i <= dist; i++) {
      // Interpolation linéaire (Lerp)
      double t = dist == 0 ? 0.0 : i / dist;
      HexCube cube = _cubeLerp(p0, p1, t);
      results.add(cubeToOffset(_cubeRound(cube)));
    }
    return results;
  }

  // Helpers mathématiques privés pour les cubes
  static HexCube _cubeLerp(HexCube a, HexCube b, double t) {
    return HexCube(
      a.x + (b.x - a.x) * t,
      a.y + (b.y - a.y) * t,
      a.z + (b.z - a.z) * t,
    );
  }

  static HexCube _cubeRound(HexCube h) {
    var rx = h.x.round();
    var ry = h.y.round();
    var rz = h.z.round();

    var xDiff = (rx - h.x).abs();
    var yDiff = (ry - h.y).abs();
    var zDiff = (rz - h.z).abs();

    if (xDiff > yDiff && xDiff > zDiff) {
      rx = -ry - rz;
    } else if (yDiff > zDiff) {
      ry = -rx - rz;
    } else {
      rz = -rx - ry;
    }
    return HexCube(rx.toDouble(), ry.toDouble(), rz.toDouble());
  }

  static getNeighbors(Point<int> point) {}
}


// Petite classe utilitaire interne
class HexCube {
  final double x, y, z;
  HexCube(this.x, this.y, this.z);
    static Point<int> cubeToOffset(HexCube cube) {
    var col = (cube.x + (cube.z - (cube.z.toInt() & 1)) / 2).toInt();
    var row = cube.z.toInt();
    return Point(col, row);
  }
  // Convertit "Odd-r" (notre grille décalée) vers Cube (x, y, z)
  static HexCube offsetToCube(int col, int row) {
    var x = col - (row - (row & 1)) / 2;
    var z = row;
    var y = -x - z;
    return HexCube(x.toDouble(), y.toDouble(), z.toDouble());
  }

  // --- 3. VOISINS ET DIRECTIONS ---
  
  static List<Point<int>> getNeighbors(Point<int> hex) {
    // Les 6 directions en coordonnées cubiques
    var directions = [
      HexCube(1, -1, 0), HexCube(1, 0, -1), HexCube(0, 1, -1),
      HexCube(-1, 1, 0), HexCube(-1, 0, 1), HexCube(0, -1, 1),
    ];

    var center = offsetToCube(hex.x, hex.y);
    var neighbors = <Point<int>>[];

    for (var d in directions) {
      var neighborCube = HexCube(center.x + d.x, center.y + d.y, center.z + d.z);
      neighbors.add(cubeToOffset(neighborCube));
    }
    return neighbors;
  }
}


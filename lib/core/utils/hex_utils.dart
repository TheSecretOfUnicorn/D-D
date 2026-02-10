import 'dart:math';
import 'package:flutter/material.dart';

class HexUtils {
  // CORRECTION : On utilise sqrt(3) précis, pas d'approximation.
  static const double sqrt3 = 1.73205080757;

  /// Calcule la largeur totale d'un hexagone (Point à Point horizontalement ?)
  /// Non, pour un Pointy-Top, Width est la distance entre les côtés plats (gauche/droite)
  /// C'est souvent égal à 'cellSize' dans les réglages.
  static double width(double radius) => sqrt3 * radius;

  /// Hauteur totale (Point à Point verticalement)
  static double height(double radius) => 2 * radius;

  /// Convertit Grille -> Pixels (Centre)
  static Offset gridToPixel(int col, int row, double radius) {
    final w = width(radius);
    final h = height(radius);
    
    // Mathématiques exactes pour "Pointy Top" (Pointe en haut)
    // X : Chaque colonne avance de la largeur (w).
    // Les lignes impaires sont décalées de w/2.
    double x = (col * w) + (row % 2) * (w / 2);
    
    // Y : Chaque ligne avance de 3/4 de la hauteur (imbrication)
    double y = row * (h * 0.75);

    // On retourne le centre (+ w/2 pour centrer dans la bounding box virtuelle)
    return Offset(x + w / 2, y + h / 2);
  }

  /// Génère le tracé pour le dessin
  static Path getHexPath(double radius) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      // Angle exact pour Pointy Top : 30°, 90°, 150°, etc.
      double angleDeg = 60.0 * i + 30; 
      double angleRad = pi / 180 * angleDeg;
      
      // On utilise radius pour les points
      path.lineTo(
        radius * cos(angleRad), 
        radius * sin(angleRad)
      );
    }
    path.close();
    return path;
  }

  /// Detection du clic (Conversion Pixels -> Grille)
  static Point<int> pixelToGrid(Offset localPosition, double radius, int maxCols, int maxRows) {
    Point<int>? bestPoint;
    double minDistance = double.infinity;
    
    // Rayon de recherche (un peu plus large pour être sûr)
    // Optimisation possible : convertir en coordonnées axiales (q,r) directes
    // Mais cette boucle est assez rapide pour < 5000 cases.
    for (int r = 0; r < maxRows; r++) {
      for (int c = 0; c < maxCols; c++) {
        final center = gridToPixel(c, r, radius);
        final dist = (center - localPosition).distance;
        
        // Si on est DANS l'hexagone (distance < rayon * facteur formel)
        // radius * sqrt(3)/2 est la distance centre-bord plat.
        if (dist < radius) { 
          if (dist < minDistance) {
            minDistance = dist;
            bestPoint = Point(c, r);
          }
        }
      }
    }
    return bestPoint ?? const Point(-1, -1);
  }
}
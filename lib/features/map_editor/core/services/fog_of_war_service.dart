import 'dart:math';
// Assure-toi que ce fichier existe (Etape précédente)
import '/core/utils/hex_utils.dart';

class FogOfWarService {
  /// Calcule les cases visibles
  /// [tokens] : Positions des personnages
  /// [walls] : Liste des cases "Mur" (Bloquantes)
  /// [visionRange] : Rayon de vision en cases (ex: 6)
  static Set<String> calculateVisibility({
    required List<Point<int>> tokens,
    required Set<String> walls,
    required int maxCols,
    required int maxRows,
    int visionRange = 8,
  }) {
    final Set<String> visibleCells = {};

    for (var tokenPos in tokens) {
      // 1. Pour chaque case de la bordure (le périmètre du cercle de vision)
      // On lance un rayon depuis le token vers cette case
      // Note : Une optimisation serait de ne faire que le périmètre, 
      // ici on scanne un carré autour pour faire simple.
      
      int startCol = max(0, tokenPos.x - visionRange);
      int endCol = min(maxCols, tokenPos.x + visionRange);
      int startRow = max(0, tokenPos.y - visionRange);
      int endRow = min(maxRows, tokenPos.y + visionRange);

      // On cible les bords du carré de vision pour lancer les rayons
      for (int c = startCol; c <= endCol; c++) {
        for (int r = startRow; r <= endRow; r++) {
          
          // On ne lance un rayon QUE si c'est une case de bordure de notre zone de recherche
          // (pour éviter de lancer 1000 rayons, on lance juste vers l'extérieur)
          bool isBorder = c == startCol || c == endCol || r == startRow || r == endRow;
          
          // Exception : on calcule aussi si c'est proche (optimisation visual)
          if (isBorder || HexUtils.distance(tokenPos, Point(c,r)) <= visionRange) {
             _castRay(tokenPos, Point(c, r), walls, visibleCells, visionRange);
          }
        }
      }
    }
    return visibleCells;
  }

  static void _castRay(
    Point<int> start, 
    Point<int> end, 
    Set<String> walls, 
    Set<String> visibleCells, 
    int range
  ) {
    final line = HexUtils.getLine(start, end);
    
    for (var point in line) {
      // Si trop loin, on arrête
      if (HexUtils.distance(start, point) > range) break;

      final key = "${point.x},${point.y}";
      
      // Cette case est visible
      visibleCells.add(key);

      // Si c'est un mur, on voit le mur, MAIS on ne voit pas derrière.
      // Donc on marque visible, PUIS on arrête le rayon.
      if (walls.contains(key)) {
        break;
      }
    }
  }
}
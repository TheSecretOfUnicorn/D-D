import 'dart:math';
// Assure-toi que ce fichier existe (Etape précédente)
import '/core/utils/hex_utils.dart';



class FogOfWarService {
  static Set<String> calculateVisibility({
    required List<Point<int>> tokens,
    required Set<String> walls,
    required int maxCols,
    required int maxRows,
    int visionRange = 8,
  }) {
    final Set<String> visibleCells = {};

    for (var tokenPos in tokens) {
      int startCol = max(0, tokenPos.x - visionRange);
      int endCol = min(maxCols, tokenPos.x + visionRange);
      int startRow = max(0, tokenPos.y - visionRange);
      int endRow = min(maxRows, tokenPos.y + visionRange);

      for (int c = startCol; c <= endCol; c++) {
        for (int r = startRow; r <= endRow; r++) {
          bool isBorder = c == startCol || c == endCol || r == startRow || r == endRow;
          if (isBorder || HexUtils.distance(tokenPos, Point(c,r)) <= visionRange) {
             _castRay(tokenPos, Point(c, r), walls, visibleCells, visionRange);
          }
        }
      }
    }
    return visibleCells;
  }

  static void _castRay(Point<int> start, Point<int> end, Set<String> walls, Set<String> visibleCells, int range) {
    final line = HexUtils.getLine(start, end);
    for (var point in line) {
      if (HexUtils.distance(start, point) > range) break;
      final key = "${point.x},${point.y}";
      visibleCells.add(key);
      if (walls.contains(key)) break; // Le mur bloque la vue
    }
  }
}
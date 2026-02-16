import 'dart:math';
// Assure-toi que ce fichier existe (Etape précédente)
import '/core/utils/hex_utils.dart';

class VisionSource {
  final Point<int> position;
  final int range;
  VisionSource(this.position, this.range);
}

class FogOfWarService {
  static Set<String> calculateVisibility({
    required List<VisionSource> sources,
    required Set<String> walls,
    required int maxCols,
    required int maxRows,
    int visionRange = 8,
  }) {
    final Set<String> visibleCells = {};

    for (var source in sources) {
      if (source.range <= 0) continue; // Ignore les lumières éteintes

      int startCol = max(0, source.position.x - source.range);
      int endCol = min(maxCols, source.position.x + source.range);
      int startRow = max(0, source.position.y - source.range);
      int endRow = min(maxRows, source.position.y + source.range);

      for (int c = startCol; c <= endCol; c++) {
        for (int r = startRow; r <= endRow; r++) {
          // Optimisation : boîte englobante simple avant Raycasting
          if (HexUtils.distance(source.position, Point(c,r)) <= source.range) {
             _castRay(source.position, Point(c, r), walls, visibleCells, source.range);
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
      if (walls.contains(key)) break;
    }
  }
}
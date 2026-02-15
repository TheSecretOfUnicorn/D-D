import 'dart:math';
import '/core/utils/hex_utils.dart';

class PathfindingService {
  /// Retourne l'ensemble des cases accessibles depuis [start] en [movement] pas.
  /// [walls] : Liste des cases bloquantes.
  static Set<String> getReachableCells({
    required Point<int> start,
    required int movement,
    required Set<String> walls,
    required int maxCols,
    required int maxRows,
  }) {
    final Set<String> reachable = {};
    final Set<String> visited = {};
    
    // File d'attente : [Point, distance_restante]
    final List<MapEntry<Point<int>, int>> queue = [];
    queue.add(MapEntry(start, movement));
    visited.add("${start.x},${start.y}");
    reachable.add("${start.x},${start.y}");

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final point = current.key;
      final movesLeft = current.value;

      if (movesLeft <= 0) continue;

      for (var neighbor in HexUtils.getNeighbors(point)) {
        // Vérifier limites de la carte
        if (neighbor.x < 0 || neighbor.x >= maxCols || neighbor.y < 0 || neighbor.y >= maxRows) continue;

        final key = "${neighbor.x},${neighbor.y}";
        
        // Si c'est un mur ou déjà visité, on ignore
        if (walls.contains(key) || visited.contains(key)) continue;

        visited.add(key);
        reachable.add(key);
        queue.add(MapEntry(neighbor, movesLeft - 1));
      }
    }
    return reachable;
  }
}
import 'dart:math';

enum ObjectType {
  door,   // Bloque la vue si fermé, laisse passer si ouvert
  chest,  // Bloque le mouvement, peut être pillé
  torch,  // Source de lumière (décoratif pour l'instant)
}

class WorldObject {
  final String id;
  final Point<int> position;
  final ObjectType type;
  bool state; // true = Ouvert/Allumé, false = Fermé/Éteint
  final int rotation;

  WorldObject({
    required this.id,
    required this.position,
    required this.type,
    this.state = false, // Par défaut : Porte fermée, Coffre fermé
    this.rotation = 0,
  });

  // Pour cloner l'objet avec un nouvel état (Immutabilité partielle)
WorldObject copyWith({bool? state, int? rotation}) {
    return WorldObject(
      id: id,
      position: position,
      type: type,
      state: state ?? this.state,
      rotation: rotation ?? this.rotation,
    );
  }
}

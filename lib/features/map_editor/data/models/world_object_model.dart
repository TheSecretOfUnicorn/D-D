import 'dart:math';

enum ObjectType { door, chest, torch, trap, custom }

class WorldObject {
  final String id;
  final Point<int> position;
  final ObjectType type;
  final bool state; // false=fermé/éteint, true=ouvert/allumé
  final double lightRadius;
  final int lightColor;
  final int rotation; // 0..7

  WorldObject({
    required this.id,
    required this.position,
    required this.type,
    this.state = false,
    this.lightRadius = 0,
    this.lightColor = 0xFFFFA726,
    this.rotation = 0,
  });

  // ✅ Méthode copyWith (pour l'éditeur)
  WorldObject copyWith({
    String? id,
    Point<int>? position,
    ObjectType? type,
    bool? state,
    double? lightRadius,
    int? lightColor,
    int? rotation,
  }) {
    return WorldObject(
      id: id ?? this.id,
      position: position ?? this.position,
      type: type ?? this.type,
      state: state ?? this.state,
      lightRadius: lightRadius ?? this.lightRadius,
      lightColor: lightColor ?? this.lightColor,
      rotation: rotation ?? this.rotation,
    );
  }

  // ✅ Méthode toJson (pour l'envoi au serveur)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'x': position.x,
      'y': position.y,
      'type': type.index, // On stocke l'index de l'enum (0, 1, 2...)
      'state': state,
      'lightRadius': lightRadius,
      'lightColor': lightColor,
      'rotation': rotation,
    };
  }

  // ✅ Méthode fromJson (pour la lecture depuis le serveur)
  factory WorldObject.fromJson(Map<String, dynamic> json) {
    return WorldObject(
      id: json['id'] ?? 'unknown',
      position: Point<int>(json['x'] ?? 0, json['y'] ?? 0),
      type: ObjectType.values[json['type'] ?? 0], // On récupère l'enum depuis l'index
      state: json['state'] ?? false,
      lightRadius: (json['lightRadius'] ?? 0).toDouble(),
      lightColor: json['lightColor'] ?? 0xFFFFA726,
      rotation: json['rotation'] ?? 0,
    );
  }
}
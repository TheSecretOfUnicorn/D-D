import 'dart:ui';
import 'dart:math';

import 'map_config_model.dart';
import 'tile_type.dart';
import 'world_object_model.dart';

class MapDataModel {
  final String? id;
  final String name;
  final MapConfig config;
  
  // Données de la carte
  final Map<String, TileType> gridData;
  final Map<String, WorldObject> objects;
  final Map<String, int> tileRotations;

  // Paramètres de jeu
  final int visionRange;
  final int movementRange;

  MapDataModel({
    this.id,
    required this.name,
    required this.config,
    required this.gridData,
    this.objects = const {},
    this.visionRange = 8,
    this.movementRange = 6,
    this.tileRotations = const {},
  });

  // --- SÉRIALISATION JSON (Vers le serveur) ---

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      // On stocke les dimensions à la racine pour accès facile
      'width': config.widthInCells,
      'height': config.heightInCells,
      
      // Tout le reste va dans un champ 'json_data' flexible
      'json_data': {
        // 1. Configuration (Couleurs, Taille case)
        'config': {
          'cellSize': config.cellSize,
          'bgColor': config.backgroundColor, // On stocke l'entier de la couleur
          'gridColor': config.gridColor,
        },
        
        // 2. Règles de jeu
        'settings': {
          'visionRange': visionRange,
          'movementRange': movementRange,
        },

        // 3. Grille (Tuiles)
        // On convertit la Map<String, TileType> en liste d'objets simple
        'grid': gridData.entries.map((e) => {
          'k': e.key, // Coordonnée "x,y"
          't': e.value.index, // Index de l'enum (0, 1, 2...) pour prendre moins de place
          'r': tileRotations[e.key] ?? 0 // Rotation associée à la tuile
          
        }).toList(),

        // 4. Objets Interactifs
        'objects': objects.values.map((obj) => {
          'id': obj.id,
          'x': obj.position.x,
          'y': obj.position.y,
          'type': obj.type.index, // Index enum ObjectType
          'state': obj.state,
          'rotation': obj.rotation,
        }).toList(),
      },
    };
  }

  // --- DÉSÉRIALISATION JSON (Depuis le serveur) ---

  factory MapDataModel.fromJson(Map<String, dynamic> json) {
    // Extraction sécurisée des données
    final jsonData = json['json_data'] ?? {};
    final configData = jsonData['config'] ?? {};
    final settingsData = jsonData['settings'] ?? {};

    // 1. Reconstruction de la Config
    final config = MapConfig(
      widthInCells: json['width'] ?? 20,
      heightInCells: json['height'] ?? 16,
      cellSize: (configData['cellSize'] ?? 64.0).toDouble(),
      backgroundColor: Color(configData['bgColor'] ?? 0xFFE0D8C0),
      gridColor: Color(configData['gridColor'] ?? 0x4D5C4033),
    );

    // 2. Reconstruction de la Grille
    final Map<String, TileType> grid = {};
    final Map<String, int> rotations = {};
    if (jsonData['grid'] != null) {
      for (var item in jsonData['grid']) {
        final key = item['k'];
        final typeIndex = item['t'];
        final rot = item['r'] ?? 0;
        if (key != null && typeIndex != null && typeIndex < TileType.values.length) {
          grid[key] = TileType.values[typeIndex];
        }
        if (rot > 0) rotations[key] = rot; // On ne stocke que si rotation > 0
      }
    }

    // 3. Reconstruction des Objets
    final Map<String, WorldObject> objs = {};
    if (jsonData['objects'] != null) {
      for (var item in jsonData['objects']) {
        final x = item['x'] ?? 0;
        final y = item['y'] ?? 0;
        final typeIndex = item['type'] ?? 0;
        
        // On recrée l'objet
        final obj = WorldObject(
          id: item['id'] ?? DateTime.now().toString(),
          position: Point(x, y),
          type: (typeIndex < ObjectType.values.length) 
              ? ObjectType.values[typeIndex] 
              : ObjectType.door,
          state: item['state'] ?? false,
          rotation: item['rot'] ?? 0, //
        );
        
        objs["$x,$y"] = obj;
      }
    }

    return MapDataModel(
      id: json['id']?.toString(), // S'assure que c'est une String
      name: json['name'] ?? "Carte sans nom",
      config: config,
      gridData: grid,
      objects: objs,
      visionRange: settingsData['visionRange'] ?? 8,
      movementRange: settingsData['movementRange'] ?? 6,
      tileRotations: rotations,
    );
  }
}
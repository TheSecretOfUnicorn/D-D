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
  final Map<String, int> tileRotations; // Clé "x,y" -> Rotation (0-5)
  final Map<String, WorldObject> objects;
  final Map<String, String> customAssets; 

  // Paramètres de jeu
  final int visionRange;
  final int movementRange;

  MapDataModel({
    this.id,
    required this.name,
    required this.config,
    required this.gridData,
    this.tileRotations = const {},
    this.objects = const {},
    this.customAssets = const {},
    this.visionRange = 8,
    this.movementRange = 6,
  });

  // --- SÉRIALISATION JSON (Vers le serveur) ---

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'width': config.widthInCells,
      'height': config.heightInCells,
      
      'json_data': {
        'config': {
          'cellSize': config.cellSize,
          // ⚠️ IMPORTANT : On utilise .value pour sauvegarder l'entier de la couleur
          'bgColor': config.backgroundColor.toARGB32(), 
          'gridColor': config.gridColor.toARGB32(),     
        },
        
        'settings': {
          'visionRange': visionRange,
          'movementRange': movementRange,
        },

        'assets': customAssets,

        // 3. Grille (Tuiles)
        'grid': gridData.entries.map((e) => {
          'k': e.key,
          't': e.value.index, // ✅ CORRECT : e.value.index (pas e.index)
          'r': tileRotations[e.key] ?? 0
        }).toList(),

        // 4. Objets Interactifs
        'objects': objects.values.map((obj) => {
          'id': obj.id,
          'x': obj.position.x,
          'y': obj.position.y,
          'type': obj.type.index,
          'state': obj.state,
          'rot': obj.rotation,
          'lr': obj.lightRadius,
          'lc': obj.lightColor,
        }).toList(),
      },
    };
  }

  // --- DÉSÉRIALISATION JSON (Depuis le serveur) ---

  factory MapDataModel.fromJson(Map<String, dynamic> json) {
    final jsonData = json['json_data'] ?? {};
    final configData = jsonData['config'] ?? {};
    final settingsData = jsonData['settings'] ?? {};

    // Chargement Assets
    final Map<String, String> loadedAssets = {};
    if (jsonData['assets'] != null) {
      (jsonData['assets'] as Map).forEach((k, v) => loadedAssets[k.toString()] = v.toString());
    }

    // Config
    final config = MapConfig(
      widthInCells: json['width'] ?? 20,
      heightInCells: json['height'] ?? 16,
      cellSize: (configData['cellSize'] ?? 64.0).toDouble(),
      backgroundColor: Color(configData['bgColor'] ?? 0xFFE0D8C0),
      gridColor: Color(configData['gridColor'] ?? 0x4D5C4033),
    );

    // Grille & Rotations
    final Map<String, TileType> grid = {};
    final Map<String, int> rotations = {};
    if (jsonData['grid'] != null) {
      for (var item in jsonData['grid']) {
        final key = item['k'];
        final typeIndex = item['t'];
        final rot = item['r'] ?? 0;
        
        // ✅ CORRECT : TileType (Singulier)
        if (key != null && typeIndex != null && typeIndex < TileType.values.length) {
          grid[key] = TileType.values[typeIndex];
          if (rot > 0) rotations[key] = rot;
        }
      }
    }

    // Objets
    final Map<String, WorldObject> objs = {};
    if (jsonData['objects'] != null) {
      for (var item in jsonData['objects']) {
        final x = item['x'] ?? 0;
        final y = item['y'] ?? 0;
        final typeIndex = item['type'] ?? 0;
        
        final obj = WorldObject(
          id: item['id'] ?? DateTime.now().toString(),
          position: Point(x, y),
          type: (typeIndex < ObjectType.values.length) 
              ? ObjectType.values[typeIndex] 
              : ObjectType.door,
          state: item['state'] ?? false,
          rotation: item['rot'] ?? 0,
          lightRadius: (item['lr'] ?? 0.0).toDouble(),
          lightColor: item['lc'] ?? 0xFFFFA726,
        );
        objs["$x,$y"] = obj;
      }
    }

    return MapDataModel(
      id: json['id']?.toString(),
      name: json['name'] ?? "Carte sans nom",
      config: config,
      gridData: grid,
      tileRotations: rotations,
      objects: objs,
      customAssets: loadedAssets,
      visionRange: settingsData['visionRange'] ?? 8,
      movementRange: settingsData['movementRange'] ?? 6,
    );
  }
}
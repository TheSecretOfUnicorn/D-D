import 'dart:ui';
import 'map_config_model.dart';

class MapDataModel {
  final int? id;
  final String name;
  final MapConfig config;
  final Set<String> paintedCells; // Ex: {"1,2", "5,5"}

  MapDataModel({
    this.id,
    required this.name,
    required this.config,
    required this.paintedCells,
  });

  // --- JSON SERIALIZATION (Pour l'envoi au serveur) ---
  
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'width': config.widthInCells,
      'height': config.heightInCells,
      'json_data': {
        'config': {
          'cellSize': config.cellSize,
          'bgColor': config.backgroundColor,
          'gridColor': config.gridColor,
        },
        // On transforme le Set en Liste pour le JSON
        'cells': paintedCells.toList(), 
      },
    };
  }

  // --- JSON DESERIALIZATION (Pour la réception du serveur) ---

  factory MapDataModel.fromJson(Map<String, dynamic> json) {
    final data = json['json_data'] ?? {};
    final configData = data['config'] ?? {};
    final List<dynamic> cellList = data['cells'] ?? [];

    return MapDataModel(
      id: json['id'],
      name: json['name'],
      paintedCells: Set<String>.from(cellList.map((e) => e.toString())),
      config: MapConfig(
        widthInCells: json['width'] ?? 20,
        heightInCells: json['height'] ?? 15,
        cellSize: (configData['cellSize'] ?? 64.0).toDouble(),
        backgroundColor: Color(configData['bgColor'] ?? 0xFFE0D8C0),
        gridColor: Color(configData['gridColor'] ?? 0x4D5C4033),
      ),
    );
  }
}
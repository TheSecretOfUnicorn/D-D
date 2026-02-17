import 'dart:convert';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/map_data_model.dart';       // Vérifie ce chemin
import '../models/map_config_model.dart';     // Vérifie ce chemin
import '../models/tile_type.dart';            // Vérifie ce chemin
import '../models/world_object_model.dart';   // Vérifie ce chemin
import '../../../../core/utils/logger_service.dart';

class MapRepository {
  final String baseUrl = "http://sc2tphk4284.universe.wf/api_jdr";

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'Content-Type': 'application/json',
      'x-user-id': prefs.get('user_id')?.toString() ?? '',
    };
  }

  // 1. CHARGER UNE CARTE
  Future<MapDataModel?> getMapData(String mapId) async {
    try {
      final headers = await _getHeaders();
      Log.error("📥 Chargement carte ID: $mapId ...");
      final response = await http.get(Uri.parse("$baseUrl/maps/$mapId"), headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // 1. Récupération de json_data (qui contient tout le dessin)
        final jsonData = data['json_data'];
        if (jsonData == null) return null; // Carte vide

        // 2. Reconstruction de la Config
        final configJson = jsonData['config'] ?? {};
        final config = MapConfig(
          widthInCells: data['width'] ?? 20,
          heightInCells: data['height'] ?? 15,
          cellSize: (configJson['cellSize'] ?? 64.0).toDouble(),
          backgroundColor: Color(configJson['bgColor'] ?? 0xFFE0D8C0),
          gridColor: Color(configJson['gridColor'] ?? 0x4D5C4033),
        );

        // 3. Reconstruction de la Grille (TileType)
        final Map<String, TileType> grid = {};
        if (jsonData['tiles'] != null) {
          Map<String, dynamic> tilesMap = jsonData['tiles'];
          tilesMap.forEach((key, value) {
            // value est l'index (0, 1, 2...) de l'enum
            if (value is int && value < TileType.values.length) {
              grid[key] = TileType.values[value];
            }
          });
        }

        // 4. Reconstruction des Objets (WorldObject)
        final Map<String, WorldObject> objects = {};
        if (jsonData['objects'] != null) {
          List<dynamic> objectsList = jsonData['objects'];
          for (var objJson in objectsList) {
            try {
              final obj = WorldObject.fromJson(objJson);
              final key = "${obj.position.x},${obj.position.y}";
              objects[key] = obj;
            } catch (e) {
              Log.error("⚠️ Objet corrompu ignoré: $e");
            }
          }
        }

        Log.error("✅ Carte chargée: ${grid.length} tuiles, ${objects.length} objets.");

        return MapDataModel(
          id: data['id'].toString(),
          name: data['name'],
          config: config,
          gridData: grid,
          objects: objects,
        );
      } else {
        Log.error("❌ Erreur Serveur: ${response.statusCode}");
      }
    } catch (e) {
      Log.error("❌ Exception getMapData: $e");
    }
    return null;
  }

  // 2. CRÉER UNE CARTE (POST)
  Future<int?> createMap(int campaignId, String name, MapConfig config) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse("$baseUrl/campaigns/$campaignId/maps"),
        headers: headers,
        body: jsonEncode({
          "name": name,
          "width": config.widthInCells,
          "height": config.heightInCells
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['id'];
      }
    } catch (e) {
      Log.error("❌ Erreur createMap: $e");
    }
    return null;
  }

  // 3. SAUVEGARDER (PUT)
  Future<bool> saveMapData(MapDataModel map) async {
    try {
      final headers = await _getHeaders();
      
      // Conversion des Enums en Index pour le JSON
      final tilesJson = map.gridData.map((k, v) => MapEntry(k, v.index));
      
      // Conversion des Objets
      final objectsJson = map.objects.values.map((o) => o.toJson()).toList();

      final body = {
        'width': map.config.widthInCells,
        'height': map.config.heightInCells,
        'json_data': {
          'config': {
            'cellSize': map.config.cellSize,
            'bgColor': map.config.backgroundColor.toARGB32(),
            'gridColor': map.config.gridColor.toARGB32(),
          },
          'tiles': tilesJson,
          'objects': objectsJson,
        },
      };

      final response = await http.put(
        Uri.parse("$baseUrl/maps/${map.id}/data"),
        headers: headers,
        body: jsonEncode(body),
      );

      return response.statusCode == 200;
    } catch (e) {
      Log.error("❌ Erreur saveMapData: $e");
      return false;
    }
  }
}
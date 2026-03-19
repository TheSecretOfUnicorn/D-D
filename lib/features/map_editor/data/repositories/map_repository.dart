import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:http/http.dart' as http;

import '../../../../core/config/api_config.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/utils/logger_service.dart';
import '../models/map_config_model.dart';
import '../models/map_data_model.dart';
import '../models/tile_type.dart';
import '../models/world_object_model.dart';

class MapRepository {
  final SessionService _sessionService = SessionService();
  final String baseUrl = ApiConfig.baseUrl;

  Future<Map<String, String>> _getHeaders() => _sessionService.authHeaders();

  Future<MapDataModel?> getMapData(String mapId) async {
    try {
      final headers = await _getHeaders();
      Log.error("Chargement carte ID: $mapId ...");
      final response = await http.get(
        Uri.parse("$baseUrl/maps/$mapId"),
        headers: headers,
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        Log.error("Erreur Serveur getMapData", response.statusCode);
        return null;
      }

      final data = jsonDecode(response.body);
      final jsonData = data['json_data'];
      if (jsonData == null) return null;

      final configJson = jsonData['config'] ?? {};
      final config = MapConfig(
        widthInCells: data['width'] ?? 20,
        heightInCells: data['height'] ?? 15,
        cellSize: (configJson['cellSize'] ?? 64.0).toDouble(),
        backgroundColor: Color(configJson['bgColor'] ?? 0xFFE0D8C0),
        gridColor: Color(configJson['gridColor'] ?? 0x4D5C4033),
      );

      final grid = <String, TileType>{};
      if (jsonData['tiles'] != null) {
        final tilesMap = Map<String, dynamic>.from(jsonData['tiles']);
        tilesMap.forEach((key, value) {
          if (value is int && value >= 0 && value < TileType.values.length) {
            grid[key] = TileType.values[value];
          }
        });
      }

      final objects = <String, WorldObject>{};
      if (jsonData['objects'] != null) {
        final objectsList = List<dynamic>.from(jsonData['objects']);
        for (final objJson in objectsList) {
          try {
            final obj = WorldObject.fromJson(objJson);
            objects["${obj.position.x},${obj.position.y}"] = obj;
          } catch (e) {
            Log.error("Objet corrompu ignore", e);
          }
        }
      }

      final tokens = <String, Point<int>>{};
      if (data['tokens'] is Map) {
        Map<Object?, Object?>.from(data['tokens']).forEach((key, value) {
          if (value is Map) {
            final x = value['x'];
            final y = value['y'];
            if (x is int && y is int) {
              tokens[key.toString()] = Point<int>(x, y);
            }
          }
        });
      }

      return MapDataModel(
        id: data['id'].toString(),
        name: data['name'],
        config: config,
        gridData: grid,
        objects: objects,
        tokenPositions: tokens,
      );
    } catch (e) {
      Log.error("Exception getMapData", e);
      return null;
    }
  }

  Future<int?> createMap(int campaignId, String name, MapConfig config) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse("$baseUrl/campaigns/$campaignId/maps"),
        headers: headers,
        body: jsonEncode({
          "name": name,
          "width": config.widthInCells,
          "height": config.heightInCells,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body)['id'];
      }
    } catch (e) {
      Log.error("Erreur createMap", e);
    }
    return null;
  }

  Future<bool> saveMapData(MapDataModel map) async {
    try {
      final headers = await _getHeaders();
      final tilesJson = map.gridData.map((k, v) => MapEntry(k, v.index));
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

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      Log.error("Erreur saveMapData", e);
      return false;
    }
  }

  Future<bool> saveTokenPositions(
    String mapId,
    Map<String, Point<int>> tokenPositions,
  ) async {
    try {
      final headers = await _getHeaders();
      final tokensJson = tokenPositions.map(
        (key, value) => MapEntry(key, {'x': value.x, 'y': value.y}),
      );

      final response = await http.patch(
        Uri.parse("$baseUrl/maps/$mapId/tokens"),
        headers: headers,
        body: jsonEncode({'tokens': tokensJson}),
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      Log.error("Erreur saveTokenPositions", e);
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getCampaignMaps(int campaignId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse("$baseUrl/campaigns/$campaignId/maps"),
        headers: headers,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      Log.error("Erreur getCampaignMaps", e);
    }
    return const [];
  }

  Future<bool> activateMap(String mapId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse("$baseUrl/maps/$mapId/activate"),
        headers: headers,
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      Log.error("Erreur activateMap", e);
      return false;
    }
  }

  Future<bool> renameMap(String mapId, String name) async {
    try {
      final trimmedName = name.trim();
      if (trimmedName.isEmpty) return false;
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse("$baseUrl/maps/$mapId/meta"),
        headers: headers,
        body: jsonEncode({'name': trimmedName}),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      Log.error("Erreur renameMap", e);
      return false;
    }
  }

  Future<bool> deleteMap(String mapId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse("$baseUrl/maps/$mapId"),
        headers: headers,
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      Log.error("Erreur deleteMap", e);
      return false;
    }
  }

  Future<Map<String, dynamic>?> getActiveMapSummary(int campaignId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse("$baseUrl/campaigns/$campaignId/map/active"),
        headers: headers,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = jsonDecode(response.body);
        if (json['active'] == true && json['map'] is Map<String, dynamic>) {
          return Map<String, dynamic>.from(json['map']);
        }
      }
    } catch (e) {
      Log.error("Erreur getActiveMapSummary", e);
    }
    return null;
  }

  Future<String?> getActiveMapId(int campaignId) async {
    final activeMap = await getActiveMapSummary(campaignId);
    return activeMap?['id']?.toString();
  }
}

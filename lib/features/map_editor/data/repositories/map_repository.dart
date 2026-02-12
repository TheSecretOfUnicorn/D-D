import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/utils/logger_service.dart';
import '../models/map_data_model.dart';

class MapRepository {
  // ⚠️ Mettez votre URL correcte ici
  final String baseUrl = "http://sc2tphk4284.universe.wf/api_jdr"; 

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.get('user_id')?.toString();
    return {
      'Content-Type': 'application/json',
      'x-user-id': userId ?? '',
    };
  }

  /// Sauvegarder la carte (Dessin + Config)
  Future<bool> saveMapData(MapDataModel map) async {
    if (map.id == null) return false;
    try {
      final headers = await _getHeaders();
      final body = map.toJson(); // Utilise la structure définie dans l'étape 2

      final response = await http.put(
        Uri.parse("$baseUrl/maps/${map.id}/data"),
        headers: headers,
        body: jsonEncode(body),
      );

      return response.statusCode == 200;
    } catch (e) {
      Log.error("Erreur saveMapData", e);
      return false;
    }
  }

  /// Récupérer la carte active d'une campagne
  Future<MapDataModel?> getActiveMap(int campaignId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse("$baseUrl/campaigns/$campaignId/map/active"),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['active'] == true && json['map'] != null) {
          return MapDataModel.fromJson(json['map']);
        }
      }
      return null;
    } catch (e) {
      Log.error("Erreur getActiveMap", e);
      return null;
    }
  }
}
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/campaign_model.dart';
import '../../../../core/utils/logger_service.dart';

class CampaignRepository {
  // ⚠️ Assurez-vous que cette URL est correcte
  final String baseUrl = "http://sc2tphk4284.universe.wf/api_jdr"; 

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.get('user_id')?.toString();
    
    if (userId == null) throw Exception("Utilisateur non connecté");
    
    return {
      'Content-Type': 'application/json',
      'x-user-id': userId,
    };
  }

  // --- 1. GESTION DES CAMPAGNES ---

  Future<List<CampaignModel>> getAllCampaigns() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse("$baseUrl/campaigns"), headers: headers);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => CampaignModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      Log.error("Exception getAllCampaigns", e);
      return [];
    }
  }

  Future<CampaignModel?> createCampaign(String title) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse("$baseUrl/campaigns"),
        headers: headers,
        body: jsonEncode({"title": title}),
      );
      if (response.statusCode == 200) {
        return CampaignModel.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<CampaignModel?> joinCampaign(String code) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse("$baseUrl/campaigns/join"),
        headers: headers,
        body: jsonEncode({"code": code}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return CampaignModel.fromJson(data['campaign']);
      }
      throw Exception(jsonDecode(response.body)['error'] ?? "Erreur"); 
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> deleteCampaign(int campaignId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(Uri.parse("$baseUrl/campaigns/$campaignId"), headers: headers);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // --- 2. GESTION DU JEU (LOGS & DÉS) ---

  Future<bool> sendLog(int campaignId, String content, {String type = 'MSG', int resultValue = 0}) async {
    try {
      final headers = await _getHeaders();
      await http.post(
        Uri.parse("$baseUrl/campaigns/$campaignId/logs"),
        headers: headers,
        body: jsonEncode({ "content": content, "type": type, "result_value": resultValue }),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getLogs(int campaignId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse("$baseUrl/campaigns/$campaignId/logs"), headers: headers);
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> updateSettings(int campaignId, bool allowDice) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse("$baseUrl/campaigns/$campaignId/settings"),
        headers: headers,
        body: jsonEncode({"allow_dice": allowDice}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getMembers(int campaignId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse("$baseUrl/campaigns/$campaignId/members"), headers: headers);
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> selectCharacter(int campaignId, String characterId) async {
    try {
      final headers = await _getHeaders();
      await http.post(
        Uri.parse("$baseUrl/campaigns/$campaignId/select-character"),
        headers: headers,
        body: jsonEncode({"character_id": int.tryParse(characterId)}),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateMemberStat(int campaignId, String charId, String key, dynamic value) async {
    try {
      final headers = await _getHeaders();
      await http.patch(
        Uri.parse("$baseUrl/campaigns/$campaignId/members/$charId/stats"),
        headers: headers,
        body: jsonEncode({"key": key, "value": value}),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- 3. COMBAT TRACKER (LES FONCTIONS MANQUANTES) ---

  Future<Map<String, dynamic>> getCombatDetails(int campaignId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse("$baseUrl/campaigns/$campaignId/combat"), headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'active': false};
    } catch (e) {
      return {'active': false};
    }
  }

  Future<bool> startCombat(int campaignId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(Uri.parse("$baseUrl/campaigns/$campaignId/combat/start"), headers: headers);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateParticipant(int campaignId, int participantId, Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse("$baseUrl/campaigns/$campaignId/combat/participants/$participantId"),
        headers: headers,
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
/// MJ : Passe au tour suivant
  Future<bool> nextTurn(int campaignId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse("$baseUrl/campaigns/$campaignId/combat/next"),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// MJ : Met fin au combat
  Future<bool> stopCombat(int campaignId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse("$baseUrl/campaigns/$campaignId/combat/stop"),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
/// MJ : Ajoute un monstre/PNJ au combat
  Future<bool> addParticipant(int campaignId, String name, int hp, int? initiative) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse("$baseUrl/campaigns/$campaignId/combat/add"),
        headers: headers,
        body: jsonEncode({
          "name": name,
          "hp": hp,
          "initiative": initiative // Peut être null (le serveur lancera le dé)
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      Log.error("Erreur addParticipant", e);
      return false;
    }
  }


}
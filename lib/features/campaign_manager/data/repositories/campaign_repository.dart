import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/campaign_model.dart';
import '../../../../core/utils/logger_service.dart';

class CampaignRepository {
  // En production, mettez l'URL dans un fichier .env
  final String baseUrl = "http://sc2tphk4284.universe.wf/api_jdr"; 

  // --- 👇 CORRECTION ICI 👇 ---
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    
    // CORRECTION : On utilise .get() pour accepter int ou String, puis .toString()
    final userId = prefs.get('user_id')?.toString(); 
    
    if (userId == null) throw Exception("Utilisateur non connecté");
    
    return {
      'Content-Type': 'application/json',
      'x-user-id': userId,
    };
  }
  // --- 👆 FIN CORRECTION 👆 ---

  // --- 1. GESTION DES CAMPAGNES ---

  Future<List<CampaignModel>> getAllCampaigns() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse("$baseUrl/campaigns"), headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => CampaignModel.fromJson(json)).toList();
      } else {
        Log.error("Erreur serveur (${response.statusCode}): ${response.body}");
        return [];
      }
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
      Log.warning("Echec création campagne: ${response.body}");
      return null;
    } catch (e) {
      Log.error("Exception createCampaign", e);
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
      } else {
        final errorMsg = jsonDecode(response.body)['error'] ?? "Erreur inconnue";
        Log.warning("Join Fail: $errorMsg");
        throw Exception(errorMsg); 
      }
    } catch (e) {
      Log.error("Exception joinCampaign", e);
      rethrow;
    }
  }

  Future<bool> deleteCampaign(int campaignId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse("$baseUrl/campaigns/$campaignId"),
        headers: headers,
      );

      if (response.statusCode == 200) return true;
      
      Log.error("Delete Fail: ${response.body}");
      return false;
    } catch (e) {
      Log.error("Exception deleteCampaign", e);
      return false;
    }
  }

  // --- 2. GESTION DU JEU ---

  Future<bool> sendLog(int campaignId, String content, {String type = 'MSG', int resultValue = 0}) async {
    try {
      final headers = await _getHeaders();
      await http.post(
        Uri.parse("$baseUrl/campaigns/$campaignId/logs"),
        headers: headers,
        body: jsonEncode({
          "content": content,
          "type": type,
          "result_value": resultValue
        }),
      );
      return true;
    } catch (e) {
      Log.error("Erreur sendLog", e);
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getLogs(int campaignId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse("$baseUrl/campaigns/$campaignId/logs"),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      return [];
    } catch (e) {
      Log.error("Erreur getLogs", e);
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
      Log.error("Erreur updateSettings", e);
      return false;
    }
  }

  // --- 3. GESTION MEMBRES & PERSOS ---

  Future<List<Map<String, dynamic>>> getMembers(int campaignId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse("$baseUrl/campaigns/$campaignId/members"), 
        headers: headers
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      Log.warning("Erreur getMembers: ${response.body}");
      return [];
    } catch (e) {
      Log.error("Exception getMembers", e);
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
      Log.error("Erreur selectCharacter", e);
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
      Log.error("Erreur updateMemberStat", e);
      return false;
    }
  }
}
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/campaign_model.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/utils/logger_service.dart';

class CampaignRepository {
  final SessionService _sessionService = SessionService();
  final String baseUrl = ApiConfig.baseUrl;

  Future<Map<String, String>> _getHeaders() => _sessionService.authHeaders();

  // --- 1. GESTION DES CAMPAGNES ---

  Future<List<CampaignModel>> getAllCampaigns() async {
    try {
      final headers = await _getHeaders();
      final response =
          await http.get(Uri.parse("$baseUrl/campaigns"), headers: headers);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => CampaignModel.fromJson(json)).toList();
      }
      Log.error(
          "Erreur getAllCampaigns (${response.statusCode})", response.body);
      return [];
    } catch (e) {
      Log.error("Exception getAllCampaigns", e);
      return [];
    }
  }

  Future<CampaignModel?> getCampaign(int campaignId) async {
    try {
      final campaigns = await getAllCampaigns();
      for (final campaign in campaigns) {
        if (campaign.id == campaignId) {
          return campaign;
        }
      }
      return null;
    } catch (e) {
      Log.error("Exception getCampaign", e);
      return null;
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
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return CampaignModel.fromJson(jsonDecode(response.body));
      }
      Log.error(
          "Erreur createCampaign (${response.statusCode})", response.body);
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
      if (response.statusCode >= 200 && response.statusCode < 300) {
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
      final response = await http.delete(
          Uri.parse("$baseUrl/campaigns/$campaignId"),
          headers: headers);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      return false;
    }
  }

  // --- 2. GESTION DU JEU (LOGS & DÉS) ---

  Future<bool> sendLog(int campaignId, String content,
      {String type = 'MSG', int resultValue = 0}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse("$baseUrl/campaigns/$campaignId/logs"),
        headers: headers,
        body: jsonEncode(
            {"content": content, "type": type, "result_value": resultValue}),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
      Log.error("Erreur sendLog (${response.statusCode})", response.body);
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getLogs(int campaignId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
          Uri.parse("$baseUrl/campaigns/$campaignId/logs"),
          headers: headers);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      Log.error("Erreur getLogs (${response.statusCode})", response.body);
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<CampaignModel?> updateSettings(
    int campaignId, {
    bool? allowDice,
    int? statPointCap,
    int? bonusStatPool,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse("$baseUrl/campaigns/$campaignId/settings"),
        headers: headers,
        body: jsonEncode({
          if (allowDice != null) "allow_dice": allowDice,
          if (statPointCap != null) "stat_point_cap": statPointCap,
          if (bonusStatPool != null) "bonus_stat_pool": bonusStatPool,
        }),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        final campaign = data['campaign'];
        if (campaign is Map<String, dynamic>) {
          return CampaignModel.fromJson(campaign);
        }
        return getCampaign(campaignId);
      }
      Log.error(
        "Erreur updateSettings (${response.statusCode})",
        response.body,
      );
      return null;
    } catch (e) {
      Log.error("Exception updateSettings", e);
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getMembers(int campaignId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
          Uri.parse("$baseUrl/campaigns/$campaignId/members"),
          headers: headers);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      Log.error("Erreur getMembers (${response.statusCode})", response.body);
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> selectCharacter(int campaignId, String characterId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse("$baseUrl/campaigns/$campaignId/select-character"),
        headers: headers,
        body: jsonEncode({"character_id": int.tryParse(characterId)}),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? "Erreur selection personnage");
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> finalizeCharacterBuild(int campaignId, String charId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(
            "$baseUrl/campaigns/$campaignId/characters/$charId/finalize-build"),
        headers: headers,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? "Erreur finalisation fiche");
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> updateMemberStat(
      int campaignId, String charId, String key, dynamic value) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse("$baseUrl/campaigns/$campaignId/members/$charId/stats"),
        headers: headers,
        body: jsonEncode({"key": key, "value": value}),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      return false;
    }
  }

  // --- 3. COMBAT TRACKER (LES FONCTIONS MANQUANTES) ---

  Future<Map<String, dynamic>> getCombatDetails(int campaignId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
          Uri.parse("$baseUrl/campaigns/$campaignId/combat"),
          headers: headers);
      if (response.statusCode >= 200 && response.statusCode < 300) {
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
      final response = await http.post(
          Uri.parse("$baseUrl/campaigns/$campaignId/combat/start"),
          headers: headers);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateParticipant(
      int campaignId, int participantId, Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse(
            "$baseUrl/campaigns/$campaignId/combat/participants/$participantId"),
        headers: headers,
        body: jsonEncode(data),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
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
      return response.statusCode >= 200 && response.statusCode < 300;
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
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      return false;
    }
  }

  /// MJ : Ajoute un monstre/PNJ au combat
  Future<bool> addParticipant(
      int campaignId, String name, int hp, int? initiative) async {
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
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      Log.error("Erreur addParticipant", e);
      return false;
    }
  }
}

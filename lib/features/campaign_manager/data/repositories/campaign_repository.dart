import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/campaign_model.dart'; // Assure-toi que ce modèle existe

class CampaignRepository {
  // ⚠️ Mets ici ton URL exacte (sans slash à la fin)
  final String baseUrl = "http://sc2tphk4284.universe.wf/api_jdr";

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id'); // On récupère l'ID stocké au Login
    return {
      "Content-Type": "application/json",
      "x-user-id": userId.toString(), // On l'envoie au serveur pour s'identifier
    };
  }

  Future<List<CampaignModel>> getAllCampaigns() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/campaigns'), headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => CampaignModel.fromJson(json)).toList();
      } else {
        throw Exception("Erreur serveur: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Erreur connexion: $e");
    }
  }

  Future<void> createCampaign(String title) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/campaigns'),
        headers: headers,
        body: jsonEncode({"title": title}),
      );

      if (response.statusCode != 200) {
        throw Exception("Erreur création: ${response.body}");
      }
    } catch (e) {
      throw Exception("Erreur connexion: $e");
    }
  }

  // ... tes autres méthodes (getAllCampaigns, createCampaign) ...

  Future<void> joinCampaign(String code) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/campaigns/join'),
        headers: headers,
        body: jsonEncode({"code": code}),
      );

      if (response.statusCode == 200) {
        return; // Succès
      } else if (response.statusCode == 404) {
        throw Exception("Code invalide : Campagne introuvable.");
      } else if (response.statusCode == 409) {
        throw Exception("Vous êtes déjà membre de cette campagne.");
      } else {
        throw Exception("Erreur serveur : ${response.body}");
      }
    } catch (e) {
      throw Exception("Impossible de rejoindre : $e");
    }
  }

// Récupérer les membres
  Future<List<Map<String, dynamic>>> getCampaignMembers(int campaignId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/campaigns/$campaignId/members'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      } else {
        throw Exception("Erreur serveur: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Erreur membres: $e");
    }
  }

// Récupérer le chat
  Future<List<Map<String, dynamic>>> getCampaignLogs(int campaignId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/campaigns/$campaignId/logs'), headers: headers);

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      } else {
        throw Exception("Erreur logs: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Erreur logs: $e");
    }
  }

  // Envoyer un message/dé
  Future<void> sendLog(int campaignId, String content, String type, int? value) async {
    final headers = await _getHeaders();
    await http.post(
      Uri.parse('$baseUrl/campaigns/$campaignId/logs'),
      headers: headers,
      body: jsonEncode({
        "content": content,
        "type": type,
        "result_value": value
      }),
    );
  }

// Mettre à jour les options (MJ)
  Future<void> updateSettings(int campaignId, bool allowDice) async {
    final headers = await _getHeaders();
    await http.patch(
      Uri.parse('$baseUrl/campaigns/$campaignId/settings'),
      headers: headers,
      body: jsonEncode({"allow_dice": allowDice}),
    );
  }






}
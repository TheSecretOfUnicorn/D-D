import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/campaign_model.dart';

class CampaignRepository {
  // ⚠️ ADRESSE DU SERVEUR :
  // Utilisez "http://10.0.2.2:3000" pour l'émulateur Android.
  // Utilisez "http://localhost:3000" pour Web ou iOS Simulateur.
  // Utilisez l'IP de votre machine (ex: "http://192.168.1.15:3000") pour un vrai téléphone.
  final String baseUrl = "http://sc2tphk4284.universe.wf/api_jdr"; // Attention au préfixe /api_jdr si défini dans app.js

  // --- 1. GESTION DES CAMPAGNES ---

  /// Récupère la liste des campagnes de l'utilisateur
  Future<List<CampaignModel>> getAllCampaigns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.get('user_id')?.toString(); // Conversion sécurisée

      if (userId == null) return [];

      final response = await http.get(
        Uri.parse("$baseUrl/campaigns"),
        headers: {'x-user-id': userId},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => CampaignModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print("Erreur getAllCampaigns: $e");
      return [];
    }
  }

  /// Crée une nouvelle campagne (GM)
  Future<CampaignModel?> createCampaign(String title) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.get('user_id')?.toString();

      if (userId == null) return null;

      final response = await http.post(
        Uri.parse("$baseUrl/campaigns"),
        headers: {
          'Content-Type': 'application/json',
          'x-user-id': userId,
        },
        body: jsonEncode({"title": title}),
      );

      if (response.statusCode == 200) {
        return CampaignModel.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print("Erreur createCampaign: $e");
      throw Exception("Impossible de créer la campagne");
    }
  }

  /// Rejoint une campagne existante via un code
  Future<CampaignModel?> joinCampaign(String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.get('user_id')?.toString();

      if (userId == null) return null;

      final response = await http.post(
        Uri.parse("$baseUrl/campaigns/join"),
        headers: {
          'Content-Type': 'application/json',
          'x-user-id': userId,
        },
        body: jsonEncode({"code": code}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // L'API renvoie souvent { success: true, campaign: {...} }
        return CampaignModel.fromJson(data['campaign']);
      } else {
        final error = jsonDecode(response.body)['error'] ?? "Erreur inconnue";
        throw Exception(error);
      }
    } catch (e) {
      print("Erreur joinCampaign: $e");
      rethrow;
    }
  }

  /// Supprime une campagne (GM Uniquement)
  Future<bool> deleteCampaign(int campaignId) async {
    final url = "$baseUrl/campaigns/$campaignId";
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 👇 CORRECTION CRITIQUE : .get() + .toString() pour éviter l'erreur de type
      final userId = prefs.get('user_id')?.toString();

      if (userId == null) return false;

      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'x-user-id': userId,
        },
      );

      print("🗑️ DELETE STATUS: ${response.statusCode}"); // Debug

      return response.statusCode == 200;
    } catch (e) {
      print("Erreur deleteCampaign: $e");
      return false;
    }
  }

  // --- 2. GESTION DU JEU (LOGS & DÉS) ---

  /// Envoie un message ou un résultat de dé
  Future<bool> sendLog(int campaignId, String content, {String type = 'MSG', int resultValue = 0}) async {
    final url = "$baseUrl/campaigns/$campaignId/logs";
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.get('user_id')?.toString();

      if (userId == null) return false;

      await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'x-user-id': userId
        },
        body: jsonEncode({
          "content": content,
          "type": type,
          "result_value": resultValue
        }),
      );
      return true;
    } catch (e) {
      print("Erreur sendLog: $e");
      return false;
    }
  }

  /// Récupère l'historique du chat et des dés
  Future<List<Map<String, dynamic>>> getLogs(int campaignId) async {
    final url = "$baseUrl/campaigns/$campaignId/logs";
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.get('user_id')?.toString();

      if (userId == null) return [];

      final response = await http.get(
        Uri.parse(url),
        headers: {'x-user-id': userId},
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      } else {
        // 👇 ICI : ON AFFICHE L'ERREUR RÉELLE DU SERVEUR
        print("🚨 ERREUR GET LOGS (${response.statusCode}): ${response.body}");
        return [];
      }
    } catch (e) {
      print("🚨 ERREUR CRITIQUE GET LOGS: $e");
      return [];
    }
  }

  /// Met à jour les paramètres de la campagne (ex: Allow Dice)
  Future<bool> updateSettings(int campaignId, bool allowDice) async {
    final url = "$baseUrl/campaigns/$campaignId/settings";
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.get('user_id')?.toString();

      if (userId == null) return false;

      final response = await http.patch(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'x-user-id': userId
        },
        body: jsonEncode({"allow_dice": allowDice}),
      );
      if (response.statusCode == 200) {
        return true;
      } else {
        // 👇 ICI : ON AFFICHE POURQUOI CA BLOQUE
        print("🚨 ERREUR SETTINGS (${response.statusCode}): ${response.body}");
        return false;
      }
    } catch (e) {
      print("🚨 ERREUR CRITIQUE SETTINGS: $e");
      return false;
    }
  }
// --- 3. GESTION DES MEMBRES & PERSONNAGES (Code Manquant) ---

  /// Récupère la liste des membres avec leurs personnages
  Future<List<Map<String, dynamic>>> getMembers(int campaignId) async {
    final url = "$baseUrl/campaigns/$campaignId/members";
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.get('user_id')?.toString(); // Toujours sécuriser l'ID
      if (userId == null) return [];

      final response = await http.get(
        Uri.parse(url), 
        headers: {'x-user-id': userId}
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      print("🚨 ERREUR GET MEMBERS: ${response.body}"); // Debug
      return [];
    } catch (e) {
      print("Erreur getMembers: $e");
      return [];
    }
  }

  /// Sélectionne le personnage actif pour cette campagne
  Future<bool> selectCharacter(int campaignId, String characterId) async {
    final url = "$baseUrl/campaigns/$campaignId/select-character";
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.get('user_id')?.toString();
      if (userId == null) return false;

      await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json', 'x-user-id': userId},
        body: jsonEncode({"character_id": int.tryParse(characterId)}), // Conversion String -> Int
      );
      return true;
    } catch (e) {
      print("Erreur selectCharacter: $e");
      return false;
    }
  }

/// GM : Met à jour une stat d'un joueur (ex: PV)
  Future<bool> updateMemberStat(int campaignId, String charId, String key, dynamic value) async {
    final url = "$baseUrl/campaigns/$campaignId/members/$charId/stats";
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.get('user_id')?.toString();
      if (userId == null) return false;

      await http.patch(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json', 'x-user-id': userId},
        body: jsonEncode({"key": key, "value": value}),
      );
      return true;
    } catch (e) {
      print("Erreur updateMemberStat: $e");
      return false;
    }
  }

  
}
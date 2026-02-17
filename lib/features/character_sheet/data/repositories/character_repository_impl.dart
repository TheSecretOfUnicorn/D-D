import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/character_model.dart';
import 'package:flutter/foundation.dart'; // Pour debugPrint

class CharacterRepositoryImpl {
  // ⚠️ Vérifiez que cette URL est correcte !
  final String baseUrl = "http://sc2tphk4284.universe.wf/api_jdr"; 

  // Récupération des headers avec sécurité
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    // On essaie 'user_id' (format habituel) et 'userId' (au cas où)
    final userId = prefs.get('user_id') ?? prefs.get('userId'); 
    
    if (userId == null) {
      debugPrint("⚠️ ALERTE : Aucun User ID trouvé dans les préférences !");
    }

    return {
      'Content-Type': 'application/json',
      'x-user-id': userId?.toString() ?? '',
    };
  }

  // Sauvegarder (Création ou Mise à jour)
  Future<void> saveCharacter(CharacterModel char) async {
    final headers = await _getHeaders();
    debugPrint("📤 Sauvegarde Perso: ${char.name} (ID: ${char.id})");

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/characters'),
        headers: headers,
        body: jsonEncode(char.toJson()),
      );

      if (response.statusCode != 200) {
        throw Exception('Erreur serveur (${response.statusCode}): ${response.body}');
      }
      debugPrint("✅ Perso sauvegardé avec succès !");
    } catch (e) {
      debugPrint("❌ Erreur saveCharacter: $e");
      rethrow; // Renvoie l'erreur pour l'afficher dans l'UI
    }
  }

  // Récupérer tous les personnages
  Future<List<CharacterModel>> getAllCharacters(String charId) async {
    final headers = await _getHeaders();
    try {
      final response = await http.get(Uri.parse('$baseUrl/characters'), headers: headers);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => CharacterModel.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint("❌ Erreur getAllCharacters: $e");
    }
    return [];
  }
  
  // Récupérer un personnage par ID
  Future<CharacterModel?> getCharacter(String id) async {
    final chars = await getAllCharacters("");
    try {
      return chars.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  // Supprimer
  Future<void> deleteCharacter(String id) async {
    final headers = await _getHeaders();
    await http.delete(Uri.parse('$baseUrl/characters/$id'), headers: headers);
  }
}
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; // Pour debugPrint
import '../models/character_model.dart';

class CharacterRepositoryImpl {
  // Vérifiez bien l'URL (sans slash à la fin)
  final String baseUrl = "http://sc2tphk4284.universe.wf/api_jdr";

  // 👇 C'EST ICI QUE SE TROUVAIT L'ERREUR "TypeError: 25"
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    
    // On récupère l'ID (qui peut être int ou String selon comment il a été sauvé)
    final dynamic rawId = prefs.get('userId') ?? prefs.get('user_id');
    
    // ✅ CORRECTION : On force la conversion en String. 
    // Si c'est 25 (int), ça devient "25" (String).
    final String userId = rawId?.toString() ?? "";

    if (userId.isEmpty) {
      debugPrint("⚠️ ALERTE : Aucun User ID trouvé (Non connecté ?)");
    }

    return {
      "Content-Type": "application/json",
      "x-user-id": userId, // Maintenant c'est bien une String !
    };
  }

  // 1. Charger TOUS les personnages
  Future<List<CharacterModel>> getAllCharacters() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/characters'), headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        // On utilise la méthode de votre modèle (fromMap ou fromJson)
        // Assurez-vous que votre modèle gère bien la conversion si l'ID est un int dans le JSON
        return jsonList.map((json) {
            // Petite sécurité supplémentaire au cas où votre modèle ne convertit pas
            if (json['id'] is int) json['id'] = json['id'].toString();
            if (json['user_id'] is int) json['user_id'] = json['user_id'].toString();
            return CharacterModel.fromMap(json);
        }).toList();
      }
    } catch (e) {
      debugPrint("❌ Erreur getAllCharacters: $e");
    }
    return [];
  }

  // 2. Charger UN personnage par ID
  Future<CharacterModel?> getCharacter(String id) async {
    final all = await getAllCharacters();
    try {
      return all.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  // 3. Sauvegarder
  Future<void> saveCharacter(CharacterModel character) async {
    try {
      final headers = await _getHeaders();
      // toMap ou toJson selon votre modèle
      final body = jsonEncode(character.toMap());

      debugPrint("📤 Sauvegarde : ${character.name}");

      final response = await http.post(
        Uri.parse('$baseUrl/characters'),
        headers: headers,
        body: body,
      );

      if (response.statusCode != 200) {
        throw Exception("Erreur serveur (${response.statusCode}): ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ Erreur saveCharacter: $e");
      rethrow;
    }
  }

  // 4. Supprimer
  Future<void> deleteCharacter(String id) async {
    try {
      final headers = await _getHeaders();
      await http.delete(Uri.parse('$baseUrl/characters/$id'), headers: headers);
    } catch (e) {
      throw Exception("Erreur suppression: $e");
    }
  }
}
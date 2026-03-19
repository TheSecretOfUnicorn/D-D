import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // Pour debugPrint
import '../models/character_model.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/services/session_service.dart';

class CharacterRepositoryImpl {
  final SessionService _sessionService = SessionService();
  final String baseUrl = ApiConfig.baseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final headers = await _sessionService.authHeaders(requireUser: false);
    if (!headers.containsKey('x-user-id')) {
      debugPrint("⚠️ ALERTE : Aucun User ID trouvé (Non connecté ?)");
    }
    return headers;
  }

  // 1. Charger TOUS les personnages
  Future<List<CharacterModel>> getAllCharacters() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/characters'), headers: headers);

      if (response.statusCode >= 200 && response.statusCode < 300) {
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
  Future<CharacterModel> saveCharacter(CharacterModel character) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode(character.toMap());

      debugPrint("📤 Sauvegarde : ${character.name}");

      http.Response response = await http.post(
        Uri.parse('$baseUrl/characters'),
        headers: headers,
        body: body,
      );

      if (character.id.startsWith('local_') && response.statusCode >= 500) {
        response = await http.post(
          Uri.parse('$baseUrl/characters'),
          headers: headers,
          body: jsonEncode({
            'name': character.name,
            'stats': character.stats,
            if (character.imagePath != null && character.imagePath!.isNotEmpty)
              'imagePath': character.imagePath,
          }),
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception("Erreur serveur (${response.statusCode}): ${response.body}");
      }
      if (response.body.isEmpty) {
        return character;
      }
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('success') && decoded.containsKey('id')) {
          return character.copyWith(
            id: decoded['id'].toString(),
            name: character.name,
            imagePath: character.imagePath,
            stats: character.stats,
          );
        }
        return CharacterModel.fromMap(decoded);
      }
      if (decoded is int || decoded is String) {
        return character.copyWith(
          id: decoded.toString(),
          name: character.name,
          imagePath: character.imagePath,
          stats: character.stats,
        );
      }
      return character;
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

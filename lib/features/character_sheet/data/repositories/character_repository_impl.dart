import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/character_model.dart';
import '../../../../core/utils/logger_service.dart';


class CharacterRepositoryImpl {
  // ⚠️ Ton URL Serveur (sans slash à la fin)
  final String baseUrl = "http://sc2tphk4284.universe.wf/api_jdr";
  
  get log => Log;

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    return {
      "Content-Type": "application/json",
      "x-user-id": userId.toString(),
    };
  }

  // Charger tous les personnages du Cloud
  Future<List<CharacterModel>> getAllCharacters() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/characters'), headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => CharacterModel.fromMap(json)).toList();
      } else {
        // Si erreur ou liste vide, on renvoie une liste vide pour ne pas crasher
        return [];
      }
    } catch (e) {
      log.error("Erreur getAllCharacters", e);
      return [];
    }
  }

  // Sauvegarder (Créer ou Update)
  Future<void> saveCharacter(CharacterModel character) async {
    try {
      final headers = await _getHeaders();
      
      // On convertit le perso en JSON
      final body = jsonEncode(character.toMap());

      final response = await http.post(
        Uri.parse('$baseUrl/characters'),
        headers: headers,
        body: body,
      );

      if (response.statusCode != 200) {
        throw Exception("Erreur sauvegarde: ${response.body}");
      }
    } catch (e) {
      throw Exception("Impossible de sauvegarder: $e");
    }
  }

  // Supprimer
  Future<void> deleteCharacter(String id) async {
    try {
      final headers = await _getHeaders();
      await http.delete(
        Uri.parse('$baseUrl/characters/$id'),
        headers: headers,
      );
    } catch (e) {
      throw Exception("Erreur suppression: $e");
    }
  }
}
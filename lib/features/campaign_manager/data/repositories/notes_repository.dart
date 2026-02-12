import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/utils/logger_service.dart';
import '../models/note_model.dart';

class NotesRepository {
  final String baseUrl = "http://sc2tphk4284.universe.wf/api_jdr"; 

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.get('user_id')?.toString();
    return {
      'Content-Type': 'application/json',
      'x-user-id': userId ?? '',
    };
  }

  /// Charger les notes de la campagne
  Future<List<NoteModel>> fetchNotes(int campaignId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse("$baseUrl/campaigns/$campaignId/notes"),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => NoteModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      Log.error("Erreur fetchNotes", e);
      return [];
    }
  }

  /// Créer une note
  Future<bool> createNote(int campaignId, String title, String content, bool isPublic) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse("$baseUrl/campaigns/$campaignId/notes"),
        headers: headers,
        body: jsonEncode({
          "title": title,
          "content": content,
          "is_public": isPublic
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      Log.error("Erreur createNote", e);
      return false;
    }
  }

  /// Supprimer une note
  Future<bool> deleteNote(int noteId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse("$baseUrl/notes/$noteId"),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Changer la visibilité (Public/Privé)
  Future<bool> toggleVisibility(int noteId, bool isPublic) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse("$baseUrl/notes/$noteId/share"),
        headers: headers,
        body: jsonEncode({"is_public": isPublic}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
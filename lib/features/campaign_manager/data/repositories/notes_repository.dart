import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note_model.dart';
import '../../../../core/utils/logger_service.dart';

class NotesRepository {
  static const String _storageKey = 'campaign_notes_list';

  /// Sauvegarde toute la liste des notes d'un coup (pour faire simple)
  Future<void> saveNotes(List<NoteModel> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(notes.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  /// Charge toutes les notes
  Future<List<NoteModel>> loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encoded = prefs.getString(_storageKey);
    
    if (encoded == null) return [];

    try {
      final List<dynamic> list = jsonDecode(encoded);
      return list.map((e) => NoteModel.fromJson(e)).toList();
    } catch (e) {

      Log.error("Exception loadNotes", e);
      return [];
    }
  }
}
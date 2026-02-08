import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/character_model.dart';

class CharacterRepositoryImpl {
  static const String _indexKey = 'character_index_list'; // Liste des IDs
  static const String _prefix = 'char_'; // Préfixe pour chaque fichier

  /// Sauvegarde un personnage et met à jour l'index
  Future<void> saveCharacter(CharacterModel character) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Sauvegarder les données du perso
    final jsonString = jsonEncode(character.toJson());
    await prefs.setString('$_prefix${character.id}', jsonString);

    // 2. Mettre à jour la liste des personnages existants
    final List<String> indexList = prefs.getStringList(_indexKey) ?? [];
    if (!indexList.contains(character.id)) {
      indexList.add(character.id);
      await prefs.setStringList(_indexKey, indexList);
    }
  }

  /// Récupère TOUS les personnages (pour le dashboard)
  Future<List<CharacterModel>> getAllCharacters() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> indexList = prefs.getStringList(_indexKey) ?? [];
    
    List<CharacterModel> allChars = [];

    for (String id in indexList) {
      final String? jsonString = prefs.getString('$_prefix$id');
      if (jsonString != null) {
        try {
          final jsonMap = jsonDecode(jsonString);
          allChars.add(CharacterModel.fromJson(jsonMap));
        } catch (e) {
          print("Fichier corrompu pour l'ID $id : $e");
        }
      }
    }
    return allChars;
  }

  /// Supprime un personnage
  Future<void> deleteCharacter(String id) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Supprimer le fichier
    await prefs.remove('$_prefix$id');
    
    // 2. Retirer de l'index
    final List<String> indexList = prefs.getStringList(_indexKey) ?? [];
    indexList.remove(id);
    await prefs.setStringList(_indexKey, indexList);
  }
}
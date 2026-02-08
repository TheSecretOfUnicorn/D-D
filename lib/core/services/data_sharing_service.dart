import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart' show Share;
import '../../features/character_sheet/data/models/character_model.dart';

// Vérifiez bien cette ligne : class DataSharingService
class DataSharingService {
  
  String exportCharacter(CharacterModel char) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(char.toJson());
  }

  Future<void> shareCharacter(CharacterModel char) async {
    final jsonString = exportCharacter(char);
    await Share.share(jsonString, subject: 'Fiche Perso : ${char.name}');
  }

  Future<void> copyToClipboard(CharacterModel char) async {
    final jsonString = exportCharacter(char);
    await Clipboard.setData(ClipboardData(text: jsonString));
  }

  CharacterModel? importCharacter(String jsonString) {
    try {
      final Map<String, dynamic> map = jsonDecode(jsonString);
      if (!map.containsKey('id') || !map.containsKey('stats')) {
        throw Exception("Format invalide");
      }
      return CharacterModel.fromJson(map);
    } catch (e) {
      print("Erreur d'import : $e");
      return null;
    }
  }
}
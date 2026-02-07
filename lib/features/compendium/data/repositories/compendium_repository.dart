import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/compendium_item_model.dart';

class CompendiumRepository {
  
  /// Charge les sorts (et plus tard les objets/monstres)
  Future<List<CompendiumItemModel>> loadSpells() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/data/spells_srd.json');
      final List<dynamic> jsonList = jsonDecode(jsonString);
      
      return jsonList.map((e) => CompendiumItemModel.fromJson(e)).toList();
    } catch (e) {
      print("Erreur chargement Compendium: $e");
      return [];
    }
  }
}
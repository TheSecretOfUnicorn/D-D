import 'dart:convert'; // Pour jsonDecode
import 'package:flutter/services.dart'; // Pour rootBundle
import '../models/rule_system_model.dart';
import '/core/utils/logger_service.dart';
class RulesRepositoryImpl {
  
  /// Charge le système de règles par défaut depuis les assets
  Future<RuleSystemModel> loadDefaultRules() async {
    try {
      // 1. Lire le fichier texte
      final String jsonString = await rootBundle.loadString('assets/rules/dnd5e_core.json');
      
      // 2. Décoder le JSON en Map
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      
      // 3. Convertir le Map en Objet Dart
      return RuleSystemModel.fromJson(jsonMap);
      
    } catch (e) {
      // En prod, on utiliserait un Logger ici
      Log.error("Erreur lors du chargement des règles", e);
      rethrow; 
    }
  }
}

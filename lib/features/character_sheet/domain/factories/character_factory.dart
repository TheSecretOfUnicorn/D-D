import 'package:uuid/uuid.dart'; // Pensez à ajouter 'uuid' dans pubspec.yaml
import '../../../rules_engine/data/models/rule_system_model.dart';
import '../../data/models/character_model.dart';

class CharacterFactory {
  // Générateur d'ID unique
  final _uuid = const Uuid();

  /// Crée un personnage vierge basé sur les règles fournies
  CharacterModel createBlankCharacter(RuleSystemModel rules) {
    final Map<String, dynamic> initialStats = {};

    // On parcourt toutes les définitions de stats du JSON
    for (var def in rules.statDefinitions) {
      // On initialise la valeur par défaut
      // Si min existe, on prend min, sinon 0 pour un int, "" pour un string
      dynamic defaultValue;
      
      if (def.type == 'integer') {
        defaultValue = def.min ?? 10; // Valeur arbitraire moyenne par défaut
      } else if (def.type == 'boolean') {
        defaultValue = false;
      } else {
        defaultValue = "";
      }

      initialStats[def.id] = defaultValue;
    }

    return CharacterModel(
      id: _uuid.v4(), // ID unique aléatoire
      name: "Nouveau Personnage",
      stats: initialStats,
    );
  }
}
import '../../../character_sheet/data/models/character_model.dart';

class CombatantModel {
  final String id;          // ID unique pour le combat (ex: Gobelin #1, Gobelin #2)
  final String name;        // Nom affiché
  final int initiative;     // Le score du dé
  final CharacterModel? character; // Lien optionnel vers une vraie fiche (si c'est un PJ)
  
  // État du tour
  bool hasPlayed;

  CombatantModel({
    required this.id,
    required this.name,
    required this.initiative,
    this.character,
    this.hasPlayed = false,
  });

  // Pour cloner et modifier facilement (Immutabilité)
  CombatantModel copyWith({bool? hasPlayed, int? initiative}) {
    return CombatantModel(
      id: id,
      name: name,
      character: character,
      initiative: initiative ?? this.initiative,
      hasPlayed: hasPlayed ?? this.hasPlayed,
    );
  }
}
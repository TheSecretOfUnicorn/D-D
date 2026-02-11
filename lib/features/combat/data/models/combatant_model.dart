class CombatantModel {
  final int id;             // ID unique en base de données (table combat_participants)
  final String name;
  final int initiative;
  final int hpCurrent;
  final int hpMax;
  final int ac;             // Classe d'armure
  final bool isNpc;         // Est-ce un monstre/PNJ ?
  final int? characterId;   // Lien vers la fiche perso (si c'est un joueur)

  CombatantModel({
    required this.id,
    required this.name,
    required this.initiative,
    required this.hpCurrent,
    required this.hpMax,
    required this.ac,
    required this.isNpc,
    this.characterId,
  });

  factory CombatantModel.fromJson(Map<String, dynamic> json) {
    return CombatantModel(
      id: json['id'],
      name: json['name'] ?? "Inconnu",
      initiative: json['initiative'] ?? 0,
      hpCurrent: json['hp_current'] ?? 10,
      hpMax: json['hp_max'] ?? 10,
      ac: json['ac'] ?? 10,
      isNpc: json['is_npc'] ?? false,
      characterId: json['character_id'],
    );
  }
}
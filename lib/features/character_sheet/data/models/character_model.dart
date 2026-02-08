class CharacterModel {
  final String id;
  String name; // Non final pour pouvoir le modifier
  final Map<String, dynamic> stats;
  final String? imagePath;

  CharacterModel({
    required this.id,
    required this.name,
    required this.stats,
    this.imagePath,
  });

  /// Copie immuable pour les modifications (Image, Nom, Stats)
  CharacterModel copyWith({
    String? id,
    String? name,
    Map<String, dynamic>? stats,
    String? imagePath,
  }) {
    return CharacterModel(
      id: id ?? this.id,
      name: name ?? this.name,
      stats: stats ?? Map<String, dynamic>.from(this.stats),
      imagePath: imagePath ?? this.imagePath,
    );
  }

  /// Récupère une stat
  dynamic getStat(String statId) => stats[statId];

  /// Modifie une stat
  void setStat(String statId, dynamic value) {
    stats[statId] = value;
  }

  /// Sérialisation JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name, // Sauvegarde du nom racine
    'image_path': imagePath,
    'stats': stats,
  };

  /// Désérialisation JSON
  factory CharacterModel.fromJson(Map<String, dynamic> json) {
    return CharacterModel(
      id: json['id'],
      // Logique robuste : Nom racine > Nom dans stats > "Inconnu"
      name: json['name'] ?? json['stats']['name'] ?? 'Inconnu',
      imagePath: json['image_path'],
      stats: Map<String, dynamic>.from(json['stats'] ?? {}),
    );
  }
}
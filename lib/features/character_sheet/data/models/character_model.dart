class CharacterModel {
  final String id;
  String name;
  
  /// Le cœur du système : on stocke les valeurs sous forme de Map.
  /// Clé = ID de la stat (ex: "str")
  /// Valeur = La valeur réelle (ex: 18)
  final Map<String, dynamic> stats;
  final String? imagePath;

  CharacterModel({
    required this.id,
    required this.name,
    required this.stats,
    this.imagePath,

  });
  // Copie immuable
  CharacterModel copyWith({
    String? name, 
    // ...
    String? imagePath, // Ajoutez-le ici
  }) {
    return CharacterModel(
      id: id,
      name: name ?? this.name,
      // ...
      imagePath: imagePath ?? this.imagePath,
      stats: stats,
    );
  }
  /// Permet de récupérer une valeur de manière sécurisée
  dynamic getStat(String statId) {
    return stats[statId];
  }

  /// Permet de modifier une valeur
  void setStat(String statId, dynamic value) {
    stats[statId] = value;
  }

  // Sérialisation pour sauvegarde future
 // JSON serialization
  Map<String, dynamic> toJson() => {
    'id': id,
    'image_path': imagePath, // Sauvegarde
    'stats': stats,
  };

  factory CharacterModel.fromJson(Map<String, dynamic> json) {
    return CharacterModel(
      id: json['id'],
      imagePath: json['image_path'], // Chargement
      stats: Map<String, dynamic>.from(json['stats']), name: '',
    );
  }
  
  // ... méthodes getStat/setStat inchangées
}

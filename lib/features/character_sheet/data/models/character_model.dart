class CharacterModel {
  String id;
  String name;
  String? imagePath;
  Map<String, dynamic> stats;

  CharacterModel({
    required this.id,
    required this.name,
    this.imagePath,
    required this.stats,
  });

  // --- 🔥 MÉTHODE BLINDÉE (Celle qui corrige ton erreur) 🔥 ---
  
  /// Récupère une stat avec un type forcé (T) et une valeur par défaut OBLIGATOIRE.
  /// Exemple : getStat&int&("Force", 10) -> renverra toujours un int, jamais null.
  T getStat<T>(String key, T defaultValue) {
    // 1. Si la clé n'existe pas ou si la valeur est explicitement null
    if (!stats.containsKey(key) || stats[key] == null) {
      return defaultValue;
    }

    final value = stats[key];

    // 2. Si la valeur est déjà du bon type (ex: c'est bien un int 15)
    if (value is T) {
      return value;
    }

    // 3. Conversion magique : String vers int
    // (Utile si la base de données renvoie "15" en texte au lieu de 15 en nombre)
    if (T == int) {
      if (value is num) return value.toInt() as T; // gère les double (10.0) -> int (10)
      if (value is String) return (int.tryParse(value) ?? defaultValue) as T;
    }

    // 4. Conversion magique : n'importe quoi vers String
    if (T == String) {
      return value.toString() as T;
    }

    // 5. Si on n'arrive pas à convertir, on renvoie la valeur par défaut pour éviter le crash
    return defaultValue;
  }

  /// Définit une stat
  void setStat(String key, dynamic value) {
    stats[key] = value;
  }

  // --- SERIALIZATION JSON ---

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'imagePath': imagePath,
      'stats': stats,
    };
  }

  Map<String, dynamic> toJson() => toMap();

  factory CharacterModel.fromMap(Map<String, dynamic> map) {
    return CharacterModel(
      id: map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: map['name'] ?? 'Nouveau Personnage',
      imagePath: map['imagePath'],
      stats: map['stats'] != null ? Map<String, dynamic>.from(map['stats']) : {},
    );
  }

  factory CharacterModel.fromJson(Map<String, dynamic> json) => CharacterModel.fromMap(json);
}
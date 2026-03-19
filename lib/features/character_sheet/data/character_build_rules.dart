class CharacterBuildRules {
  static const List<int> standardArray = [15, 14, 13, 12, 10, 8];

  static const List<String> supportedRaces = [
    'Humain',
    'Elfe',
    'Nain',
    'Halfelin',
    'Demi-orc',
    'Tieffelin',
  ];

  static const Map<String, List<String>> classStatPriority = {
    'Guerrier': ['str', 'con', 'dex', 'wis', 'cha', 'int'],
    'Magicien': ['int', 'con', 'dex', 'wis', 'cha', 'str'],
    'Voleur': ['dex', 'con', 'int', 'wis', 'cha', 'str'],
    'Clerc': ['wis', 'con', 'str', 'dex', 'cha', 'int'],
    'Paladin': ['str', 'cha', 'con', 'wis', 'dex', 'int'],
    'Ranger': ['dex', 'wis', 'con', 'str', 'int', 'cha'],
    'Barde': ['cha', 'dex', 'con', 'wis', 'int', 'str'],
    'Druide': ['wis', 'con', 'dex', 'int', 'cha', 'str'],
    'Sorcier': ['cha', 'con', 'dex', 'wis', 'int', 'str'],
    'Moine': ['dex', 'wis', 'con', 'str', 'cha', 'int'],
  };

  static const Map<String, Map<String, int>> raceBonuses = {
    'Humain': {'str': 1, 'dex': 1, 'con': 1, 'int': 1, 'wis': 1, 'cha': 1},
    'Elfe': {'dex': 2, 'int': 1},
    'Nain': {'con': 2, 'wis': 1},
    'Halfelin': {'dex': 2, 'cha': 1},
    'Demi-orc': {'str': 2, 'con': 1},
    'Tieffelin': {'cha': 2, 'int': 1},
  };

  static const Map<String, List<Map<String, dynamic>>> starterItems = {
    'Guerrier': [
      {'name': 'Epee longue', 'qty': 1, 'desc': 'Arme martiale polyvalente.'},
      {'name': 'Bouclier', 'qty': 1, 'desc': 'Ajoute une defense de base.'},
      {'name': 'Armure de mailles', 'qty': 1, 'desc': 'Protection lourde.'},
    ],
    'Magicien': [
      {'name': 'Baton arcanique', 'qty': 1, 'desc': 'Focus de sort.'},
      {'name': 'Sacoche de composants', 'qty': 1, 'desc': 'Materiaux usuels.'},
      {'name': 'Dague', 'qty': 1, 'desc': 'Arme de secours.'},
    ],
    'Voleur': [
      {'name': 'Rapiere', 'qty': 1, 'desc': 'Arme precise.'},
      {'name': 'Outils de voleur', 'qty': 1, 'desc': 'Crochetage et sabotage.'},
      {'name': 'Arc court', 'qty': 1, 'desc': 'Arme legere a distance.'},
    ],
    'Clerc': [
      {'name': 'Masse', 'qty': 1, 'desc': 'Arme simple consacree.'},
      {'name': 'Symbole sacre', 'qty': 1, 'desc': 'Canalise la magie divine.'},
      {'name': 'Bouclier', 'qty': 1, 'desc': 'Protection de front.'},
    ],
  };

  static const Map<String, List<Map<String, dynamic>>> starterSpells = {
    'Magicien': [
      {'name': 'Projectile magique', 'level': 1},
      {'name': 'Bouclier', 'level': 1},
      {'name': 'Trait de feu', 'level': 0},
    ],
    'Clerc': [
      {'name': 'Soin', 'level': 1},
      {'name': 'Mot de guerison', 'level': 1},
      {'name': 'Flamme sacree', 'level': 0},
    ],
    'Barde': [
      {'name': 'Moquerie cruelle', 'level': 0},
      {'name': 'Mot de guerison', 'level': 1},
    ],
    'Druide': [
      {'name': 'Gourdin magique', 'level': 0},
      {'name': 'Baies nourricieres', 'level': 1},
    ],
    'Sorcier': [
      {'name': 'Rayon de givre', 'level': 0},
      {'name': 'Projectiles magiques', 'level': 1},
    ],
  };

  static Map<String, int> buildStats({
    required List<String> statIds,
    required String characterClass,
    required String race,
  }) {
    final normalizedStats = statIds.isEmpty
        ? const ['str', 'dex', 'con', 'int', 'wis', 'cha']
        : statIds;
    final priority = classStatPriority[characterClass] ?? normalizedStats;
    final assigned = <String, int>{
      for (final statId in normalizedStats) statId: 10
    };

    for (var i = 0; i < priority.length && i < standardArray.length; i++) {
      final statId = priority[i];
      if (assigned.containsKey(statId)) {
        assigned[statId] = standardArray[i];
      }
    }

    final bonuses = raceBonuses[race] ?? const <String, int>{};
    for (final entry in bonuses.entries) {
      if (assigned.containsKey(entry.key)) {
        assigned[entry.key] = assigned[entry.key]! + entry.value;
      }
    }

    return assigned;
  }

  static List<Map<String, dynamic>> buildStarterInventory(
      String characterClass) {
    final items =
        starterItems[characterClass] ?? const <Map<String, dynamic>>[];
    return items
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  static List<Map<String, dynamic>> buildStarterSpellbook(
      String characterClass) {
    final spells =
        starterSpells[characterClass] ?? const <Map<String, dynamic>>[];
    return spells
        .map((spell) => Map<String, dynamic>.from(spell))
        .toList(growable: false);
  }

  static Map<String, int> racePreview(String race) {
    return Map<String, int>.from(raceBonuses[race] ?? const <String, int>{});
  }
}

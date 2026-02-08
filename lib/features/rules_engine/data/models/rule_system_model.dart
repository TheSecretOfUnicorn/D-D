class RuleSystemModel {
  final String systemId;
  final String systemName;
  final String version;
  
  final List<StatDefinition> statDefinitions;
  final LayoutDefinition? layout;
  final Map<String, List<DataDefinition>> dataDefinitions;
  final Map<String, List<Map<String, dynamic>>> library;

  RuleSystemModel({
    required this.systemId,
    required this.systemName,
    required this.version,
    required this.statDefinitions,
    required this.dataDefinitions,
    this.layout,
    this.library = const {},
  });

  // --- 1. Pour traduire "str" en "Force" ---
  String getStatName(String id) {
    try {
      final def = statDefinitions.firstWhere((s) => s.id == id);
      return def.name; // Retourne "Force"
    } catch (e) {
      return id.toUpperCase(); // Fallback si non trouvé
    }
  }

  // --- 2. Pour récupérer les classes (Dropdown) ---
  List<String> get classes {
    if (library.containsKey('classes')) {
      return library['classes']!.map((e) => e['name'].toString()).toList();
    }
    return ["Guerrier", "Magicien", "Voleur", "Clerc"];
  }

  // --- 3. FILTRE AMÉLIORÉ (Exclut Inventaire & Sorts) ---
  static const List<String> _excludedStats = [
    // Infos Textuelles
    'name', 'bio', 'class', 'race', 'background', 'alignment', 'description',
    // Progression & Combat (affichés ailleurs)
    'level', 'xp', 'hp', 'hp_current', 'hp_max', 'ac', 'armor_class', 'speed', 'initiative', 'proficiency_bonus',
    // Inventaire & Sorts (ce ne sont pas des stats chiffrées simples)
    'inventory', 'spells', 'equipment', 'gold', 'currency', 'features', 'traits'
  ];

  List<String> get stats {
    return statDefinitions
        .where((def) => !_excludedStats.contains(def.id))
        .map((e) => e.id)
        .toList();
  }

  factory RuleSystemModel.fromJson(Map<String, dynamic> json) {
    // ... (Le parsing reste identique à avant) ...
    Map<String, List<Map<String, dynamic>>> lib = {};
    if (json['library'] != null) {
      (json['library'] as Map<String, dynamic>).forEach((key, value) {
        if (value is List) {
           lib[key] = List<Map<String, dynamic>>.from(value.map((e) => Map<String, dynamic>.from(e)));
        }
      });
    }

    Map<String, List<DataDefinition>> dataDefs = {};
    if (json['data_definitions'] != null) {
      (json['data_definitions'] as Map<String, dynamic>).forEach((key, value) {
         if (value is List) {
            dataDefs[key] = value.map((e) => DataDefinition.fromJson(e)).toList();
         }
      });
    }

    List<StatDefinition> stats = [];
    if (json['stat_definitions'] != null) {
       stats = (json['stat_definitions'] as List)
          .map((e) => StatDefinition.fromJson(e))
          .toList();
    }

    return RuleSystemModel(
      systemId: json['system_id'] ?? 'unknown',
      systemName: json['system_name'] ?? 'Unknown System',
      version: json['version'] ?? '1.0',
      statDefinitions: stats,
      dataDefinitions: dataDefs,
      layout: json['layout'] != null ? LayoutDefinition.fromJson(json['layout']) : null,
      library: lib,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'system_id': systemId,
      'system_name': systemName,
      'version': version,
      'stat_definitions': statDefinitions.map((e) => e.toJson()).toList(),
    };
  }
}

// ... (Garde les classes StatDefinition, DataDefinition, etc. en bas) ...
class StatDefinition {
  final String id;
  final String name;
  final String type; 
  final int? min;
  final int? max;
  final String? iconAsset;
  final String? dataRef; 

  StatDefinition({
    required this.id,
    required this.name,
    required this.type,
    this.min,
    this.max,
    this.iconAsset,
    this.dataRef,
  });

  factory StatDefinition.fromJson(Map<String, dynamic> json) {
    return StatDefinition(
      id: json['id'] ?? 'unknown',
      name: json['name'] ?? 'Unnamed',
      type: json['type'] ?? 'string',
      min: json['min'],
      max: json['max'],
      iconAsset: json['icon_asset'],
      dataRef: json['data_ref'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'min': min,
    'max': max,
    'icon_asset': iconAsset,
    'data_ref': dataRef,
  };
}
// Ajoute DataDefinition, LayoutDefinition, SectionDefinition si tu ne les as plus sous la main
class DataDefinition {
  final String id;
  final String name;
  final String type;
  final int? min;
  DataDefinition({required this.id, required this.name, required this.type, this.min});
  factory DataDefinition.fromJson(Map<String, dynamic> json) => DataDefinition(id: json['id'], name: json['name'], type: json['type'], min: json['min']);
}
class LayoutDefinition {
  final List<String> tabs;
  final List<SectionDefinition> sections;
  LayoutDefinition({required this.tabs, required this.sections});
  factory LayoutDefinition.fromJson(Map<String, dynamic> json) => LayoutDefinition(tabs: List<String>.from(json['tabs'] ?? []), sections: (json['sections'] as List<dynamic>?)?.map((e) => SectionDefinition.fromJson(e)).toList() ?? []);
}
class SectionDefinition {
  final String tab; final String title; final List<String> contains;
  SectionDefinition({required this.tab, required this.title, required this.contains});
  factory SectionDefinition.fromJson(Map<String, dynamic> json) => SectionDefinition(tab: json['tab'] ?? "General", title: json['title'] ?? "", contains: List<String>.from(json['contains'] ?? []));
}
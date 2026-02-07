// lib/features/rules_engine/data/models/rule_system_model.dart

/// Ce modèle représente l'intégralité d'un fichier de règles (ex: dnd5e.json)
class RuleSystemModel {
  final String systemId;
  final String systemName;
  final String version;
  final List<StatDefinitionModel> statDefinitions;
  final LayoutModel? layout;
  final Map<String, List<StatDefinitionModel>> dataDefinitions;


  RuleSystemModel({
    required this.systemId,
    required this.systemName,
    required this.version,
    required this.statDefinitions,
    required this.dataDefinitions,
    this.layout,
  });

  /// Factory : Construit l'objet depuis un Map (JSON décodé)
  factory RuleSystemModel.fromJson(Map<String, dynamic> json) {
    final Map<String, List<StatDefinitionModel>> parsedDefs = {};
    if (json['data_definitions'] != null) {
      (json['data_definitions'] as Map<String, dynamic>).forEach((key, value) {
        parsedDefs[key] = (value as List)
            .map((e) => StatDefinitionModel.fromJson(e))
            .toList();
      });
    }
    return RuleSystemModel(
      systemId: json['system_id'] ?? 'unknown_system',
      systemName: json['system_name'] ?? 'Unnamed System',
      version: json['version'] ?? '0.0.0',
      statDefinitions: (json['stat_definitions'] as List<dynamic>?)
              ?.map((e) => StatDefinitionModel.fromJson(e))
              .toList() ??
          [],
      layout: json['layout'] != null 
          ? LayoutModel.fromJson(json['layout']) 
          : null   ,
      dataDefinitions: parsedDefs,
    );
  }

  /// Convertit l'objet en JSON (utile pour l'export plus tard)
  Map<String, dynamic> toJson() {
    return {
      'system_id': systemId,
      'system_name': systemName,
      'version': version,
      'stat_definitions': statDefinitions.map((e) => e.toJson()).toList(),
    };
  }
}

/// Ce modèle définit une statistique unique (ex: "Force" ou "PV")
class StatDefinitionModel {
  final String id;
  final String name;
  final String type; // 'integer', 'string', 'boolean'
  final int? min;
  final int? max;
  final String? iconAsset;
  final String? dataRef; // NOUVEAU : Référence au modèle (ex: "item")

  StatDefinitionModel({
    required this.id,
    required this.name,
    required this.type,
    this.min,
    this.max,
    this.iconAsset,
    this.dataRef,
  });

  factory StatDefinitionModel.fromJson(Map<String, dynamic> json) {
    return StatDefinitionModel(
      id: json['id'], // Obligatoire, plantera si absent (c'est voulu)
      name: json['name'] ?? 'Unnamed Stat',
      type: json['type'] ?? 'string',
      min: json['min'],
      max: json['max'],
      iconAsset: json['icon_asset'],
      dataRef: json['data_ref'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'min': min,
      'max': max,
      'icon_asset': iconAsset,
    };
  }
}

class LayoutModel {
  final List<String> tabs;
  final List<SectionModel> sections;

  LayoutModel({required this.tabs, required this.sections});

  factory LayoutModel.fromJson(Map<String, dynamic> json) {
    return LayoutModel(
      tabs: List<String>.from(json['tabs'] ?? []),
      sections: (json['sections'] as List<dynamic>?)
              ?.map((e) => SectionModel.fromJson(e))
              .toList() ?? [],
    );
  }
  
  // Pour la sauvegarde
  Map<String, dynamic> toJson() => {
    'tabs': tabs,
    'sections': sections.map((e) => e.toJson()).toList(),
  };
}

/// Une section regroupe des champs (ex: "Attributs") dans un onglet
class SectionModel {
  final String tab;      // Dans quel onglet ? (ex: "Stats")
  final String title;    // Titre de la section
  final List<String> contains; // Liste des IDs de stats à afficher

  SectionModel({required this.tab, required this.title, required this.contains});

  factory SectionModel.fromJson(Map<String, dynamic> json) {
    return SectionModel(
      tab: json['tab'] ?? "General",
      title: json['title'] ?? "",
      contains: List<String>.from(json['contains'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    'tab': tab,
    'title': title,
    'contains': contains,
  };
}
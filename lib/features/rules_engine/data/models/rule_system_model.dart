// lib/features/rules_engine/data/models/rule_system_model.dart

class RuleSystemModel {
  final String systemId;
  final String systemName;
  final String version;
  
  final List<StatDefinition> statDefinitions; // Notez l'absence de "Model"
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

  factory RuleSystemModel.fromJson(Map<String, dynamic> json) {
    // Lecture de la bibliothèque
    Map<String, List<Map<String, dynamic>>> lib = {};
    if (json['library'] != null) {
      json['library'].forEach((key, value) {
        lib[key] = List<Map<String, dynamic>>.from(value);
      });
    }

    // Lecture des définitions de colonnes (DataDefinitions)
    Map<String, List<DataDefinition>> dataDefs = {};
    if (json['data_definitions'] != null) {
      (json['data_definitions'] as Map<String, dynamic>).forEach((key, value) {
        dataDefs[key] = (value as List).map((e) => DataDefinition.fromJson(e)).toList();
      });
    }

    return RuleSystemModel(
      systemId: json['system_id'] ?? 'unknown',
      systemName: json['system_name'] ?? 'Unknown System',
      version: json['version'] ?? '1.0',
      statDefinitions: (json['stat_definitions'] as List)
          .map((e) => StatDefinition.fromJson(e))
          .toList(),
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

/// Statistique unique (ex: Force, PV)
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
      id: json['id'],
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

/// Colonne d'un tableau (ex: Poids, Qté)
class DataDefinition {
  final String id;
  final String name;
  final String type;
  final int? min;

  DataDefinition({
    required this.id,
    required this.name,
    required this.type,
    this.min,
  });

  factory DataDefinition.fromJson(Map<String, dynamic> json) {
    return DataDefinition(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      min: json['min'],
    );
  }
}

/// Structure visuelle
class LayoutDefinition {
  final List<String> tabs;
  final List<SectionDefinition> sections;

  LayoutDefinition({required this.tabs, required this.sections});

  factory LayoutDefinition.fromJson(Map<String, dynamic> json) {
    return LayoutDefinition(
      tabs: List<String>.from(json['tabs'] ?? []),
      sections: (json['sections'] as List<dynamic>?)
              ?.map((e) => SectionDefinition.fromJson(e))
              .toList() ?? [],
    );
  }
}

class SectionDefinition {
  final String tab;
  final String title;
  final List<String> contains;

  SectionDefinition({required this.tab, required this.title, required this.contains});

  factory SectionDefinition.fromJson(Map<String, dynamic> json) {
    return SectionDefinition(
      tab: json['tab'] ?? "General",
      title: json['title'] ?? "",
      contains: List<String>.from(json['contains'] ?? []),
    );
  }
}
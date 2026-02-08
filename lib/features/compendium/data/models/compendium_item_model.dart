class CompendiumItemModel {
  final String id;
  final String name;
  final String description;
  final Map<String, dynamic>
  details; // Pour stocker tout le reste (niveau, école...) en vrac

  CompendiumItemModel({
    required this.id,
    required this.name,
    required this.description,
    required this.details,
  });

  factory CompendiumItemModel.fromJson(Map<String, dynamic> json) {
    // On extrait les champs connus, et on garde le reste dans 'details'
    final details = Map<String, dynamic>.from(json);
    details.remove('id');
    details.remove('name');
    details.remove('description');

    return CompendiumItemModel(
      id: json['id'] ?? 'unknown',
      name: json['name'] ?? 'Sans nom',
      description: json['description'] ?? '',
      details: details,
    );
  }
}

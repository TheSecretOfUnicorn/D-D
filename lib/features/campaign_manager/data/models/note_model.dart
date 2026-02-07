class NoteModel {
  final String id;
  final String title;
  final String content; // Le texte du scénario
  final String? parentId; // L'ID du dossier parent (null = racine)
  final bool isFolder; // Est-ce un dossier ou une page ?
  final DateTime lastEdited;

  NoteModel({
    required this.id,
    required this.title,
    this.content = "",
    this.parentId,
    this.isFolder = false,
    required this.lastEdited,
  });

  // Sérialisation JSON (comme d'habitude)
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'parent_id': parentId,
    'is_folder': isFolder,
    'last_edited': lastEdited.toIso8601String(),
  };

  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      id: json['id'],
      title: json['title'],
      content: json['content'] ?? "",
      parentId: json['parent_id'],
      isFolder: json['is_folder'] ?? false,
      lastEdited: DateTime.parse(json['last_edited']),
    );
  }
}
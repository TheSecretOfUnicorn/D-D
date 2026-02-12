class NoteModel {
  final int id;
  final String title;
  final String content;
  final bool isPublic;
  final DateTime createdAt;

  NoteModel({
    required this.id,
    required this.title,
    required this.content,
    required this.isPublic,
    required this.createdAt,
  });

  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      id: json['id'],
      title: json['title'] ?? "Sans titre",
      content: json['content'] ?? "",
      isPublic: json['is_public'] ?? false,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'content': content,
    'is_public': isPublic,
  };
}
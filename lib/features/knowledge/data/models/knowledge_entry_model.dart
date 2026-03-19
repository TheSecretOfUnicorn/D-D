enum KnowledgeVisibility { group, targeted, mjOnly }

class KnowledgeEntryModel {
  final int id;
  final String title;
  final String content;
  final bool isPublic;
  final List<int> sharedWith;
  final DateTime createdAt;

  const KnowledgeEntryModel({
    required this.id,
    required this.title,
    required this.content,
    required this.isPublic,
    required this.sharedWith,
    required this.createdAt,
  });

  KnowledgeVisibility get visibility {
    if (isPublic) return KnowledgeVisibility.group;
    if (sharedWith.isNotEmpty) return KnowledgeVisibility.targeted;
    return KnowledgeVisibility.mjOnly;
  }

  factory KnowledgeEntryModel.fromJson(Map<String, dynamic> json) {
    final rawSharedWith = json['shared_with'];
    final sharedWith = rawSharedWith is List
        ? rawSharedWith
            .map((value) => int.tryParse(value.toString()))
            .whereType<int>()
            .toList(growable: false)
        : const <int>[];

    return KnowledgeEntryModel(
      id: json['id'],
      title: json['title'] ?? "Sans titre",
      content: json['content'] ?? "",
      isPublic: json['is_public'] ?? false,
      sharedWith: sharedWith,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}

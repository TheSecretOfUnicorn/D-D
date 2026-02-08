class CampaignModel {
  final int id; // Changement: String -> int (car SERIAL SQL)
  final String title;
  final String? inviteCode;
  final DateTime lastPlayed;
  final bool allowDice;

  CampaignModel({
    required this.id,
    required this.title,
    this.inviteCode,
    required this.lastPlayed,
    required this.allowDice,
  });

  // Factory pour convertir le JSON de PostgreSQL
  factory CampaignModel.fromJson(Map<String, dynamic> json) {
    return CampaignModel(
      id: json['id'], // L'ID est un entier en SQL
      title: json['title'],
      inviteCode: json['invite_code'], // Attention au snake_case
      // PostgreSQL renvoie une date String ISO 8601
      lastPlayed: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      allowDice: json['allow_dice'] ?? true,
    );
  }
}
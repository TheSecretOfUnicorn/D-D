class CampaignModel {
  final int id;
  final String title;
  final String inviteCode; // 👈 Corrigé : String (pas String?)
  final int gmId;
  final String role;       // 👈 Corrigé : Ajouté pour corriger l'erreur dashboard
  final bool allowDice;    // 👈 Corrigé : Ajouté pour corriger l'erreur game page

  CampaignModel({
    required this.id,
    required this.title,
    required this.inviteCode,
    required this.gmId,
    required this.role,
    this.allowDice = true,
  });

  factory CampaignModel.fromJson(Map<String, dynamic> json) {
    return CampaignModel(
      id: json['id'],
      title: json['title'],
      // Si le code est null dans la BDD, on met '????' pour éviter le crash
      inviteCode: json['invite_code'] ?? '????', 
      gmId: json['gm_id'] ?? 0,
      // Si le rôle n'est pas renvoyé, on assume que c'est un Joueur
      role: json['role'] ?? 'PLAYER',
      // Par défaut, on autorise les dés
      allowDice: json['allow_dice'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'invite_code': inviteCode,
      'gm_id': gmId,
      'role': role,
      'allow_dice': allowDice,
    };
  }
}
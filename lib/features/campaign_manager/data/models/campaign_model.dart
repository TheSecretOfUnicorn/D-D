import 'campaign_settings_model.dart';

class CampaignModel {
  final int id;
  final String title;
  final String inviteCode; // 👈 Corrigé : String (pas String?)
  final int gmId;
  final String role; // 👈 Corrigé : Ajouté pour corriger l'erreur dashboard
  final bool allowDice; // 👈 Corrigé : Ajouté pour corriger l'erreur game page
  final int statPointCap;
  final int bonusStatPool;

  CampaignModel({
    required this.id,
    required this.title,
    required this.inviteCode,
    required this.gmId,
    required this.role,
    this.allowDice = true,
    this.statPointCap = 60,
    this.bonusStatPool = 0,
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
      statPointCap: json['stat_point_cap'] ?? 60,
      bonusStatPool: json['bonus_stat_pool'] ?? 0,
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
      'stat_point_cap': statPointCap,
      'bonus_stat_pool': bonusStatPool,
    };
  }

  CampaignSettingsModel get settings => CampaignSettingsModel(
        allowDice: allowDice,
        statPointCap: statPointCap,
        bonusStatPool: bonusStatPool,
      );

  bool get isGM => role == 'GM';

  CampaignModel copyWith({
    int? id,
    String? title,
    String? inviteCode,
    int? gmId,
    String? role,
    bool? allowDice,
    int? statPointCap,
    int? bonusStatPool,
  }) {
    return CampaignModel(
      id: id ?? this.id,
      title: title ?? this.title,
      inviteCode: inviteCode ?? this.inviteCode,
      gmId: gmId ?? this.gmId,
      role: role ?? this.role,
      allowDice: allowDice ?? this.allowDice,
      statPointCap: statPointCap ?? this.statPointCap,
      bonusStatPool: bonusStatPool ?? this.bonusStatPool,
    );
  }
}

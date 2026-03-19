class CampaignSettingsModel {
  final bool allowDice;
  final int statPointCap;
  final int bonusStatPool;

  const CampaignSettingsModel({
    required this.allowDice,
    required this.statPointCap,
    required this.bonusStatPool,
  });

  factory CampaignSettingsModel.fromJson(Map<String, dynamic> json) {
    return CampaignSettingsModel(
      allowDice: json['allow_dice'] ?? true,
      statPointCap: json['stat_point_cap'] ?? 60,
      bonusStatPool: json['bonus_stat_pool'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'allow_dice': allowDice,
      'stat_point_cap': statPointCap,
      'bonus_stat_pool': bonusStatPool,
    };
  }
}

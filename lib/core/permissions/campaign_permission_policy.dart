import '../../features/campaign_manager/data/models/campaign_model.dart';

class CampaignPermissionPolicy {
  final CampaignModel campaign;

  const CampaignPermissionPolicy(this.campaign);

  bool get isGM => campaign.isGM;
  bool get isPlayer => !isGM;

  bool get canManageCampaign => isGM;
  bool get canManageMaps => isGM;
  bool get canOpenMapEditor => isGM;
  bool get canManageCombat => isGM;
  bool get canManageKnowledgeVisibility => isGM;
  bool get canCreateKnowledgeEntry => isGM;
  bool get canAccessCompendiumAdmin => isGM;
  bool get canEditCampaignRules => isGM;
  bool get canAllocateProgression => isGM;

  bool get canAccessKnowledge => true;
  bool get canOpenSessionMap => true;
  bool get canOpenCombatPage => isGM;
  bool get canViewGroupPanel => true;
  bool get canRollDice => campaign.allowDice;

  bool get canEditCharacterInCampaign => isGM;
  bool get canEditCharacterIdentityInCampaign => false;
  bool get canEditInventoryInCampaign => isGM;
  bool get canEditSpellbookInCampaign => isGM;

  String get shellLabel => isGM ? 'MJ' : 'Joueur';
}

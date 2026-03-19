import '../../../campaign_manager/data/models/campaign_model.dart';

class SessionStateModel {
  final CampaignModel campaign;
  final List<Map<String, dynamic>> logs;
  final bool combatActive;
  final int combatRound;
  final int combatParticipants;
  final String? activeMapId;
  final String? activeMapName;
  final int? activeMapWidth;
  final int? activeMapHeight;

  const SessionStateModel({
    required this.campaign,
    required this.logs,
    required this.combatActive,
    required this.combatRound,
    required this.combatParticipants,
    this.activeMapId,
    this.activeMapName,
    this.activeMapWidth,
    this.activeMapHeight,
  });

  bool get hasActiveMap => activeMapId != null;
}

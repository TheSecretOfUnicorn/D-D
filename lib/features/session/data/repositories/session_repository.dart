import '../../../campaign_manager/data/models/campaign_model.dart';
import '../../../campaign_manager/data/repositories/campaign_repository.dart';
import '../../../map_editor/data/repositories/map_repository.dart';
import '../models/session_state_model.dart';

class SessionRepository {
  final CampaignRepository _campaignRepository = CampaignRepository();
  final MapRepository _mapRepository = MapRepository();

  Future<SessionStateModel> loadState(CampaignModel campaign) async {
    final results = await Future.wait<dynamic>([
      _campaignRepository.getLogs(campaign.id),
      _campaignRepository.getCombatDetails(campaign.id),
      _mapRepository.getActiveMapSummary(campaign.id),
    ]);

    final logs = List<Map<String, dynamic>>.from(
      results[0] as List<Map<String, dynamic>>,
      growable: false,
    );
    final combat = results[1] as Map<String, dynamic>;
    final activeMap = results[2] as Map<String, dynamic>?;
    final encounter = combat['encounter'] as Map<String, dynamic>?;
    final participantCount = combat['participants'] is List
        ? (combat['participants'] as List).length
        : 0;

    return SessionStateModel(
      campaign: campaign,
      logs: logs,
      combatActive: combat['active'] == true,
      combatRound: encounter?['round'] ?? 0,
      combatParticipants: participantCount,
      activeMapId: activeMap?['id']?.toString(),
      activeMapName: activeMap?['name']?.toString(),
      activeMapWidth: activeMap?['width'] as int?,
      activeMapHeight: activeMap?['height'] as int?,
    );
  }

  Future<String?> resolveActiveMapId(CampaignModel campaign) {
    return _mapRepository.getActiveMapId(campaign.id);
  }
}

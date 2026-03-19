import 'package:flutter/material.dart';

import '../../../../core/permissions/campaign_permission_policy.dart';
import '../../../campaign_manager/data/models/campaign_model.dart';
import '../../../map_editor/presentation/pages/map_editor_page.dart';

class SessionRuntimePage extends StatelessWidget {
  final CampaignModel campaign;
  final String mapId;

  const SessionRuntimePage({
    super.key,
    required this.campaign,
    required this.mapId,
  });

  @override
  Widget build(BuildContext context) {
    final policy = CampaignPermissionPolicy(campaign);
    return MapEditorPage.session(
      campaignId: campaign.id,
      mapId: mapId,
      isGM: policy.isGM,
    );
  }
}

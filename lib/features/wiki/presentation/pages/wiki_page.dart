import '../../../campaign_manager/presentation/pages/campaign_notes_page.dart';

class WikiPage extends CampaignNotesPage {
  const WikiPage({
    super.key,
    required super.campaignId,
    required super.isGM,
  }) : super(title: "Connaissances de campagne");
}

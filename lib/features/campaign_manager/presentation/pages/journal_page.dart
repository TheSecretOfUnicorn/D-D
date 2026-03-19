import 'campaign_notes_page.dart';

class JournalPage extends CampaignNotesPage {
  const JournalPage({
    super.key,
    required super.campaignId,
    required super.isGM,
  }) : super(title: "Journal et indices");
}

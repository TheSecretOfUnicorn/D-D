import 'package:flutter/material.dart';

import '../../../knowledge/presentation/pages/knowledge_page.dart';
import '../../data/models/campaign_model.dart';
import '../../data/repositories/campaign_repository.dart';

class CampaignNotesPage extends StatefulWidget {
  final int campaignId;
  final bool isGM;
  final String title;

  const CampaignNotesPage({
    super.key,
    required this.campaignId,
    required this.isGM,
    this.title = "Journal et indices",
  });

  @override
  State<CampaignNotesPage> createState() => _CampaignNotesPageState();
}

class _CampaignNotesPageState extends State<CampaignNotesPage> {
  final CampaignRepository _campaignRepository = CampaignRepository();

  CampaignModel? _campaign;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCampaign();
  }

  Future<void> _loadCampaign() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    final campaign = await _campaignRepository.getCampaign(widget.campaignId);
    if (!mounted) return;

    setState(() {
      _campaign = campaign;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_campaign == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 56, color: Colors.redAccent),
                const SizedBox(height: 12),
                const Text(
                  "Campagne introuvable.",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Le module knowledge ne peut pas etre charge sans campagne valide.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _loadCampaign,
                  child: const Text("Reessayer"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return KnowledgePage(
      campaign: _campaign!,
      title: widget.title,
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/services/session_service.dart';
import '../../../../core/ui/app_feedback.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../auth/presentation/pages/auth_page.dart';
import '../../../bug_report/presentation/widgets/bug_report_action.dart';
import '../../../campaign_manager/data/models/campaign_model.dart';
import '../../../campaign_manager/data/repositories/campaign_repository.dart';
import '../../../campaign_manager/presentation/pages/campaign_game_page.dart';
import '../../../character_sheet/data/character_build_rules.dart';
import '../../../character_sheet/data/models/character_model.dart';
import '../../../character_sheet/data/repositories/character_repository_impl.dart';
import '../../../character_sheet/presentation/pages/character_sheet_page.dart';
import '../../../compendium/presentation/pages/compendium_page.dart';
import '../../../rules_engine/data/repositories/rules_repository_impl.dart';

enum AppShellMode { gm, player }

class AppShellPage extends StatefulWidget {
  const AppShellPage({super.key});

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  final AuthRepository _authRepo = AuthRepository();
  final CampaignRepository _campaignRepo = CampaignRepository();
  final CharacterRepositoryImpl _characterRepo = CharacterRepositoryImpl();
  final RulesRepositoryImpl _rulesRepo = RulesRepositoryImpl();
  final SessionService _sessionService = SessionService();

  List<CharacterModel> _characters = const [];
  List<CampaignModel> _campaigns = const [];
  bool _isLoading = true;
  AppShellMode _mode = AppShellMode.gm;
  bool _hasResolvedInitialMode = false;

  List<CampaignModel> get _gmCampaigns =>
      _campaigns.where((campaign) => campaign.isGM).toList(growable: false);

  List<CampaignModel> get _playerCampaigns =>
      _campaigns.where((campaign) => !campaign.isGM).toList(growable: false);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  AppShellMode _defaultModeFor(List<CampaignModel> campaigns) {
    final hasGmCampaign = campaigns.any((campaign) => campaign.isGM);
    if (hasGmCampaign || campaigns.isEmpty) {
      return AppShellMode.gm;
    }
    return AppShellMode.player;
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final results = await Future.wait<dynamic>([
        _characterRepo.getAllCharacters(),
        _campaignRepo.getAllCampaigns(),
      ]);

      final characters =
          (results[0] as List).cast<CharacterModel>().toList(growable: false);
      final campaigns =
          (results[1] as List).cast<CampaignModel>().toList(growable: false);

      if (!mounted) return;
      setState(() {
        _characters = characters;
        _campaigns = campaigns;
        if (!_hasResolvedInitialMode) {
          _mode = _defaultModeFor(campaigns);
          _hasResolvedInitialMode = true;
        }
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppFeedback.error(context, "Impossible de charger l'espace de jeu.");
    }
  }

  Future<void> _logout() async {
    await _authRepo.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthPage()),
      (route) => false,
    );
  }

  Future<void> _openCharacterSheet(CharacterModel character) async {
    final rules = await _rulesRepo.loadDefaultRules();
    if (!mounted) return;

    final activeCampaignId = _mode == AppShellMode.player
        ? await _sessionService.getActiveCampaignId()
        : null;
    if (!mounted) return;

    final freshCharacter = await _characterRepo.getCharacter(character.id);
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CharacterSheetPage(
          character: freshCharacter ?? character,
          rules: rules,
          campaignId: activeCampaignId,
        ),
      ),
    );

    await _loadData();
  }

  Future<void> _createCharacter() async {
    final rules = await _rulesRepo.loadDefaultRules();
    if (!mounted) return;

    final nameController = TextEditingController(text: "Nouveau heros");
    String selectedClass =
        rules.classes.isNotEmpty ? rules.classes.first : 'Guerrier';
    String selectedRace = CharacterBuildRules.supportedRaces.first;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text("Creer un personnage"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: "Nom",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedClass,
                      decoration: const InputDecoration(
                        labelText: "Classe",
                        border: OutlineInputBorder(),
                      ),
                      items: rules.classes
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => selectedClass = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRace,
                      decoration: const InputDecoration(
                        labelText: "Race",
                        border: OutlineInputBorder(),
                      ),
                      items: CharacterBuildRules.supportedRaces
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => selectedRace = value);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text("Annuler"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text("Creer"),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!confirmed) return;

    final statIds = rules.stats.isNotEmpty
        ? rules.stats
        : const ['str', 'dex', 'con', 'int', 'wis', 'cha'];
    final defaultStats = <String, dynamic>{
      ...CharacterBuildRules.buildStats(
        statIds: statIds,
        characterClass: selectedClass,
        race: selectedRace,
      ),
      'level': 1,
      'class': selectedClass,
      'race': selectedRace,
      'hp_current': selectedClass == 'Guerrier' ? 12 : 10,
      'hp_max': selectedClass == 'Guerrier' ? 12 : 10,
      'ac': selectedClass == 'Guerrier' || selectedClass == 'Clerc' ? 16 : 12,
      'inventory': CharacterBuildRules.buildStarterInventory(selectedClass),
      'spellbook': CharacterBuildRules.buildStarterSpellbook(selectedClass),
      'player_build_locked': false,
    };

    final newCharacter = CharacterModel(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      name: nameController.text.trim().isEmpty
          ? "Nouveau heros"
          : nameController.text.trim(),
      stats: defaultStats,
    );

    try {
      final savedCharacter = await _characterRepo.saveCharacter(newCharacter);
      if (!mounted) return;
      await _openCharacterSheet(savedCharacter);
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(
        context,
        "Creation personnage impossible: ${e.toString().replaceFirst('Exception: ', '')}",
      );
    }
  }

  Future<void> _deleteCharacter(String id) async {
    await _characterRepo.deleteCharacter(id);
    await _loadData();
  }

  Future<void> _openCampaign(CampaignModel campaign) async {
    await _sessionService.setActiveCampaignId(campaign.id);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CampaignGamePage(campaign: campaign),
      ),
    );
    await _loadData();
  }

  Future<void> _openCompendium() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CompendiumPage()),
    );
  }

  void _createCampaign() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Nouvelle campagne"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Titre de l'aventure",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                await _campaignRepo.createCampaign(controller.text.trim());
                await _loadData();
              } catch (e) {
                if (!mounted) return;
                setState(() => _isLoading = false);
                AppFeedback.error(
                  context,
                  "Creation campagne impossible: ${e.toString().replaceFirst('Exception: ', '')}",
                );
              }
            },
            child: const Text("Creer"),
          ),
        ],
      ),
    );
  }

  void _joinCampaign() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Rejoindre une campagne"),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: "Code invitation",
            labelText: "Code",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                await _campaignRepo.joinCampaign(controller.text.trim());
                await _loadData();
                if (!mounted) return;
                AppFeedback.success(context, "Campagne rejointe.");
              } catch (e) {
                if (!mounted) return;
                setState(() => _isLoading = false);
                AppFeedback.error(
                  context,
                  e.toString().replaceAll("Exception: ", ""),
                );
              }
            },
            child: const Text("Rejoindre"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCampaign(int campaignId) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Supprimer la campagne ?"),
            content: const Text(
              "Cette action supprimera l'acces MJ a cette campagne.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Annuler"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  "Supprimer",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      await _campaignRepo.deleteCampaign(campaignId);
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppFeedback.error(
        context,
        "Suppression impossible: ${e.toString().replaceFirst('Exception: ', '')}",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGmMode = _mode == AppShellMode.gm;

    return Scaffold(
      appBar: AppBar(
        title: Text(isGmMode ? "Espace MJ" : "Accueil joueur"),
        actions: [
          BugReportActionButton(
            sourcePage: isGmMode ? "app_shell_mj" : "app_shell_player",
            extraContext: {
              'shell_mode': isGmMode ? 'gm' : 'player',
              'campaign_count': _campaigns.length,
              'character_count': _characters.length,
            },
          ),
          if (isGmMode)
            IconButton(
              icon: const Icon(Icons.auto_stories),
              tooltip: "Compendium",
              onPressed: _openCompendium,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Rafraichir",
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Deconnexion",
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          _ModeSwitchBar(
            selectedMode: _mode,
            onModeChanged: (mode) => setState(() => _mode = mode),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: isGmMode
                          ? _buildGmShell(context)
                          : _buildPlayerShell(context),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGmShell(BuildContext context) {
    return [
      _ShellSummaryCard(
        title: "Preparation et arbitrage",
        subtitle:
            "Campagnes dirigees, personnages locaux et acces aux outils MJ uniquement.",
        primaryStatLabel: "Campagnes MJ",
        primaryStatValue: _gmCampaigns.length.toString(),
        secondaryStatLabel: "Personnages",
        secondaryStatValue: _characters.length.toString(),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _PrimaryActionButton(
            icon: Icons.add_circle_outline,
            label: "Nouvelle campagne",
            onPressed: _createCampaign,
          ),
          _PrimaryActionButton(
            icon: Icons.person_add_alt_1,
            label: "Nouveau personnage",
            onPressed: _createCharacter,
          ),
          _PrimaryActionButton(
            icon: Icons.menu_book,
            label: "Compendium",
            onPressed: _openCompendium,
          ),
        ],
      ),
      const SizedBox(height: 20),
      const _SectionHeader(
        title: "Campagnes dirigees",
        subtitle: "Entree d'administration MJ et acces aux sessions de jeu.",
      ),
      const SizedBox(height: 8),
      if (_gmCampaigns.isEmpty)
        _EmptySectionCard(
          title: "Aucune campagne MJ",
          message:
              "Cree ta premiere campagne pour ouvrir un espace de preparation.",
          actionLabel: "Creer une campagne",
          onPressed: _createCampaign,
        )
      else
        ..._gmCampaigns.map(
          (campaign) => _CampaignCard(
            campaign: campaign,
            subtitle: "Code invitation: ${campaign.inviteCode}",
            trailing: IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
              tooltip: "Supprimer",
              onPressed: () => _deleteCampaign(campaign.id),
            ),
            onTap: () => _openCampaign(campaign),
          ),
        ),
      const SizedBox(height: 20),
      const _SectionHeader(
        title: "Personnages locaux",
        subtitle: "Edition hors session et preparation des fiches.",
      ),
      const SizedBox(height: 8),
      if (_characters.isEmpty)
        _EmptySectionCard(
          title: "Aucun personnage",
          message: "Les personnages restent accessibles dans les deux shells.",
          actionLabel: "Creer un personnage",
          onPressed: _createCharacter,
        )
      else
        ..._characters.map(
          (character) => _CharacterCard(
            character: character,
            onTap: () => _openCharacterSheet(character),
            onDelete: () => _deleteCharacter(character.id),
          ),
        ),
    ];
  }

  List<Widget> _buildPlayerShell(BuildContext context) {
    return [
      _ShellSummaryCard(
        title: "Jeu joueur",
        subtitle:
            "Campagnes rejointes, acces session et gestion des heros sans outils MJ parasites.",
        primaryStatLabel: "Campagnes rejoinees",
        primaryStatValue: _playerCampaigns.length.toString(),
        secondaryStatLabel: "Mes heros",
        secondaryStatValue: _characters.length.toString(),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _PrimaryActionButton(
            icon: Icons.group_add,
            label: "Rejoindre une campagne",
            onPressed: _joinCampaign,
          ),
          _PrimaryActionButton(
            icon: Icons.person_add_alt_1,
            label: "Nouveau heros",
            onPressed: _createCharacter,
          ),
        ],
      ),
      const SizedBox(height: 20),
      const _SectionHeader(
        title: "Campagnes rejoinees",
        subtitle: "Point d'entree joueur vers la page campagne et la session.",
      ),
      const SizedBox(height: 8),
      if (_playerCampaigns.isEmpty)
        _EmptySectionCard(
          title: "Aucune campagne joueur",
          message: "Utilise un code d'invitation pour rejoindre une table.",
          actionLabel: "Rejoindre",
          onPressed: _joinCampaign,
        )
      else
        ..._playerCampaigns.map(
          (campaign) => _CampaignCard(
            campaign: campaign,
            subtitle: "Role joueur",
            onTap: () => _openCampaign(campaign),
          ),
        ),
      const SizedBox(height: 20),
      const _SectionHeader(
        title: "Mes heros",
        subtitle:
            "Fiches personnelles hors campagne. Les permissions fines restent gerees en session.",
      ),
      const SizedBox(height: 8),
      if (_characters.isEmpty)
        _EmptySectionCard(
          title: "Aucun heros disponible",
          message:
              "Creer un personnage avant d'entrer en campagne evite les flux bancals.",
          actionLabel: "Creer un heros",
          onPressed: _createCharacter,
        )
      else
        ..._characters.map(
          (character) => _CharacterCard(
            character: character,
            onTap: () => _openCharacterSheet(character),
            onDelete: () => _deleteCharacter(character.id),
          ),
        ),
    ];
  }
}

class _ModeSwitchBar extends StatelessWidget {
  final AppShellMode selectedMode;
  final ValueChanged<AppShellMode> onModeChanged;

  const _ModeSwitchBar({
    required this.selectedMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      color: const Color(0xFF121212),
      child: Wrap(
        spacing: 12,
        children: [
          ChoiceChip(
            label: const Text("Shell MJ"),
            selected: selectedMode == AppShellMode.gm,
            onSelected: (_) => onModeChanged(AppShellMode.gm),
          ),
          ChoiceChip(
            label: const Text("Shell joueur"),
            selected: selectedMode == AppShellMode.player,
            onSelected: (_) => onModeChanged(AppShellMode.player),
          ),
        ],
      ),
    );
  }
}

class _ShellSummaryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String primaryStatLabel;
  final String primaryStatValue;
  final String secondaryStatLabel;
  final String secondaryStatValue;

  const _ShellSummaryCard({
    required this.title,
    required this.subtitle,
    required this.primaryStatLabel,
    required this.primaryStatValue,
    required this.secondaryStatLabel,
    required this.secondaryStatValue,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1E1E1E),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatBadge(
                    label: primaryStatLabel,
                    value: primaryStatValue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatBadge(
                    label: secondaryStatLabel,
                    value: secondaryStatValue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;

  const _StatBadge({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _PrimaryActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.white54),
        ),
      ],
    );
  }
}

class _EmptySectionCard extends StatelessWidget {
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onPressed;

  const _EmptySectionCard({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1E1E1E),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onPressed,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final CampaignModel campaign;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _CampaignCard({
    required this.campaign,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF252525),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              campaign.isGM ? const Color(0xFFB23A48) : const Color(0xFF6D9DC5),
          child: Icon(
            campaign.isGM ? Icons.security : Icons.person,
            color: Colors.white,
          ),
        ),
        title: Text(
          campaign.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white54),
        ),
        trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: onTap,
      ),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  final CharacterModel character;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _CharacterCard({
    required this.character,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF252525),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(
          character.name.isEmpty ? "Sans nom" : character.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          "Niveau ${character.getStat<int>('level', 1)}",
          style: const TextStyle(color: Colors.white54),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.grey),
          onPressed: onDelete,
        ),
        onTap: onTap,
      ),
    );
  }
}

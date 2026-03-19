import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/permissions/campaign_permission_policy.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/ui/app_feedback.dart';
import '../../../bug_report/presentation/widgets/bug_report_action.dart';
import '../../../character_sheet/data/models/character_model.dart';
import '../../../character_sheet/data/repositories/character_repository_impl.dart';
import '../../../character_sheet/presentation/pages/character_sheet_page.dart';
import '../../../combat/presentation/pages/combat_page.dart';
import '../../../knowledge/presentation/pages/knowledge_page.dart';
import '../../../map_editor/presentation/pages/maps_list_page.dart';
import '../../../rules_engine/data/repositories/rules_repository_impl.dart';
import '../../../session/data/models/session_state_model.dart';
import '../../../session/data/repositories/session_repository.dart';
import '../../../session/presentation/pages/session_map_page.dart';
import '../../data/models/campaign_model.dart';
import '../../data/repositories/campaign_repository.dart';

class CampaignGamePage extends StatefulWidget {
  final CampaignModel campaign;

  const CampaignGamePage({super.key, required this.campaign});

  @override
  State<CampaignGamePage> createState() => _CampaignGamePageState();
}

class _CampaignGamePageState extends State<CampaignGamePage> {
  final CampaignRepository _campaignRepository = CampaignRepository();
  final CharacterRepositoryImpl _characterRepository =
      CharacterRepositoryImpl();
  final SessionRepository _sessionRepository = SessionRepository();
  final SessionService _sessionService = SessionService();

  late CampaignModel _campaign;
  CharacterModel? _myCharacter;
  SessionStateModel? _sessionState;
  bool _isLoading = true;
  bool _isSessionLoading = true;
  Timer? _refreshTimer;

  CampaignPermissionPolicy get _policy => CampaignPermissionPolicy(_campaign);
  List<Map<String, dynamic>> get _logs => _sessionState?.logs ?? const [];
  bool get _combatActive => _sessionState?.combatActive ?? false;
  int get _combatRound => _sessionState?.combatRound ?? 0;
  int get _combatParticipants => _sessionState?.combatParticipants ?? 0;

  @override
  void initState() {
    super.initState();
    _campaign = widget.campaign;
    _sessionService.setActiveCampaignId(_campaign.id);
    _loadInitialState();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _refreshCampaignState(showLoader: false),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialState() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    await Future.wait<void>([
      _loadMyCharacter(),
      _refreshCampaignState(showLoader: false),
    ]);

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _refreshCampaignState({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() => _isSessionLoading = true);
    }

    final latestCampaign =
        await _campaignRepository.getCampaign(widget.campaign.id) ?? _campaign;
    final sessionState = await _sessionRepository.loadState(latestCampaign);

    if (!mounted) return;
    setState(() {
      _campaign = latestCampaign;
      _sessionState = sessionState;
      _isSessionLoading = false;
    });
  }

  Future<void> _loadMyCharacter() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'campaign_${widget.campaign.id}_char';
    final charId = prefs.getString(key);

    if (charId == null) {
      if (!mounted) return;
      setState(() => _myCharacter = null);
      return;
    }

    final character = await _characterRepository.getCharacter(charId);
    if (!mounted) return;
    setState(() => _myCharacter = character);
  }

  Future<void> _selectCharacter() async {
    setState(() => _isLoading = true);
    final allCharacters = await _characterRepository.getAllCharacters();
    if (!mounted) return;
    setState(() => _isLoading = false);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: const Text(
          "Choisir mon heros",
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: allCharacters.isEmpty
              ? const Text(
                  "Aucun personnage cree. Va dans Mes heros pour preparer une fiche.",
                  style: TextStyle(color: Colors.white54),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: allCharacters.length,
                  itemBuilder: (context, index) {
                    final character = allCharacters[index];
                    return ListTile(
                      title: Text(
                        character.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      onTap: () async {
                        final prefs = await SharedPreferences.getInstance();
                        final key = 'campaign_${widget.campaign.id}_char';
                        await prefs.setString(key, character.id);

                        try {
                          await _campaignRepository.selectCharacter(
                            widget.campaign.id,
                            character.id,
                          );
                        } catch (error) {
                          if (!mounted || !dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          AppFeedback.error(
                            context,
                            error.toString().replaceFirst('Exception: ', ''),
                          );
                          return;
                        }

                        if (!mounted || !dialogContext.mounted) return;
                        setState(() => _myCharacter = character);
                        Navigator.pop(dialogContext);
                        AppFeedback.success(
                          context,
                          "Personnage actif: ${character.name}",
                        );
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }

  Future<void> _openCharacterSheet() async {
    if (_myCharacter == null) return;

    final rules = await RulesRepositoryImpl().loadDefaultRules();
    if (!mounted) return;

    final freshCharacter =
        await _characterRepository.getCharacter(_myCharacter!.id);
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CharacterSheetPage(
          character: freshCharacter ?? _myCharacter!,
          rules: rules,
          campaignId: _campaign.id,
        ),
      ),
    );

    await Future.wait<void>([
      _loadMyCharacter(),
      _refreshCampaignState(showLoader: false),
    ]);
  }

  Future<void> _openCombatPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CombatPage(
          campaignId: _campaign.id,
          isGM: _policy.canManageCombat,
        ),
      ),
    );

    await _refreshCampaignState(showLoader: false);
  }

  Future<void> _openSessionMap() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SessionMapPage(campaign: _campaign),
      ),
    );

    await _refreshCampaignState(showLoader: false);
  }

  Future<void> _openMapsManager() async {
    if (!_policy.canOpenMapEditor) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapsListPage(
          campaignId: _campaign.id,
          isGM: true,
        ),
      ),
    );

    await _refreshCampaignState(showLoader: false);
  }

  Future<void> _openKnowledgePage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KnowledgePage(campaign: _campaign),
      ),
    );

    await _refreshCampaignState(showLoader: false);
  }

  Future<void> _showDiceRoller() async {
    if (!_policy.canRollDice) {
      AppFeedback.warning(
        context,
        "Les jets de des sont verrouilles sur cette campagne.",
      );
      return;
    }

    if (_policy.isGM) {
      final targetController = TextEditingController(
        text: _myCharacter?.name ?? "un joueur",
      );
      final reasonController = TextEditingController(text: "initiative");
      var faces = 20;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: const Color(0xFF252525),
            title: const Text(
              "Demander un jet",
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: targetController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Cible",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Action ou raison",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: faces,
                  decoration: const InputDecoration(
                    labelText: "De demande",
                    border: OutlineInputBorder(),
                  ),
                  items: const [4, 6, 8, 10, 12, 20, 100]
                      .map(
                        (item) => DropdownMenuItem<int>(
                          value: item,
                          child: Text("d$item"),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => faces = value);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Annuler"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final target = targetController.text.trim().isEmpty
                      ? "un joueur"
                      : targetController.text.trim();
                  final reason = reasonController.text.trim().isEmpty
                      ? "une action"
                      : reasonController.text.trim();
                  Navigator.pop(dialogContext);
                  final success = await _campaignRepository.sendLog(
                    _campaign.id,
                    "Demande de jet: $target doit lancer 1d$faces pour $reason.",
                    type: 'SYSTEM',
                  );

                  if (!mounted || !context.mounted) return;
                  if (!success) {
                    AppFeedback.error(
                      context,
                      "Impossible d'envoyer la demande de jet.",
                    );
                    return;
                  }
                  await _refreshCampaignState(showLoader: false);
                },
                child: const Text("Envoyer"),
              ),
            ],
          ),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: const Text(
          "Repondre a un jet",
          style: TextStyle(color: Colors.white),
        ),
        content: _PlayerDiceResponseForm(
          onSubmit: (faces, reason, manualResult, useInAppRoll) async {
            Navigator.pop(dialogContext);
            final result =
                useInAppRoll ? Random().nextInt(faces) + 1 : manualResult;
            if (result == null || result <= 0) return;
            final actor = _myCharacter?.name ?? "Un aventurier";
            final label = reason.trim().isEmpty ? "la demande du MJ" : reason;
            final success = await _campaignRepository.sendLog(
              _campaign.id,
              "$actor repond a $label : 1d$faces = $result",
              type: 'DICE',
              resultValue: result,
            );

            if (!mounted) return;
            if (!success) {
              AppFeedback.error(
                context,
                "Impossible d'envoyer le jet a la campagne.",
              );
              return;
            }

            await _refreshCampaignState(showLoader: false);
            if (!mounted) return;
            AppFeedback.success(context, "Jet enregistre : $result");
          },
        ),
      ),
    );
  }

  Future<void> _showGroupPanel() async {
    setState(() => _isLoading = true);
    final members = await _campaignRepository.getMembers(_campaign.id);
    if (!mounted) return;
    setState(() => _isLoading = false);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: const Text(
          "Groupe",
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: members.isEmpty
              ? const Text(
                  "Aucun membre trouve.",
                  style: TextStyle(color: Colors.white70),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    final characterName = member['char_name']?.toString();
                    final username =
                        member['username']?.toString() ?? 'Inconnu';
                    final role = member['role']?.toString() ?? '';

                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          (characterName ?? username).isNotEmpty
                              ? (characterName ?? username)[0].toUpperCase()
                              : '?',
                        ),
                      ),
                      title: Text(
                        characterName ?? username,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        [username, if (role.isNotEmpty) role].join(' - '),
                        style: const TextStyle(color: Colors.white54),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Fermer"),
          ),
        ],
      ),
    );
  }

  Future<void> _openCampaignRulesDialog() async {
    if (!_policy.canEditCampaignRules) return;

    var allowDice = _campaign.settings.allowDice;
    final statPointCapController = TextEditingController(
      text: _campaign.settings.statPointCap.toString(),
    );
    final bonusPoolController = TextEditingController(
      text: _campaign.settings.bonusStatPool.toString(),
    );

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text("Regles de campagne"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Autoriser les des"),
                    value: allowDice,
                    onChanged: (value) =>
                        setDialogState(() => allowDice = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: statPointCapController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Cap de stats campagne",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bonusPoolController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Reserve MJ disponible",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Annuler"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final statPointCap =
                      int.tryParse(statPointCapController.text.trim());
                  final bonusPool =
                      int.tryParse(bonusPoolController.text.trim());
                  if (statPointCap == null || statPointCap < 0) {
                    AppFeedback.error(
                      context,
                      "Le cap de stats est invalide.",
                    );
                    return;
                  }
                  if (bonusPool == null || bonusPool < 0) {
                    AppFeedback.error(
                      context,
                      "La reserve MJ est invalide.",
                    );
                    return;
                  }

                  final updatedCampaign =
                      await _campaignRepository.updateSettings(
                    _campaign.id,
                    allowDice: allowDice,
                    statPointCap: statPointCap,
                    bonusStatPool: bonusPool,
                  );

                  if (!mounted || !dialogContext.mounted) return;
                  if (updatedCampaign == null) {
                    AppFeedback.error(
                      context,
                      "Impossible d'enregistrer les regles.",
                    );
                    return;
                  }

                  setState(() => _campaign = updatedCampaign);
                  Navigator.pop(dialogContext);
                },
                child: const Text("Enregistrer"),
              ),
            ],
          ),
        ),
      );
    } finally {
      statPointCapController.dispose();
      bonusPoolController.dispose();
    }

    await _refreshCampaignState(showLoader: false);
  }

  String _formatLogTitle(Map<String, dynamic> log) {
    final type = (log['type'] ?? 'MSG').toString().toUpperCase();
    final content = (log['content'] ?? '').toString();

    if (content.isNotEmpty) {
      return content;
    }

    switch (type) {
      case 'DICE':
        return "Jet de des";
      case 'SYSTEM':
        return "Evenement systeme";
      default:
        return "Entree de campagne";
    }
  }

  String _formatLogMeta(Map<String, dynamic> log) {
    final author = [
      log['username'],
      log['user_name'],
      log['author'],
      log['author_name'],
    ]
        .firstWhere(
          (value) => value != null && value.toString().trim().isNotEmpty,
          orElse: () => '',
        )
        .toString();

    final createdAtRaw = log['created_at']?.toString();
    if (createdAtRaw == null || createdAtRaw.isEmpty) {
      return author;
    }

    final createdAt = DateTime.tryParse(createdAtRaw)?.toLocal();
    if (createdAt == null) {
      return author;
    }

    final time =
        "${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}";

    if (author.isEmpty) {
      return time;
    }

    return "$author - $time";
  }

  Color _logAccent(Map<String, dynamic> log) {
    final type = (log['type'] ?? 'MSG').toString().toUpperCase();
    final resultValue = log['result_value'];

    if (type == 'DICE' && resultValue is num) {
      if (resultValue == 1) return Colors.redAccent;
      if (resultValue >= 20) return Colors.greenAccent;
      return const Color(0xFFFFD700);
    }

    if (type == 'SYSTEM') {
      return Colors.blueGrey;
    }

    return const Color(0xFF8B0000);
  }

  @override
  Widget build(BuildContext context) {
    final combatLabel = _combatActive
        ? (_combatParticipants == 0
            ? "Combat vide"
            : "Combat - Round $_combatRound")
        : "Combat";

    return Scaffold(
      appBar: AppBar(
        title: Text(_campaign.title),
        backgroundColor: const Color(0xFF1A1A1A),
        actions: [
          BugReportActionButton(
            sourcePage: "campaign_game",
            campaignId: _campaign.id,
            characterId: _myCharacter?.id,
            extraContext: {
              'combat_active': _combatActive,
              'combat_round': _combatRound,
              'has_character': _myCharacter != null,
            },
          ),
          if (_policy.canEditCampaignRules)
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: "Regles",
              onPressed: _openCampaignRulesDialog,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Rafraichir",
            onPressed: _refreshCampaignState,
          ),
        ],
      ),
      backgroundColor: const Color(0xFF121212),
      body: Column(
        children: [
          _CampaignHeader(
            policy: _policy,
            characterName: _myCharacter?.name,
            combatActive: _combatActive,
            combatRound: _combatRound,
            combatParticipants: _combatParticipants,
            onSelectCharacter: _policy.isPlayer ? _selectCharacter : null,
            onOpenSheet: _policy.isPlayer && _myCharacter != null
                ? _openCharacterSheet
                : null,
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _refreshCampaignState,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _CampaignRulesCard(
                          campaign: _campaign,
                          policy: _policy,
                          onEdit: _policy.canEditCampaignRules
                              ? _openCampaignRulesDialog
                              : null,
                        ),
                        const SizedBox(height: 16),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.5,
                          children: [
                            if (_policy.canOpenSessionMap)
                              _ActionCard(
                                icon: Icons.map,
                                label: "Table de session",
                                color: const Color(0xFF6D9DC5),
                                onTap: _openSessionMap,
                              ),
                            if (_policy.canOpenMapEditor)
                              _ActionCard(
                                icon: Icons.edit_location_alt,
                                label: "Editeur cartes",
                                color: const Color(0xFF5F8D4E),
                                onTap: _openMapsManager,
                              ),
                            if (_policy.canOpenCombatPage)
                              _ActionCard(
                                icon: Icons.sports_kabaddi,
                                label: combatLabel,
                                color: _combatActive
                                    ? const Color(0xFFB23A48)
                                    : const Color(0xFF9F7E46),
                                onTap: _openCombatPage,
                              ),
                            _ActionCard(
                              icon: Icons.casino,
                              label: _policy.canRollDice
                                  ? "Des"
                                  : "Des verrouilles",
                              color: _policy.canRollDice
                                  ? const Color(0xFFD9A441)
                                  : Colors.grey,
                              onTap: _showDiceRoller,
                            ),
                            if (_policy.canAccessKnowledge)
                              _ActionCard(
                                icon: Icons.book,
                                label: "Connaissances",
                                color: const Color(0xFF8D6E63),
                                onTap: _openKnowledgePage,
                              ),
                            if (_policy.canViewGroupPanel)
                              _ActionCard(
                                icon: Icons.people,
                                label: "Groupe",
                                color: const Color(0xFF6C8A4D),
                                onTap: _showGroupPanel,
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "Chronique de campagne",
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 10),
                        Container(
                          constraints: const BoxConstraints(minHeight: 180),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B1B1B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: _isSessionLoading
                              ? const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : _logs.isEmpty
                                  ? const Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Text(
                                        "Aucun evenement partage pour le moment.",
                                        style: TextStyle(color: Colors.white54),
                                      ),
                                    )
                                  : ListView.separated(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      padding: const EdgeInsets.all(12),
                                      itemCount: _logs.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(
                                        color: Colors.white10,
                                        height: 12,
                                      ),
                                      itemBuilder: (context, index) {
                                        final log = _logs[index];
                                        final accent = _logAccent(log);
                                        return Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              width: 10,
                                              height: 10,
                                              margin:
                                                  const EdgeInsets.only(top: 6),
                                              decoration: BoxDecoration(
                                                color: accent,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _formatLogTitle(log),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    _formatLogMeta(log),
                                                    style: const TextStyle(
                                                      color: Colors.white54,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CampaignHeader extends StatelessWidget {
  final CampaignPermissionPolicy policy;
  final String? characterName;
  final bool combatActive;
  final int combatRound;
  final int combatParticipants;
  final VoidCallback? onSelectCharacter;
  final VoidCallback? onOpenSheet;

  const _CampaignHeader({
    required this.policy,
    required this.characterName,
    required this.combatActive,
    required this.combatRound,
    required this.combatParticipants,
    this.onSelectCharacter,
    this.onOpenSheet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF252525),
      child: Row(
        children: [
          Icon(
            policy.isGM ? Icons.security : Icons.person,
            color: Colors.white,
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  policy.isGM
                      ? "Maitre du jeu"
                      : (characterName ?? "Spectateur"),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  combatActive
                      ? (combatParticipants == 0
                          ? "Combat lance sans participant"
                          : "$combatParticipants participants engages - round $combatRound")
                      : "Exploration en cours",
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 12,
                  ),
                ),
                if (onSelectCharacter != null)
                  GestureDetector(
                    onTap: onSelectCharacter,
                    child: Text(
                      characterName == null
                          ? "Choisir un personnage"
                          : "Changer de personnage",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (onOpenSheet != null)
            ElevatedButton(
              onPressed: onOpenSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B0000),
                foregroundColor: const Color(0xFFFFD700),
              ),
              child: const Text("Fiche"),
            ),
        ],
      ),
    );
  }
}

class _CampaignRulesCard extends StatelessWidget {
  final CampaignModel campaign;
  final CampaignPermissionPolicy policy;
  final VoidCallback? onEdit;

  const _CampaignRulesCard({
    required this.campaign,
    required this.policy,
    this.onEdit,
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Regles de campagne",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (onEdit != null)
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.tune),
                    label: const Text("Editer"),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _RuleChip(
                  label: campaign.allowDice ? "Des actifs" : "Des verrouilles",
                  color: campaign.allowDice
                      ? const Color(0xFFD9A441)
                      : Colors.grey,
                ),
                _RuleChip(
                  label: "Cap stats ${campaign.statPointCap}",
                  color: const Color(0xFF5F8D4E),
                ),
                _RuleChip(
                  label: "Reserve MJ ${campaign.bonusStatPool}",
                  color: const Color(0xFF6D9DC5),
                ),
                _RuleChip(
                  label: policy.isGM ? "Mode MJ" : "Mode joueur",
                  color: policy.isGM
                      ? const Color(0xFFB23A48)
                      : const Color(0xFF8D6E63),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleChip extends StatelessWidget {
  final String label;
  final Color color;

  const _RuleChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white)),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF2C2C2C),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerDiceResponseForm extends StatefulWidget {
  final Future<void> Function(
    int faces,
    String reason,
    int? manualResult,
    bool useInAppRoll,
  ) onSubmit;

  const _PlayerDiceResponseForm({
    required this.onSubmit,
  });

  @override
  State<_PlayerDiceResponseForm> createState() =>
      _PlayerDiceResponseFormState();
}

class _PlayerDiceResponseFormState extends State<_PlayerDiceResponseForm> {
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _manualResultController = TextEditingController();
  int _faces = 20;
  bool _useInAppRoll = false;

  @override
  void dispose() {
    _reasonController.dispose();
    _manualResultController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _reasonController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: "Demande ou action",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _faces,
          decoration: const InputDecoration(
            labelText: "De",
            border: OutlineInputBorder(),
          ),
          items: const [4, 6, 8, 10, 12, 20, 100]
              .map(
                (item) => DropdownMenuItem<int>(
                  value: item,
                  child: Text("d$item"),
                ),
              )
              .toList(growable: false),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _faces = value);
          },
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Lancer le de dans l'app"),
          value: _useInAppRoll,
          onChanged: (value) => setState(() => _useInAppRoll = value),
        ),
        if (!_useInAppRoll)
          TextField(
            controller: _manualResultController,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Resultat manuel",
              border: OutlineInputBorder(),
            ),
          ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: () => widget.onSubmit(
              _faces,
              _reasonController.text.trim(),
              int.tryParse(_manualResultController.text),
              _useInAppRoll,
            ),
            child: const Text("Envoyer"),
          ),
        ),
      ],
    );
  }
}

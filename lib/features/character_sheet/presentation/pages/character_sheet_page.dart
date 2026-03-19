import 'dart:async';
import 'dart:math'; // Pour les jets de dés
import 'package:flutter/material.dart';

import '../../../../core/permissions/campaign_permission_policy.dart';
import '../../../../core/ui/app_feedback.dart';
import '../../data/character_build_rules.dart';
import '../../data/models/character_model.dart';
import '../../data/repositories/character_repository_impl.dart';
import '../../../bug_report/presentation/widgets/bug_report_action.dart';
import '../../../rules_engine/data/models/rule_system_model.dart';
import '../../../compendium/data/repositories/compendium_repository.dart';
import '../../../compendium/presentation/pages/compendium_editor_page.dart';
// 👇 Import nécessaire pour parler au Chat
import '../../../campaign_manager/data/models/campaign_model.dart';
import '../../../campaign_manager/data/repositories/campaign_repository.dart';

class CharacterSheetPage extends StatefulWidget {
  final CharacterModel character;
  final RuleSystemModel rules;
  final int? campaignId; // 👈 Nouveau : Si présent, on est en mode "Jeu"

  const CharacterSheetPage({
    super.key,
    required this.character,
    required this.rules,
    this.campaignId,
  });

  @override
  State<CharacterSheetPage> createState() => _CharacterSheetPageState();
}

class _CharacterSheetPageState extends State<CharacterSheetPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CharacterRepositoryImpl _repo = CharacterRepositoryImpl();
  final CampaignRepository _campaignRepo =
      CampaignRepository(); // Pour envoyer les dés

  final CompendiumRepository _compendiumRepo = CompendiumRepository();
  List<Map<String, dynamic>> _onlineItems = [];
  List<Map<String, dynamic>> _onlineSpells = [];
  bool _isLoadingCompendium = true;
  bool _isLoadingCampaignContext = false;
  CampaignModel? _campaign;

  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _raceController;
  late Map<String, dynamic> _lastSyncedCampaignStats;

  Timer? _saveDebounce;
  bool get _isInCampaign => widget.campaignId != null;
  CampaignPermissionPolicy? get _policy =>
      _campaign == null ? null : CampaignPermissionPolicy(_campaign!);
  bool get _campaignContextReady => !_isInCampaign || _campaign != null;
  bool get _canEditCharacter =>
      !_isInCampaign ||
      (_campaignContextReady && (_policy?.canEditCharacterInCampaign ?? false));
  bool get _canEditName =>
      !_isInCampaign || (_policy?.canEditCharacterIdentityInCampaign ?? false);
  bool get _canEditLoadout =>
      !_isInCampaign ||
      (_campaignContextReady && (_policy?.canEditInventoryInCampaign ?? false));
  bool get _canEditSpellbook =>
      !_isInCampaign ||
      (_campaignContextReady && (_policy?.canEditSpellbookInCampaign ?? false));
  bool get _canRollDiceInCampaign =>
      !_isInCampaign ||
      (_campaignContextReady && (_policy?.canRollDice ?? false));
  int? get _boundCampaignId {
    final rawValue = widget.character.stats['bound_campaign_id'];
    if (rawValue is int) return rawValue;
    if (rawValue is String) return int.tryParse(rawValue);
    return null;
  }

  bool get _isPlayerBuildLocked =>
      widget.character.getStat<bool>('player_build_locked', false);
  bool get _isBoundToCurrentCampaign =>
      _isInCampaign && _boundCampaignId == widget.campaignId;
  bool get _canFinalizePlayerBuild =>
      _isInCampaign &&
      _campaignContextReady &&
      (_policy?.isPlayer ?? false) &&
      _isBoundToCurrentCampaign &&
      !_isPlayerBuildLocked;
  bool get _canEditCoreStats => _canEditCharacter || _canFinalizePlayerBuild;
  List<String> get _trackedStats => widget.rules.stats.isNotEmpty
      ? widget.rules.stats
      : const ['str', 'dex', 'con', 'int', 'wis', 'cha'];
  int get _spentStatPoints => _trackedStats.fold<int>(
        0,
        (sum, statId) => sum + widget.character.getStat<int>(statId, 10),
      );
  int get _defaultStatPointCap => _trackedStats.length * 10;
  int get _statPointCap =>
      _campaign?.statPointCap ??
      widget.character.getStat<int>(
        'stat_point_cap',
        _spentStatPoints > 0 ? _spentStatPoints : _defaultStatPointCap,
      );
  int get _bonusStatPoints =>
      widget.character.getStat<int>('bonus_stat_points', 0);
  int get _campaignBonusPool => _campaign?.bonusStatPool ?? 0;
  int get _totalAllocatedStatPoints => _statPointCap + _bonusStatPoints;
  int get _remainingStatPoints => _totalAllocatedStatPoints - _spentStatPoints;
  bool get _canRequestDice =>
      _isInCampaign && (_policy?.isGM ?? false) && _canRollDiceInCampaign;
  List<String> get _raceOptions => CharacterBuildRules.supportedRaces;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    _nameController = TextEditingController(text: widget.character.name);
    _bioController = TextEditingController(
        text: widget.character.getStat<String>('bio', ''));
    _raceController = TextEditingController(
        text: widget.character.getStat<String>('race', ''));
    _lastSyncedCampaignStats = _currentStatsSnapshot();

    _loadCompendium();
    _loadCampaignSettings();
  }

  Future<void> _loadCompendium() async {
    if (!mounted) return;
    setState(() => _isLoadingCompendium = true);

    // On pourrait utiliser l'ID de la campagne du perso, ou celui passé en paramètre
    final campaignIdStr = widget.campaignId?.toString();
    try {
      final data = await _compendiumRepo.fetchFullCompendium(campaignIdStr);
      if (mounted) {
        setState(() {
          _onlineItems = data['items']!;
          _onlineSpells = data['spells']!;
          _isLoadingCompendium = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCompendium = false);
    }
  }

  Future<void> _loadCampaignSettings() async {
    if (!_isInCampaign) return;

    if (mounted) {
      setState(() => _isLoadingCampaignContext = true);
    }
    final campaign = await _campaignRepo.getCampaign(widget.campaignId!);
    if (!mounted) return;

    setState(() {
      _campaign = campaign;
      _isLoadingCampaignContext = false;
    });
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _tabController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    _raceController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _currentStatsSnapshot() {
    final updatedStats = Map<String, dynamic>.from(widget.character.stats);
    updatedStats['bio'] = _bioController.text;
    updatedStats['race'] = _raceController.text;
    return updatedStats;
  }

  void _saveChanges() async {
    final currentStats = _currentStatsSnapshot();
    widget.character.stats = Map<String, dynamic>.from(currentStats);

    if (_isInCampaign) {
      if (!_canEditCharacter && !_canFinalizePlayerBuild) return;

      if (_canFinalizePlayerBuild && !_canEditCharacter) {
        final charToSave = widget.character.copyWith(
          name: _nameController.text,
          stats: currentStats,
        );

        try {
          final savedCharacter = await _repo.saveCharacter(charToSave);
          widget.character.id = savedCharacter.id;
          widget.character.name = savedCharacter.name;
          widget.character.imagePath = savedCharacter.imagePath;
          widget.character.stats =
              Map<String, dynamic>.from(savedCharacter.stats);
          _lastSyncedCampaignStats = _currentStatsSnapshot();
        } catch (e) {
          if (mounted) {
            AppFeedback.error(
              context,
              "Impossible d'enregistrer l'allocation initiale.",
            );
          }
        }
        return;
      }

      try {
        final changedEntries = currentStats.entries.where((entry) {
          return _lastSyncedCampaignStats[entry.key] != entry.value;
        }).toList()
          ..sort((a, b) {
            if (a.key == 'bonus_stat_points') return -1;
            if (b.key == 'bonus_stat_points') return 1;
            return 0;
          });

        if (changedEntries.isEmpty) return;

        var syncOk = true;
        final failedEntries = <String, dynamic>{};

        for (final entry in changedEntries) {
          final saved = await _campaignRepo.updateMemberStat(
            widget.campaignId!,
            widget.character.id,
            entry.key,
            entry.value,
          );
          if (saved) {
            _lastSyncedCampaignStats[entry.key] = entry.value;
          } else {
            syncOk = false;
            failedEntries[entry.key] = _lastSyncedCampaignStats[entry.key];
          }
        }

        if (failedEntries.isNotEmpty && mounted) {
          setState(() {
            for (final entry in failedEntries.entries) {
              widget.character.setStat(entry.key, entry.value);
            }
            _bioController.text = widget.character.getStat<String>('bio', '');
            _raceController.text = widget.character.getStat<String>('race', '');
          });
        }

        await _loadCampaignSettings();
        if (!mounted) return;
        if (!syncOk) {
          AppFeedback.error(
            context,
            "Certaines regles de campagne ont refuse la modification.",
          );
        }
      } catch (e) {
        if (mounted) {
          AppFeedback.error(
            context,
            "Impossible de synchroniser les modifications MJ.",
          );
        }
      }
      return;
    }
    // Mise à jour locale du modèle avant sauvegarde
    // Note: character est passé par référence, donc on modifie l'objet original
    // Mais idéalement on devrait utiliser une copie locale si on voulait être puriste.
    // Ici c'est acceptable pour la simplicité.
    final updatedStats = Map<String, dynamic>.from(widget.character.stats);
    updatedStats['bio'] = _bioController.text;
    updatedStats['race'] = _raceController.text;

    // On recrée un objet propre pour la sauvegarde
    final charToSave = widget.character.copyWith(
      name: _nameController.text,
      stats: updatedStats,
    );

    try {
      final savedCharacter = await _repo.saveCharacter(charToSave);
      widget.character.id = savedCharacter.id;
      widget.character.name = savedCharacter.name;
      widget.character.imagePath = savedCharacter.imagePath;
      widget.character.stats = Map<String, dynamic>.from(savedCharacter.stats);
      if (mounted) {
        // Discret en mode jeu, visible en mode édition
        if (widget.campaignId == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Sauvegardé !"),
              duration: Duration(milliseconds: 500)));
        }
      }
    } catch (e) {
      // Error handling silencieux ou SnackBar rouge
    }
  }

  void _updateStat(String key, dynamic value) {
    setState(() {
      widget.character.setStat(key, value);
    });
    if (_saveDebounce?.isActive ?? false) _saveDebounce!.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 1000), _saveChanges);
  }

  void _updateBonusAllocation(int nextValue) {
    if (!_canEditCharacter) return;

    final currentValue = _bonusStatPoints;
    if (nextValue == currentValue) return;
    if (nextValue < 0) return;

    final delta = nextValue - currentValue;
    if (delta > _campaignBonusPool) {
      AppFeedback.error(
        context,
        "Reserve MJ insuffisante ($_campaignBonusPool restant).",
      );
      return;
    }

    _updateStat('bonus_stat_points', nextValue);
  }

  void _updateCoreStat(String key, int nextValue) {
    if (!_canEditCoreStats) {
      AppFeedback.warning(
        context,
        "L'allocation initiale est verrouillee pour cette campagne.",
      );
      return;
    }

    final currentValue = widget.character.getStat<int>(key, 10);
    if (nextValue == currentValue) return;
    if (nextValue < 0) return;

    if (nextValue > currentValue && _remainingStatPoints <= 0) {
      AppFeedback.error(
        context,
        "Aucun point de caracteristique disponible.",
      );
      return;
    }

    _updateStat(key, nextValue);
  }

  Future<void> _finalizePlayerBuild() async {
    if (!_canFinalizePlayerBuild) return;
    if (_remainingStatPoints < 0) {
      AppFeedback.error(
        context,
        "Le budget de points doit etre valide avant finalisation.",
      );
      return;
    }

    _saveDebounce?.cancel();
    final currentStats = _currentStatsSnapshot();
    final charToSave = widget.character.copyWith(
      name: _nameController.text,
      stats: currentStats,
    );

    try {
      final savedCharacter = await _repo.saveCharacter(charToSave);
      widget.character.id = savedCharacter.id;
      widget.character.name = savedCharacter.name;
      widget.character.imagePath = savedCharacter.imagePath;
      widget.character.stats = Map<String, dynamic>.from(savedCharacter.stats);
      _lastSyncedCampaignStats = _currentStatsSnapshot();
    } catch (error) {
      if (!mounted) return;
      AppFeedback.error(
        context,
        error.toString().replaceFirst('Exception: ', ''),
      );
      return;
    }

    bool success = false;
    try {
      success = await _campaignRepo.finalizeCharacterBuild(
        widget.campaignId!,
        widget.character.id,
      );
    } catch (error) {
      if (!mounted) return;
      AppFeedback.error(
        context,
        error.toString().replaceFirst('Exception: ', ''),
      );
      return;
    }

    if (!mounted) return;

    if (!success) {
      AppFeedback.error(
        context,
        "Impossible de finaliser cette fiche pour la campagne.",
      );
      return;
    }

    setState(() {
      widget.character.setStat('bound_campaign_id', widget.campaignId);
      widget.character.setStat('player_build_locked', true);
    });
    AppFeedback.success(
      context,
      "Fiche finalisee pour cette campagne. Le MJ gere la progression ensuite.",
    );
  }

  void _applyCreationTemplate() {
    final selectedClass = widget.character.getStat<String>('class', 'Guerrier');
    final selectedRace = _raceController.text.trim().isEmpty
        ? _raceOptions.first
        : _raceController.text.trim();
    final statIds = widget.rules.stats.isNotEmpty
        ? widget.rules.stats
        : const ['str', 'dex', 'con', 'int', 'wis', 'cha'];
    final starterStats = CharacterBuildRules.buildStats(
      statIds: statIds,
      characterClass: selectedClass,
      race: selectedRace,
    );

    setState(() {
      for (final entry in starterStats.entries) {
        widget.character.setStat(entry.key, entry.value);
      }
      widget.character.setStat(
        'inventory',
        CharacterBuildRules.buildStarterInventory(selectedClass),
      );
      widget.character.setStat(
        'spellbook',
        CharacterBuildRules.buildStarterSpellbook(selectedClass),
      );
      final baseHp = selectedClass == 'Guerrier' ? 12 : 10;
      final baseAc =
          selectedClass == 'Guerrier' || selectedClass == 'Clerc' ? 16 : 12;
      widget.character.setStat('hp_max', baseHp);
      widget.character.setStat('hp_current', baseHp);
      widget.character.setStat('ac', baseAc);
    });

    _saveChanges();
  }

  Future<void> _handleCampaignStatAction(String statName, int value) async {
    if (!_isInCampaign) return;
    if (!_canRollDiceInCampaign) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Les jets de des sont verrouilles sur cette campagne."),
        ),
      );
      return;
    }

    final mod = ((value - 10) / 2).floor();
    final sign = mod >= 0 ? "+" : "";

    if (_canRequestDice) {
      final reasonController = TextEditingController(text: statName);
      final sendRequest = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              backgroundColor: const Color(0xFF252525),
              title: const Text(
                "Demander un jet",
                style: TextStyle(color: Colors.white),
              ),
              content: TextField(
                controller: reasonController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Action ou raison",
                  border: OutlineInputBorder(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text("Annuler"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text("Envoyer"),
                ),
              ],
            ),
          ) ??
          false;

      if (!sendRequest) return;

      final label = reasonController.text.trim().isEmpty
          ? statName
          : reasonController.text.trim();
      await _campaignRepo.sendLog(
        widget.campaignId!,
        "Demande de jet: ${widget.character.name} doit tester $label ($sign$mod).",
        type: 'SYSTEM',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Demande de jet envoyee.")),
      );
      return;
    }

    final manualResultController = TextEditingController();
    final manualEntry = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: const Color(0xFF252525),
            title: const Text(
              "Repondre au jet",
              style: TextStyle(color: Colors.white),
            ),
            content: TextField(
              controller: manualResultController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Resultat manuel de d20 pour $statName",
                border: const OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text("Lancer in app"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text("Valider"),
              ),
            ],
          ),
        ) ??
        false;

    final d20 = manualEntry
        ? int.tryParse(manualResultController.text)
        : Random().nextInt(20) + 1;
    if (d20 == null || d20 <= 0) return;
    final total = d20 + mod;

    await _campaignRepo.sendLog(
      widget.campaignId!,
      "${widget.character.name} repond au jet $statName ($sign$mod) : d20 $d20 = $total",
      type: 'DICE',
      resultValue: total,
    );

    if (!mounted) return;
    AppFeedback.success(context, "Jet enregistre : $total");
  }

  // 🔥 FONCTION CLÉ : Lancer un dé et l'envoyer au chat 🔥
  // ignore: unused_element
  void _rollStat(String statName, int value) async {
    if (widget.campaignId == null) return; // Pas de campagne = pas de chat
    if (!_canRollDiceInCampaign) {
      AppFeedback.warning(
        context,
        "Les jets de des sont verrouilles sur cette campagne.",
      );
      return;
    }

    final mod = ((value - 10) / 2).floor();
    final d20 = Random().nextInt(20) + 1;
    final total = d20 + mod;

    final sign = mod >= 0 ? "+" : "";
    final msg =
        "a testé $statName ($sign$mod) : $total"; // ex: "a testé Force (+3) : 15"

    await _campaignRepo.sendLog(widget.campaignId!, msg,
        type: 'DICE', resultValue: total);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Jet envoyé : $total"),
        backgroundColor: Colors.indigo,
        duration: const Duration(milliseconds: 800),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _canEditName
            ? TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontSize: 20),
                decoration: const InputDecoration(
                    border: InputBorder.none, hintText: "Nom du personnage"),
                onSubmitted: (_) => _saveChanges(),
              )
            : Text(widget.character.name),
        actions: [
          BugReportActionButton(
            sourcePage: "character_sheet",
            campaignId: widget.campaignId,
            characterId: widget.character.id,
            extraContext: {
              'can_edit_character': _canEditCharacter,
              'can_finalize_build': _canFinalizePlayerBuild,
              'build_locked': _isPlayerBuildLocked,
            },
          ),
          // Raccourci MJ (visible seulement si on n'est PAS en mode jeu pour éviter la confusion)
          if (!_isInCampaign)
            IconButton(
              icon: const Icon(Icons.library_add),
              onPressed: () async {
                final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CompendiumEditorPage()));
                if (result == true) {
                  await Future.delayed(const Duration(milliseconds: 300));
                  _loadCompendium();
                }
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.bar_chart), text: "Stats"),
            Tab(icon: Icon(Icons.person), text: "Bio"),
            Tab(icon: Icon(Icons.backpack), text: "Inventaire"),
            Tab(icon: Icon(Icons.auto_fix_high), text: "Sorts"),
          ],
        ),
      ),
      backgroundColor: const Color(0xFF121212),
      body: Column(
        children: [
          if (_isInCampaign && _isLoadingCampaignContext)
            const LinearProgressIndicator(minHeight: 2),
          if (_isInCampaign && !_isLoadingCampaignContext && _campaign == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFF3A1F22),
              child: const Text(
                "Contexte campagne indisponible. Les modifications gouvernees par les regles sont verrouillees.",
                style: TextStyle(color: Colors.white70),
              ),
            ),
          if (_isInCampaign)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: _canEditCharacter
                  ? const Color(0xFF3B2F12)
                  : const Color(0xFF2A1F1F),
              child: Text(
                _canEditCharacter
                    ? "Mode campagne MJ : progression et budget sous controle du meneur."
                    : "Mode campagne joueur : fiche verrouillee, seules les actions de jeu restent disponibles.",
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStatsTab(),
                _buildBioTab(),
                InventoryTab(
                  key: ValueKey(_onlineItems.length),
                  character: widget.character,
                  availableItems: _onlineItems,
                  isLoading: _isLoadingCompendium,
                  onSave: _saveChanges,
                  campaignId: widget
                      .campaignId, // On passe l'ID pour permettre l'utilisation
                  campaignRepo: _campaignRepo,
                  canEditLoadout: _canEditLoadout,
                ),
                SpellbookTab(
                  key: ValueKey(_onlineSpells.length),
                  character: widget.character,
                  availableSpells: _onlineSpells,
                  isLoading: _isLoadingCompendium,
                  onSave: _saveChanges,
                  campaignId: widget.campaignId,
                  campaignRepo: _campaignRepo,
                  canEditSpellbook: _canEditSpellbook,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    // Sécurité si les règles ne sont pas chargées
    final List<String> statsList = widget.rules.stats.isNotEmpty
        ? widget.rules.stats
        : ['str', 'dex', 'con', 'int', 'wis', 'cha'];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text("Caractéristiques",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.indigo)),
        const Divider(),
        ...statsList.map((statId) {
          final int currentValue = widget.character.getStat<int>(statId, 10);
          final int modifier = ((currentValue - 10) / 2).floor();
          final String modSign = modifier >= 0 ? "+" : "";
          final String displayName = widget.rules.getStatName(statId);

          return Card(
            color: const Color(0xFF252525),
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              title: Text(displayName,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text("Modif: $modSign$modifier",
                  style: const TextStyle(color: Colors.white54)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 👇 LE BOUTON DE JEU (Seulement si en campagne)
                  if (_isInCampaign)
                    IconButton(
                      icon: const Icon(Icons.casino, color: Colors.deepOrange),
                      tooltip: "Lancer le dé",
                      onPressed: _canRollDiceInCampaign
                          ? () => _handleCampaignStatAction(
                                displayName,
                                currentValue,
                              )
                          : null,
                    ),

                  // Éditeurs (Petits boutons discrets)
                  SizedBox(
                    height: 30,
                    width: 30,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.remove,
                          size: 16, color: Colors.white70),
                      onPressed: _canEditCoreStats
                          ? () => _updateCoreStat(statId, currentValue - 1)
                          : null,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text("$currentValue",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ),
                  SizedBox(
                    height: 30,
                    width: 30,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.add,
                          size: 16, color: Colors.white70),
                      onPressed: _canEditCoreStats
                          ? () => _updateCoreStat(statId, currentValue + 1)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        _buildStatBudgetCard(),
        const SizedBox(height: 20),
        const Text("État",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.indigo)),
        const Divider(),
        _buildNumberEditor("Niveau", "level", 1),
        _buildNumberEditor("PV Actuels", "hp_current", 10),
        _buildNumberEditor("PV Max", "hp_max", 10),
        _buildNumberEditor("Classe d'Armure (CA)", "ac", 10),
      ],
    );
  }

  Widget _buildNumberEditor(String label, String key, int defaultValue) {
    final int val = widget.character.getStat<int>(key, defaultValue);
    return Card(
      color: const Color(0xFF252525),
      child: ListTile(
        title: Text(label, style: const TextStyle(color: Colors.white)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove, color: Colors.white70),
              onPressed:
                  _canEditCharacter ? () => _updateStat(key, val - 1) : null,
            ),
            Text("$val",
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white70),
              onPressed:
                  _canEditCharacter ? () => _updateStat(key, val + 1) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBudgetCard() {
    final bool canEditCampaignRules =
        _isInCampaign && (_policy?.canEditCampaignRules ?? false);
    final bool isPlayerInCampaign =
        _isInCampaign && (_policy?.isPlayer ?? false);

    return Card(
      color: const Color(0xFF1D2A22),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Budget de progression",
              style: TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Depenses totales: $_spentStatPoints",
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              "Budget total autorise: $_totalAllocatedStatPoints",
              style: const TextStyle(color: Colors.white70),
            ),
            if (_isInCampaign)
              Text(
                "Bonus alloue au personnage: $_bonusStatPoints",
                style: const TextStyle(color: Colors.white70),
              ),
            if (_isInCampaign)
              Text(
                "Reserve MJ restante: $_campaignBonusPool",
                style: const TextStyle(color: Colors.white70),
              ),
            if (_isInCampaign)
              Text(
                "Cap de campagne: $_statPointCap",
                style: const TextStyle(color: Colors.white70),
              ),
            if (_isInCampaign) const SizedBox(height: 4),
            Text(
              "Points restants: $_remainingStatPoints",
              style: TextStyle(
                color: _remainingStatPoints < 0
                    ? Colors.redAccent
                    : Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (canEditCampaignRules) ...[
              _buildAllocationEditor(),
            ] else if (_canFinalizePlayerBuild) ...[
              const Text(
                "Allocation initiale joueur : tu ajustes les caracteristiques une seule fois pour cette campagne.",
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _finalizePlayerBuild,
                icon: const Icon(Icons.lock_clock_outlined),
                label: const Text("Finaliser pour la campagne"),
              ),
            ] else if (isPlayerInCampaign)
              Text(
                _isPlayerBuildLocked
                    ? "Allocation initiale deja validee. La progression passe desormais par le MJ."
                    : "Associe d'abord cette fiche a la campagne active pour finaliser son allocation.",
                style: const TextStyle(color: Colors.white54),
              )
            else
              const Text(
                "Le MJ gere seul ce budget pendant la campagne.",
                style: TextStyle(color: Colors.white54),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllocationEditor() {
    return Card(
      color: const Color(0xFF252525),
      child: ListTile(
        title: const Text("Bonus alloue a ce personnage",
            style: TextStyle(color: Colors.white)),
        subtitle: const Text(
          "Cette reserve ajoute du budget uniquement a cette fiche",
          style: TextStyle(color: Colors.white54),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove, color: Colors.white70),
              onPressed: () => _updateBonusAllocation(_bonusStatPoints - 1),
            ),
            Text(
              "$_bonusStatPoints",
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white70),
              onPressed: () => _updateBonusAllocation(_bonusStatPoints + 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBioTab() {
    final List<String> validClasses = widget.rules.classes;
    final String raceValue = _raceController.text.trim();
    final raceBonuses = CharacterBuildRules.racePreview(raceValue);
    final starterInventory = CharacterBuildRules.buildStarterInventory(
      widget.character.getStat<String>('class', 'Guerrier'),
    );
    final starterSpells = CharacterBuildRules.buildStarterSpellbook(
      widget.character.getStat<String>('class', 'Guerrier'),
    );
    String? currentClass = widget.character.getStat<String?>('class', null);
    if (currentClass != null && !validClasses.contains(currentClass)) {
      currentClass = null;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: currentClass,
            decoration: const InputDecoration(
                labelText: "Classe", border: OutlineInputBorder()),
            dropdownColor: const Color(0xFF333333),
            style: const TextStyle(color: Colors.white),
            items: validClasses
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged:
                _canEditCharacter ? (val) => _updateStat('class', val) : null,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _raceOptions.contains(raceValue) ? raceValue : null,
            decoration: const InputDecoration(
                labelText: "Race", border: OutlineInputBorder()),
            dropdownColor: const Color(0xFF333333),
            style: const TextStyle(color: Colors.white),
            items: _raceOptions
                .map((race) => DropdownMenuItem(value: race, child: Text(race)))
                .toList(),
            onChanged: !_canEditCharacter
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() => _raceController.text = value);
                    _saveChanges();
                  },
          ),
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFF252525),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Profil race / classe",
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: Colors.amberAccent),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    raceBonuses.isEmpty
                        ? "Aucun bonus racial defini."
                        : "Bonus raciaux: ${raceBonuses.entries.map((entry) => '${entry.key.toUpperCase()} ${entry.value >= 0 ? '+' : ''}${entry.value}').join(', ')}",
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Pack de depart: ${starterInventory.map((item) => item['name']).join(', ')}",
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    starterSpells.isEmpty
                        ? "Aucun sort de depart."
                        : "Sorts de depart: ${starterSpells.map((spell) => spell['name']).join(', ')}",
                    style: const TextStyle(color: Colors.white70),
                  ),
                  if (!_isInCampaign && _canEditCharacter) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _applyCreationTemplate,
                        icon: const Icon(Icons.auto_fix_high),
                        label: const Text("Appliquer le profil DnD"),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _bioController,
            maxLines: 10,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
                labelText: "Biographie / Notes", border: OutlineInputBorder()),
            readOnly: !_canEditCharacter,
            onEditingComplete: _canEditCharacter ? _saveChanges : null,
          ),
        ],
      ),
    );
  }
}

// --- ONGLETS ADAPTÉS POUR LE JEU ---

class InventoryTab extends StatefulWidget {
  final CharacterModel character;
  final List<Map<String, dynamic>> availableItems;
  final bool isLoading;
  final VoidCallback onSave;
  final int? campaignId; // Important pour le Chat
  final CampaignRepository? campaignRepo; // Important pour le Chat
  final bool canEditLoadout;

  const InventoryTab({
    super.key,
    required this.character,
    required this.availableItems,
    required this.isLoading,
    required this.onSave,
    this.campaignId,
    this.campaignRepo,
    this.canEditLoadout = true,
  });

  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  late List<dynamic> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.character.getStat<List<dynamic>>('inventory', []);
  }

  // 👇 LOGIQUE D'ACTION
  void _useItem(String name) {
    if (widget.campaignId != null && widget.campaignRepo != null) {
      widget.campaignRepo!.sendLog(widget.campaignId!, "a utilisé : $name");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Utilisé : $name"),
          duration: const Duration(seconds: 1)));
    }
  }

  void _addItem() {
    String selectedName = "";
    String selectedDesc = "";
    TextEditingController qtyCtrl = TextEditingController(text: "1");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: const Text("Ajouter un objet",
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Autocomplete<Map<String, dynamic>>(
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text == '') return const Iterable.empty();
                return widget.availableItems.where((o) => o['name']
                    .toString()
                    .toLowerCase()
                    .contains(textEditingValue.text.toLowerCase()));
              },
              displayStringForOption: (o) => o['name'],
              onSelected: (s) {
                selectedName = s['name'];
                selectedDesc = s['desc'] ?? "";
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) =>
                      TextField(
                controller: controller,
                focusNode: focusNode,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: "Nom de l'objet",
                    suffixIcon: Icon(Icons.search, color: Colors.white70)),
                onChanged: (val) => selectedName = val,
              ),
            ),
            TextField(
                controller: qtyCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Quantité"),
                keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () {
              if (selectedName.isNotEmpty) {
                setState(() {
                  _items.add({
                    'name': selectedName,
                    'qty': int.tryParse(qtyCtrl.text) ?? 1,
                    'desc': selectedDesc
                  });
                  widget.character.setStat('inventory', _items);
                });
                widget.onSave();
              }
              Navigator.pop(ctx);
            },
            child: const Text("Ajouter"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: widget.canEditLoadout
          ? FloatingActionButton(
              onPressed: _addItem,
              backgroundColor: Colors.brown,
              child: const Icon(Icons.add))
          : null,
      body: _items.isEmpty
          ? const Center(
              child: Text("Sac à dos vide.",
                  style: TextStyle(color: Colors.white54)))
          : ListView.builder(
              itemCount: _items.length,
              itemBuilder: (ctx, i) => Card(
                color: const Color(0xFF252525),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ExpansionTile(
                  leading: CircleAvatar(
                      backgroundColor: Colors.brown[100],
                      child: Text("${_items[i]['qty']}",
                          style: const TextStyle(color: Colors.brown))),
                  title: Text(_items[i]['name'] ?? "Objet",
                      style: const TextStyle(color: Colors.white)),
                  children: [
                    if (_items[i]['desc'] != null &&
                        _items[i]['desc'].toString().isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(_items[i]['desc'],
                              style: const TextStyle(color: Colors.white70))),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      // 👇 BOUTON UTILISER (Visible seulement si en campagne)
                      if (widget.campaignId != null)
                        TextButton.icon(
                          icon:
                              const Icon(Icons.touch_app, color: Colors.green),
                          label: const Text("Utiliser"),
                          onPressed: () => _useItem(_items[i]['name']),
                        ),
                      if (widget.canEditLoadout)
                        TextButton.icon(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            label: const Text("Jeter"),
                            onPressed: () {
                              setState(() {
                                _items.removeAt(i);
                                widget.character.setStat('inventory', _items);
                              });
                              widget.onSave();
                            }),
                    ]),
                  ],
                ),
              ),
            ),
    );
  }
}

class SpellbookTab extends StatefulWidget {
  final CharacterModel character;
  final List<Map<String, dynamic>> availableSpells;
  final bool isLoading;
  final VoidCallback onSave;
  final int? campaignId;
  final CampaignRepository? campaignRepo;
  final bool canEditSpellbook;

  const SpellbookTab({
    super.key,
    required this.character,
    required this.availableSpells,
    required this.isLoading,
    required this.onSave,
    this.campaignId,
    this.campaignRepo,
    this.canEditSpellbook = true,
  });

  @override
  State<SpellbookTab> createState() => _SpellbookTabState();
}

class _SpellbookTabState extends State<SpellbookTab> {
  late List<dynamic> _spells;

  @override
  void initState() {
    super.initState();
    _spells = widget.character.getStat<List<dynamic>>('spellbook', []);
  }

  // 👇 LOGIQUE DE LANCER DE SORT
  void _castSpell(String name) {
    if (widget.campaignId != null && widget.campaignRepo != null) {
      widget.campaignRepo!.sendLog(widget.campaignId!, "incante : $name ✨");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Lancé : $name"),
          duration: const Duration(seconds: 1)));
    }
  }

  void _addSpell() {
    String selectedName = "";
    TextEditingController levelCtrl = TextEditingController(text: "0");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: const Text("Apprendre un sort",
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Autocomplete<Map<String, dynamic>>(
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text == '') return const Iterable.empty();
                return widget.availableSpells.where((o) => o['name']
                    .toString()
                    .toLowerCase()
                    .contains(textEditingValue.text.toLowerCase()));
              },
              displayStringForOption: (o) => o['name'],
              onSelected: (s) {
                selectedName = s['name'];
                levelCtrl.text = (s['level'] ?? 0).toString();
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) =>
                      TextField(
                controller: controller,
                focusNode: focusNode,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Nom du sort"),
                onChanged: (val) => selectedName = val,
              ),
            ),
            TextField(
                controller: levelCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Niveau"),
                keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Annuler")),
          ElevatedButton(
              onPressed: () {
                if (selectedName.isNotEmpty) {
                  setState(() {
                    _spells.add({
                      'name': selectedName,
                      'level': int.tryParse(levelCtrl.text) ?? 0
                    });
                    widget.character.setStat('spellbook', _spells);
                  });
                  widget.onSave();
                }
                Navigator.pop(ctx);
              },
              child: const Text("Ajouter")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: widget.canEditSpellbook
          ? FloatingActionButton(
              onPressed: _addSpell,
              backgroundColor: Colors.purple,
              child: const Icon(Icons.auto_fix_high))
          : null,
      body: _spells.isEmpty
          ? const Center(
              child: Text("Grimoire vide.",
                  style: TextStyle(color: Colors.white54)))
          : ListView.builder(
              itemCount: _spells.length,
              itemBuilder: (ctx, i) => Card(
                color: const Color(0xFF252525),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                      backgroundColor: Colors.purple[100],
                      child: Text("${_spells[i]['level']}",
                          style: const TextStyle(color: Colors.purple))),
                  title: Text(_spells[i]['name'] ?? "Sort",
                      style: const TextStyle(color: Colors.white)),
                  subtitle: Text("Niveau ${_spells[i]['level']}",
                      style: const TextStyle(color: Colors.white54)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 👇 BOUTON LANCER (Visible seulement si en campagne)
                      if (widget.campaignId != null)
                        IconButton(
                            icon: const Icon(Icons.auto_awesome,
                                color: Colors.purple),
                            onPressed: () => _castSpell(_spells[i]['name'])),
                      if (widget.canEditSpellbook)
                        IconButton(
                            icon:
                                const Icon(Icons.delete, color: Colors.white70),
                            onPressed: () {
                              setState(() {
                                _spells.removeAt(i);
                                widget.character.setStat('spellbook', _spells);
                              });
                              widget.onSave();
                            }),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

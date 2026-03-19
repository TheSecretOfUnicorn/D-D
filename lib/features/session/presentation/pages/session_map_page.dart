import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/permissions/campaign_permission_policy.dart';
import '../../../../core/services/session_service.dart';
import '../../../bug_report/presentation/widgets/bug_report_action.dart';
import '../../../campaign_manager/data/models/campaign_model.dart';
import '../../../character_sheet/data/models/character_model.dart';
import '../../../character_sheet/data/repositories/character_repository_impl.dart';
import '../../../character_sheet/presentation/pages/character_sheet_page.dart';
import '../../../combat/presentation/pages/combat_page.dart';
import '../../../knowledge/presentation/pages/knowledge_page.dart';
import '../../../map_editor/presentation/pages/maps_list_page.dart';
import '../../../rules_engine/data/repositories/rules_repository_impl.dart';
import '../../data/models/session_state_model.dart';
import '../../data/repositories/session_repository.dart';
import 'session_runtime_page.dart';

class SessionMapPage extends StatefulWidget {
  final CampaignModel campaign;

  const SessionMapPage({
    super.key,
    required this.campaign,
  });

  @override
  State<SessionMapPage> createState() => _SessionMapPageState();
}

class _SessionMapPageState extends State<SessionMapPage> {
  final SessionRepository _sessionRepository = SessionRepository();
  final CharacterRepositoryImpl _characterRepository =
      CharacterRepositoryImpl();
  final RulesRepositoryImpl _rulesRepository = RulesRepositoryImpl();
  final SessionService _sessionService = SessionService();

  SessionStateModel? _sessionState;
  CharacterModel? _selectedCharacter;
  bool _isLoading = true;

  CampaignPermissionPolicy get _policy =>
      CampaignPermissionPolicy(_sessionState?.campaign ?? widget.campaign);

  List<Map<String, dynamic>> get _logs =>
      _sessionState?.logs.take(6).toList(growable: false) ?? const [];

  @override
  void initState() {
    super.initState();
    _sessionService.setActiveCampaignId(widget.campaign.id);
    _loadSession();
  }

  Future<void> _loadSession() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    final results = await Future.wait<dynamic>([
      _sessionRepository.loadState(widget.campaign),
      _loadSelectedCharacter(),
    ]);

    if (!mounted) return;
    setState(() {
      _sessionState = results[0] as SessionStateModel;
      _selectedCharacter = results[1] as CharacterModel?;
      _isLoading = false;
    });
  }

  Future<CharacterModel?> _loadSelectedCharacter() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'campaign_${widget.campaign.id}_char';
    final charId = prefs.getString(key);
    if (charId == null) return null;
    return _characterRepository.getCharacter(charId);
  }

  Future<void> _openRuntime() async {
    final state = _sessionState;
    if (state == null || !state.hasActiveMap) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SessionRuntimePage(
          campaign: state.campaign,
          mapId: state.activeMapId!,
        ),
      ),
    );

    await _loadSession();
  }

  Future<void> _openMapsManager() async {
    if (!_policy.canOpenMapEditor) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapsListPage(
          campaignId: widget.campaign.id,
          isGM: true,
        ),
      ),
    );

    await _loadSession();
  }

  Future<void> _openCombatPage() async {
    if (!_policy.canOpenCombatPage) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CombatPage(
          campaignId: widget.campaign.id,
          isGM: _policy.canManageCombat,
        ),
      ),
    );

    await _loadSession();
  }

  Future<void> _openKnowledgePage() async {
    final state = _sessionState;
    if (state == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KnowledgePage(
          campaign: state.campaign,
          title: "Connaissances de session",
        ),
      ),
    );

    await _loadSession();
  }

  Future<void> _openCharacterSheet() async {
    final character = _selectedCharacter;
    if (character == null) return;

    final rules = await _rulesRepository.loadDefaultRules();
    if (!mounted) return;

    final freshCharacter =
        await _characterRepository.getCharacter(character.id);
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CharacterSheetPage(
          character: freshCharacter ?? character,
          rules: rules,
          campaignId: widget.campaign.id,
        ),
      ),
    );

    await _loadSession();
  }

  String _formatLogTitle(Map<String, dynamic> log) {
    final type = (log['type'] ?? 'MSG').toString().toUpperCase();
    switch (type) {
      case 'DICE':
        return "Jet de des";
      case 'SYSTEM':
        return "Evenement systeme";
      default:
        return (log['content'] ?? '').toString();
    }
  }

  String _formatLogMeta(Map<String, dynamic> log) {
    final author =
        (log['username'] ?? log['author_name'] ?? 'Inconnu').toString();
    final createdAtRaw = log['created_at']?.toString();
    if (createdAtRaw == null) return author;

    final createdAt = DateTime.tryParse(createdAtRaw)?.toLocal();
    if (createdAt == null) return author;
    final hh = createdAt.hour.toString().padLeft(2, '0');
    final mm = createdAt.minute.toString().padLeft(2, '0');
    return "$author • $hh:$mm";
  }

  Color _logAccent(Map<String, dynamic> log) {
    switch ((log['type'] ?? 'MSG').toString().toUpperCase()) {
      case 'DICE':
        return const Color(0xFFD9A441);
      case 'SYSTEM':
        return const Color(0xFFB23A48);
      default:
        return const Color(0xFF6D9DC5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _sessionState;
    if (_isLoading || state == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final combatLabel = state.combatActive
        ? (state.combatParticipants == 0
            ? "Combat actif sans participant"
            : "${state.combatParticipants} participants • Round ${state.combatRound}")
        : "Exploration";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Table de session"),
        actions: [
          BugReportActionButton(
            sourcePage: "session_map",
            campaignId: widget.campaign.id,
            characterId: _selectedCharacter?.id,
            extraContext: {
              'has_active_map': state.hasActiveMap,
              'combat_active': state.combatActive,
            },
          ),
          IconButton(
            tooltip: "Rafraichir",
            onPressed: _loadSession,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSession,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SessionHeroCard(
              campaign: state.campaign,
              policy: _policy,
              combatLabel: combatLabel,
              hasActiveMap: state.hasActiveMap,
            ),
            const SizedBox(height: 16),
            _SessionMapCard(
              activeMapName: state.activeMapName,
              activeMapWidth: state.activeMapWidth,
              activeMapHeight: state.activeMapHeight,
              hasActiveMap: state.hasActiveMap,
              isGM: _policy.isGM,
              onEnterRuntime: state.hasActiveMap ? _openRuntime : null,
              onManageMaps: _policy.canOpenMapEditor ? _openMapsManager : null,
            ),
            const SizedBox(height: 16),
            if (_policy.isPlayer || _selectedCharacter != null)
              _SessionCharacterCard(
                character: _selectedCharacter,
                canOpenSheet: _selectedCharacter != null,
                onOpenSheet:
                    _selectedCharacter != null ? _openCharacterSheet : null,
              ),
            if (_policy.isPlayer || _selectedCharacter != null)
              const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (_policy.canOpenCombatPage)
                  _SessionActionButton(
                    icon: Icons.sports_kabaddi,
                    label: "Combat",
                    color: state.combatActive
                        ? const Color(0xFFB23A48)
                        : const Color(0xFF9F7E46),
                    onTap: _openCombatPage,
                  ),
                _SessionActionButton(
                  icon: Icons.book,
                  label: "Connaissances",
                  color: const Color(0xFF8D6E63),
                  onTap: _openKnowledgePage,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              "Flux de session",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            _SessionFeedCard(
              logs: _logs,
              formatTitle: _formatLogTitle,
              formatMeta: _formatLogMeta,
              accentFor: _logAccent,
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionHeroCard extends StatelessWidget {
  final CampaignModel campaign;
  final CampaignPermissionPolicy policy;
  final String combatLabel;
  final bool hasActiveMap;

  const _SessionHeroCard({
    required this.campaign,
    required this.policy,
    required this.combatLabel,
    required this.hasActiveMap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            campaign.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            policy.isGM
                ? "Espace de conduite de session. Tu arbitres la carte active et l'etat du combat."
                : "Espace de jeu. La session est centree sur la carte active et le flux commun.",
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SessionStatusChip(
                label: policy.isGM ? "Mode MJ" : "Mode joueur",
                color: policy.isGM
                    ? const Color(0xFFB23A48)
                    : const Color(0xFF6D9DC5),
              ),
              _SessionStatusChip(
                label: combatLabel,
                color: const Color(0xFFD9A441),
              ),
              _SessionStatusChip(
                label: hasActiveMap ? "Carte active" : "Aucune carte active",
                color: hasActiveMap
                    ? const Color(0xFF6C8A4D)
                    : const Color(0xFF8D6E63),
              ),
              _SessionStatusChip(
                label: campaign.allowDice ? "Des actifs" : "Des verrouilles",
                color:
                    campaign.allowDice ? const Color(0xFFD9A441) : Colors.grey,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionMapCard extends StatelessWidget {
  final String? activeMapName;
  final int? activeMapWidth;
  final int? activeMapHeight;
  final bool hasActiveMap;
  final bool isGM;
  final VoidCallback? onEnterRuntime;
  final VoidCallback? onManageMaps;

  const _SessionMapCard({
    required this.activeMapName,
    required this.activeMapWidth,
    required this.activeMapHeight,
    required this.hasActiveMap,
    required this.isGM,
    this.onEnterRuntime,
    this.onManageMaps,
  });

  @override
  Widget build(BuildContext context) {
    final sizeLabel = activeMapWidth != null && activeMapHeight != null
        ? "$activeMapWidth" "x$activeMapHeight cases"
        : "Dimensions inconnues";

    return Card(
      color: const Color(0xFF1B1B1B),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.map_outlined, color: Color(0xFFFFD700)),
                SizedBox(width: 10),
                Text(
                  "Carte de session",
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              hasActiveMap
                  ? (activeMapName ?? "Carte active sans nom")
                  : "Aucune carte active",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              hasActiveMap
                  ? sizeLabel
                  : (isGM
                      ? "Active une carte avant de lancer la session."
                      : "Le MJ n'a active aucune carte pour le moment."),
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: onEnterRuntime,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text("Entrer sur la carte"),
                ),
                if (onManageMaps != null)
                  OutlinedButton.icon(
                    onPressed: onManageMaps,
                    icon: const Icon(Icons.edit_location_alt),
                    label: const Text("Gerer les cartes"),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCharacterCard extends StatelessWidget {
  final CharacterModel? character;
  final bool canOpenSheet;
  final VoidCallback? onOpenSheet;

  const _SessionCharacterCard({
    required this.character,
    required this.canOpenSheet,
    this.onOpenSheet,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1B1B1B),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.badge_outlined, color: Color(0xFFFFD700)),
                SizedBox(width: 10),
                Text(
                  "Personnage actif",
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (character == null)
              const Text(
                "Aucun personnage actif pour cette campagne. Choisis-en un depuis la page campagne.",
                style: TextStyle(color: Colors.white70),
              )
            else ...[
              Text(
                character!.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                "Niveau ${character!.getStat<int>('level', 1)} • PV ${character!.getStat<int>('hp_current', 10)}/${character!.getStat<int>('hp_max', 10)} • CA ${character!.getStat<int>('ac', 10)}",
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: canOpenSheet ? onOpenSheet : null,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text("Ouvrir la fiche"),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SessionActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _SessionActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: FilledButton.tonalIcon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.16),
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

class _SessionFeedCard extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  final String Function(Map<String, dynamic>) formatTitle;
  final String Function(Map<String, dynamic>) formatMeta;
  final Color Function(Map<String, dynamic>) accentFor;

  const _SessionFeedCard({
    required this.logs,
    required this.formatTitle,
    required this.formatMeta,
    required this.accentFor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: logs.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                "Aucun evenement de session pour le moment.",
                style: TextStyle(color: Colors.white54),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(14),
              itemCount: logs.length,
              separatorBuilder: (_, __) =>
                  const Divider(color: Colors.white10, height: 12),
              itemBuilder: (context, index) {
                final log = logs[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: accentFor(log),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatTitle(log),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatMeta(log),
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
    );
  }
}

class _SessionStatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _SessionStatusChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

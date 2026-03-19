import 'dart:async';

import 'package:flutter/material.dart';

import '../../../campaign_manager/data/repositories/campaign_repository.dart';
import '../../data/models/combatant_model.dart';

class CombatPage extends StatefulWidget {
  final int campaignId;
  final bool isGM;

  const CombatPage({
    super.key,
    required this.campaignId,
    required this.isGM,
  });

  @override
  State<CombatPage> createState() => _CombatPageState();
}

class _CombatPageState extends State<CombatPage> {
  final CampaignRepository _repo = CampaignRepository();

  List<CombatantModel> _participants = [];
  List<Map<String, dynamic>> _members = [];
  bool _isActive = false;
  bool _isLoading = true;
  bool _isStartingCombat = false;
  int _currentRound = 1;
  int _turnIndex = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadCombatState();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _loadCombatState(showLoader: false),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCombatState({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() => _isLoading = true);
    }

    final combat = await _repo.getCombatDetails(widget.campaignId);
    final members = await _repo.getMembers(widget.campaignId);
    if (!mounted) return;

    final active = combat['active'] == true;
    final participants = active && combat['participants'] is List
        ? (combat['participants'] as List)
            .map((json) =>
                CombatantModel.fromJson(Map<String, dynamic>.from(json)))
            .toList()
        : <CombatantModel>[];
    final encounter = combat['encounter'] as Map<String, dynamic>?;

    setState(() {
      _isActive = active;
      _participants = participants;
      _members = members;
      _currentRound = encounter?['round'] ?? 1;
      _turnIndex = encounter?['current_turn_index'] ?? 0;
      _isLoading = false;
    });
  }

  Future<void> _startCombat() async {
    if (!widget.isGM) return;
    if (_isStartingCombat) return;
    setState(() => _isStartingCombat = true);

    final success = await _repo.startCombat(widget.campaignId);
    if (!mounted) return;

    setState(() => _isStartingCombat = false);
    await _loadCombatState(showLoader: false);
    if (!mounted) return;

    if (_isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _participants.isEmpty
                ? "Initiative lancee, mais aucun participant n'a ete ajoute au combat."
                : "Initiative lancee.",
          ),
          backgroundColor: _participants.isEmpty
              ? const Color(0xFFD9A441)
              : const Color(0xFF2E7D32),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? "Le serveur n'a pas active le combat. Verifie que les joueurs ont bien un personnage associe."
              : "Impossible de lancer le combat.",
        ),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Future<void> _nextTurn() async {
    if (!widget.isGM) return;
    final success = await _repo.nextTurn(widget.campaignId);
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossible de passer au tour suivant."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    await _loadCombatState(showLoader: false);
  }

  Future<void> _stopCombat() async {
    if (!widget.isGM) return;
    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Fin du combat ?"),
            content: const Text(
                "Cela effacera l'initiative et remettra la table en exploration."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Annuler"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  "Finir",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    final success = await _repo.stopCombat(widget.campaignId);
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossible de finir le combat."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    Navigator.pop(context);
  }

  Future<void> _showAddMonsterDialog() async {
    if (!widget.isGM) return;
    final nameCtrl = TextEditingController();
    final hpCtrl = TextEditingController(text: "10");
    final initCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Ajouter un ennemi"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "Nom"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: hpCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "PV max"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: initCtrl,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: "Initiative (optionnel)"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final hp = int.tryParse(hpCtrl.text) ?? 10;
              final init = int.tryParse(initCtrl.text);
              final success = await _repo.addParticipant(
                widget.campaignId,
                nameCtrl.text.trim(),
                hp,
                init,
              );

              if (!ctx.mounted) return;
              Navigator.pop(ctx);

              if (!mounted) return;
              if (!success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Impossible d'ajouter l'ennemi."),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }

              await _loadCombatState(showLoader: false);
            },
            child: const Text("Ajouter"),
          ),
        ],
      ),
    );
  }

  Future<void> _editParticipant(CombatantModel participant) async {
    if (!widget.isGM) return;

    final hpCtrl =
        TextEditingController(text: participant.hpCurrent.toString());
    final initCtrl =
        TextEditingController(text: participant.initiative.toString());

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Modifier ${participant.name}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: initCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Initiative"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: hpCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "PV actuels"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () async {
              final newInit =
                  int.tryParse(initCtrl.text) ?? participant.initiative;
              final newHp = (int.tryParse(hpCtrl.text) ?? participant.hpCurrent)
                  .clamp(0, participant.hpMax);
              final success = await _repo.updateParticipant(
                widget.campaignId,
                participant.id,
                {
                  "initiative": newInit,
                  "hp_current": newHp,
                },
              );

              if (!ctx.mounted) return;
              Navigator.pop(ctx);

              if (!mounted) return;
              if (!success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Impossible de modifier ce participant."),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }

              await _loadCombatState(showLoader: false);
            },
            child: const Text("Valider"),
          ),
        ],
      ),
    );
  }

  Future<void> _applyHpDelta(CombatantModel participant, int delta) async {
    if (!widget.isGM) return;
    final nextHp = (participant.hpCurrent + delta).clamp(0, participant.hpMax);
    final success = await _repo.updateParticipant(
      widget.campaignId,
      participant.id,
      {"hp_current": nextHp},
    );
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "Impossible de mettre a jour les PV de ${participant.name}."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    await _loadCombatState(showLoader: false);
  }

  CombatantModel? get _activeParticipant {
    if (_participants.isEmpty) return null;
    if (_turnIndex < 0 || _turnIndex >= _participants.length) return null;
    return _participants[_turnIndex];
  }

  bool get _hasEmptyActiveCombat => _isActive && _participants.isEmpty;

  int get _readyMembersCount =>
      _members.where((member) => member['char_name'] != null).length;

  int get _unassignedMembersCount =>
      _members.where((member) => member['char_name'] == null).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isActive ? "Round $_currentRound" : "Combat Tracker"),
        centerTitle: true,
        actions: [
          if (widget.isGM && _isActive) ...[
            IconButton(
              icon: const Icon(Icons.skip_next,
                  color: Colors.greenAccent, size: 30),
              tooltip: "Tour suivant",
              onPressed: _nextTurn,
            ),
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined,
                  color: Colors.redAccent),
              tooltip: "Finir le combat",
              onPressed: _stopCombat,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCombatState,
          ),
        ],
      ),
      floatingActionButton: widget.isGM && _isActive
          ? FloatingActionButton.extended(
              onPressed: _showAddMonsterDialog,
              backgroundColor: Colors.red[800],
              icon: const Icon(Icons.smart_toy),
              label: const Text("Ennemi"),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isActive
              ? (_hasEmptyActiveCombat
                  ? _buildEmptyActiveCombat()
                  : _buildActiveCombat())
              : _buildPreparationView(),
    );
  }

  Widget _buildPreparationView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF252525),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Table en attente",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFD700),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Verifie que les joueurs ont bien choisi leur personnage avant de lancer l'initiative.",
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SummaryChip(
                    icon: Icons.groups,
                    label: "${_members.length} membres",
                    color: const Color(0xFF8D6E63),
                  ),
                  _SummaryChip(
                    icon: Icons.verified_user,
                    label: "$_readyMembersCount personnages prets",
                    color: const Color(0xFF6C8A4D),
                  ),
                  if (_unassignedMembersCount > 0)
                    _SummaryChip(
                      icon: Icons.warning_amber,
                      label: "$_unassignedMembersCount sans personnage",
                      color: const Color(0xFFB23A48),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              if (widget.isGM)
                ElevatedButton.icon(
                  onPressed: _isStartingCombat ? null : _startCombat,
                  icon: _isStartingCombat
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(
                    _isStartingCombat ? "Lancement..." : "Lancer l'initiative",
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          "Roster de campagne",
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        if (_members.isEmpty)
          const Card(
            color: Color(0xFF252525),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                "Aucun membre de campagne trouve.",
                style: TextStyle(color: Colors.white70),
              ),
            ),
          )
        else
          ..._members.map(_buildMemberCard),
      ],
    );
  }

  Widget _buildActiveCombat() {
    final activeParticipant = _activeParticipant;

    return RefreshIndicator(
      onRefresh: _loadCombatState,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF252525),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.sports_kabaddi, color: Color(0xFFFFD700)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Round $_currentRound",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFFD700),
                        ),
                      ),
                    ),
                    Text(
                      "${_participants.length} participants",
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (activeParticipant != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1B1B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              const Color(0xFFFFD700).withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: activeParticipant.isNpc
                              ? Colors.red[800]
                              : const Color(0xFF6D9DC5),
                          foregroundColor: Colors.white,
                          child: Text(activeParticipant.initiative.toString()),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Tour actif",
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 12),
                              ),
                              Text(
                                activeParticipant.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.isGM)
                          ElevatedButton.icon(
                            onPressed: _nextTurn,
                            icon: const Icon(Icons.skip_next),
                            label: const Text("Suivant"),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ..._participants.asMap().entries.map(
                (entry) =>
                    _buildParticipantCard(entry.value, entry.key == _turnIndex),
              ),
        ],
      ),
    );
  }

  Widget _buildEmptyActiveCombat() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF252525),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: const Color(0xFFB23A48).withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.warning_amber, color: Color(0xFFFFD700)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Combat lance, mais table vide",
                      style: TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                "Le combat est bien passe en etat actif, mais aucun participant n'a ete injecte dans l'ordre d'initiative.",
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SummaryChip(
                    icon: Icons.groups,
                    label: "${_members.length} membres campagne",
                    color: const Color(0xFF8D6E63),
                  ),
                  _SummaryChip(
                    icon: Icons.verified_user,
                    label: "$_readyMembersCount personnages associes",
                    color: const Color(0xFF6C8A4D),
                  ),
                  _SummaryChip(
                    icon: Icons.warning_amber,
                    label: "$_unassignedMembersCount sans personnage",
                    color: const Color(0xFFB23A48),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (widget.isGM)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _showAddMonsterDialog,
                      icon: const Icon(Icons.smart_toy),
                      label: const Text("Ajouter un ennemi"),
                    ),
                    OutlinedButton.icon(
                      onPressed: _loadCombatState,
                      icon: const Icon(Icons.refresh),
                      label: const Text("Recharger"),
                    ),
                    OutlinedButton.icon(
                      onPressed: _stopCombat,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text("Fermer ce combat"),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          "Composition attendue",
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        if (_members.isEmpty)
          const Card(
            color: Color(0xFF252525),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                "Aucun membre de campagne trouve.",
                style: TextStyle(color: Colors.white70),
              ),
            ),
          )
        else
          ..._members.map(_buildMemberCard),
      ],
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final charName = member['char_name']?.toString();
    final username = member['username']?.toString() ?? 'Inconnu';
    final role = member['role']?.toString() ?? '';
    final isReady = charName != null && charName.isNotEmpty;

    return Card(
      color: const Color(0xFF252525),
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              isReady ? const Color(0xFF6C8A4D) : const Color(0xFF8B0000),
          child: Icon(isReady ? Icons.shield : Icons.help_outline,
              color: Colors.white),
        ),
        title: Text(
          charName ?? username,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          isReady
              ? [username, if (role.isNotEmpty) role].join(' • ')
              : "$username • personnage non selectionne",
          style: const TextStyle(color: Colors.white54),
        ),
        trailing: Text(
          isReady ? "Pret" : "En attente",
          style: TextStyle(
            color: isReady ? const Color(0xFFFFD700) : Colors.redAccent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantCard(CombatantModel participant, bool isTurn) {
    final healthRatio = participant.hpMax <= 0
        ? 0.0
        : participant.hpCurrent / participant.hpMax;
    final healthColor = healthRatio <= 0.25
        ? Colors.redAccent
        : healthRatio <= 0.6
            ? const Color(0xFFD9A441)
            : const Color(0xFF6C8A4D);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTurn ? const Color(0xFFFFD700) : Colors.white10,
          width: isTurn ? 2 : 1,
        ),
        boxShadow: isTurn
            ? [
                const BoxShadow(
                  color: Color(0x40FFD700),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : const [],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: participant.isNpc
                      ? Colors.red[800]
                      : const Color(0xFF6D9DC5),
                  foregroundColor: Colors.white,
                  child: participant.isNpc
                      ? const Icon(Icons.smart_toy)
                      : Text(
                          participant.initiative.toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        participant.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MiniTag(
                            label:
                                participant.isNpc ? "PNJ / Monstre" : "Joueur",
                            color: participant.isNpc
                                ? Colors.redAccent
                                : const Color(0xFF6D9DC5),
                          ),
                          _MiniTag(
                            label: "Init ${participant.initiative}",
                            color: const Color(0xFFD9A441),
                          ),
                          _MiniTag(
                            label: "CA ${participant.ac}",
                            color: const Color(0xFF8D6E63),
                          ),
                          if (isTurn)
                            const _MiniTag(
                              label: "Tour actif",
                              color: Color(0xFFFFD700),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (widget.isGM)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white70),
                    onPressed: () => _editParticipant(participant),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: healthRatio,
              color: healthColor,
              backgroundColor: Colors.white12,
              minHeight: 10,
              borderRadius: BorderRadius.circular(999),
            ),
            const SizedBox(height: 6),
            Text(
              "${participant.hpCurrent} / ${participant.hpMax} PV",
              style: const TextStyle(color: Colors.white70),
            ),
            if (widget.isGM) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HpActionButton(
                    label: "-5 PV",
                    color: Colors.redAccent,
                    onTap: () => _applyHpDelta(participant, -5),
                  ),
                  _HpActionButton(
                    label: "-1 PV",
                    color: const Color(0xFFB23A48),
                    onTap: () => _applyHpDelta(participant, -1),
                  ),
                  _HpActionButton(
                    label: "+1 PV",
                    color: const Color(0xFF6C8A4D),
                    onTap: () => _applyHpDelta(participant, 1),
                  ),
                  _HpActionButton(
                    label: "+5 PV",
                    color: const Color(0xFF2E7D32),
                    onTap: () => _applyHpDelta(participant, 5),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SummaryChip({
    required this.icon,
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
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniTag({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HpActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _HpActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(label),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/permissions/campaign_permission_policy.dart';
import '../../../campaign_manager/data/models/campaign_model.dart';
import '../../../campaign_manager/data/repositories/campaign_repository.dart';
import '../../data/models/knowledge_entry_model.dart';
import '../../data/repositories/knowledge_repository.dart';

class KnowledgePage extends StatefulWidget {
  final CampaignModel campaign;
  final String title;

  const KnowledgePage({
    super.key,
    required this.campaign,
    this.title = "Journal et connaissances",
  });

  @override
  State<KnowledgePage> createState() => _KnowledgePageState();
}

class _KnowledgePageState extends State<KnowledgePage> {
  final KnowledgeRepository _knowledgeRepository = KnowledgeRepository();
  final CampaignRepository _campaignRepository = CampaignRepository();

  List<KnowledgeEntryModel> _entries = const [];
  List<Map<String, dynamic>> _members = const [];
  bool _isLoading = true;

  CampaignPermissionPolicy get _policy =>
      CampaignPermissionPolicy(widget.campaign);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait<dynamic>([
      _knowledgeRepository.fetchEntries(widget.campaign.id),
      _policy.canManageKnowledgeVisibility
          ? _campaignRepository.getMembers(widget.campaign.id)
          : Future.value(const <Map<String, dynamic>>[]),
    ]);

    if (!mounted) return;
    setState(() {
      _entries = (results[0] as List)
          .cast<KnowledgeEntryModel>()
          .toList(growable: false);
      _members = (results[1] as List)
          .cast<Map<String, dynamic>>()
          .toList(growable: false);
      _isLoading = false;
    });
  }

  Map<int, String> get _memberLabelsByUserId {
    final labels = <int, String>{};
    for (final member in _members) {
      final userId = int.tryParse(member['user_id'].toString());
      if (userId == null) continue;

      final username = member['username']?.toString().trim();
      final characterName = member['char_name']?.toString().trim();
      final fallbackLabel =
          username != null && username.isNotEmpty ? username : "Joueur $userId";
      labels[userId] = characterName != null && characterName.isNotEmpty
          ? "$characterName ($fallbackLabel)"
          : fallbackLabel;
    }
    return labels;
  }

  Future<void> _openEntryDialog({KnowledgeEntryModel? entry}) async {
    final titleController = TextEditingController(text: entry?.title ?? "");
    final contentController = TextEditingController(text: entry?.content ?? "");
    var visibility = entry?.visibility ?? KnowledgeVisibility.mjOnly;
    final selectedTargets = entry?.sharedWith.toSet() ?? <int>{};

    try {
      await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(
              entry == null ? "Nouvelle connaissance" : "Visibilite et partage",
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    readOnly: entry != null,
                    decoration: const InputDecoration(
                      labelText: "Titre",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: contentController,
                    maxLines: 5,
                    readOnly: entry != null,
                    decoration: const InputDecoration(
                      labelText: "Contenu",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (entry != null) ...[
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Le contenu reste en lecture seule ici. Seul le partage est modifie.",
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  DropdownButtonFormField<KnowledgeVisibility>(
                    initialValue: visibility,
                    decoration: const InputDecoration(
                      labelText: "Visibilite",
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: KnowledgeVisibility.group,
                        child: Text("Connu du groupe"),
                      ),
                      DropdownMenuItem(
                        value: KnowledgeVisibility.targeted,
                        child: Text("Ciblee"),
                      ),
                      DropdownMenuItem(
                        value: KnowledgeVisibility.mjOnly,
                        child: Text("Secret MJ"),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => visibility = value);
                    },
                  ),
                  if (visibility == KnowledgeVisibility.targeted) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Joueurs cibles",
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._members
                        .where((member) => member['role'] != 'GM')
                        .map((member) {
                      final userId = int.tryParse(member['user_id'].toString());
                      if (userId == null) return const SizedBox.shrink();
                      final isSelected = selectedTargets.contains(userId);
                      return CheckboxListTile(
                        value: isSelected,
                        title:
                            Text(member['username']?.toString() ?? 'Inconnu'),
                        subtitle: Text(member['char_name']?.toString() ??
                            "Sans personnage"),
                        onChanged: (value) {
                          setDialogState(() {
                            if (value == true) {
                              selectedTargets.add(userId);
                            } else {
                              selectedTargets.remove(userId);
                            }
                          });
                        },
                      );
                    }),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Annuler"),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.trim().isEmpty) return;

                  final targets = selectedTargets.toList(growable: false);
                  if (visibility == KnowledgeVisibility.targeted &&
                      targets.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Selectionne au moins un destinataire pour une connaissance ciblee.",
                        ),
                        backgroundColor: Colors.orangeAccent,
                      ),
                    );
                    return;
                  }

                  final success = entry == null
                      ? await _knowledgeRepository.createEntry(
                          widget.campaign.id,
                          title: titleController.text.trim(),
                          content: contentController.text.trim(),
                          visibility: visibility,
                          sharedWith: targets,
                        )
                      : await _knowledgeRepository.updateVisibility(
                          entry.id,
                          visibility: visibility,
                          sharedWith: targets,
                        );

                  if (!mounted || !ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (success) {
                    await _loadData();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            "Impossible d'enregistrer cette connaissance."),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                },
                child: Text(entry == null ? "Creer" : "Appliquer"),
              ),
            ],
          ),
        ),
      );
    } finally {
      titleController.dispose();
      contentController.dispose();
    }
  }

  Future<void> _deleteEntry(int entryId) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Supprimer ?"),
            content: const Text("Cette action est irreversible."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Annuler"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Supprimer",
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    final success = await _knowledgeRepository.deleteEntry(entryId);
    if (!mounted) return;
    if (success) {
      await _loadData();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Suppression impossible."),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  List<String> _targetLabelsForEntry(KnowledgeEntryModel entry) {
    if (entry.sharedWith.isEmpty) return const [];

    final memberLabels = _memberLabelsByUserId;
    return entry.sharedWith
        .map((userId) => memberLabels[userId] ?? "Joueur $userId")
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final publicEntries = _entries
        .where((entry) => entry.visibility == KnowledgeVisibility.group)
        .toList(growable: false);
    final targetedEntries = _entries
        .where((entry) => entry.visibility == KnowledgeVisibility.targeted)
        .toList(growable: false);
    final mjEntries = _entries
        .where((entry) => entry.visibility == KnowledgeVisibility.mjOnly)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      floatingActionButton: _policy.canCreateKnowledgeEntry
          ? FloatingActionButton(
              onPressed: _openEntryDialog,
              child: const Icon(Icons.note_add),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _KnowledgeHeader(
                    isGM: _policy.isGM,
                    publicCount: publicEntries.length,
                    targetedCount: targetedEntries.length,
                    privateCount: mjEntries.length,
                  ),
                  const SizedBox(height: 16),
                  if (publicEntries.isNotEmpty) ...[
                    const _KnowledgeSectionTitle(
                      title: "Connu du groupe",
                      color: Color(0xFF8D6E63),
                    ),
                    const SizedBox(height: 8),
                    ...publicEntries.map(
                      (entry) => _KnowledgeEntryCard(
                        entry: entry,
                        isGM: _policy.isGM,
                        targetLabels: const [],
                        onEdit: () => _openEntryDialog(entry: entry),
                        onDelete: () => _deleteEntry(entry.id),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (targetedEntries.isNotEmpty) ...[
                    _KnowledgeSectionTitle(
                      title: _policy.isGM
                          ? "Notes ciblees"
                          : "Connaissances pour toi",
                      color: const Color(0xFF6D9DC5),
                    ),
                    const SizedBox(height: 8),
                    ...targetedEntries.map(
                      (entry) => _KnowledgeEntryCard(
                        entry: entry,
                        isGM: _policy.isGM,
                        targetLabels: _targetLabelsForEntry(entry),
                        onEdit: _policy.canManageKnowledgeVisibility
                            ? () => _openEntryDialog(entry: entry)
                            : null,
                        onDelete: _policy.canManageKnowledgeVisibility
                            ? () => _deleteEntry(entry.id)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_policy.isGM && mjEntries.isNotEmpty) ...[
                    const _KnowledgeSectionTitle(
                      title: "Secret MJ",
                      color: Color(0xFF8B0000),
                    ),
                    const SizedBox(height: 8),
                    ...mjEntries.map(
                      (entry) => _KnowledgeEntryCard(
                        entry: entry,
                        isGM: true,
                        targetLabels: const [],
                        onEdit: () => _openEntryDialog(entry: entry),
                        onDelete: () => _deleteEntry(entry.id),
                      ),
                    ),
                  ],
                  if (_entries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Center(
                        child: Text(
                          "Aucune connaissance pour le moment.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _KnowledgeHeader extends StatelessWidget {
  final bool isGM;
  final int publicCount;
  final int targetedCount;
  final int privateCount;

  const _KnowledgeHeader({
    required this.isGM,
    required this.publicCount,
    required this.targetedCount,
    required this.privateCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _CountChip(
              label: "$publicCount groupe", color: const Color(0xFF8D6E63)),
          _CountChip(
              label: "$targetedCount ciblees", color: const Color(0xFF6D9DC5)),
          if (isGM)
            _CountChip(
                label: "$privateCount secretes",
                color: const Color(0xFF8B0000)),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final Color color;

  const _CountChip({
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
      child: Text(label, style: const TextStyle(color: Colors.white)),
    );
  }
}

class _KnowledgeSectionTitle extends StatelessWidget {
  final String title;
  final Color color;

  const _KnowledgeSectionTitle({
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

class _KnowledgeEntryCard extends StatelessWidget {
  final KnowledgeEntryModel entry;
  final bool isGM;
  final List<String> targetLabels;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _KnowledgeEntryCard({
    required this.entry,
    required this.isGM,
    this.targetLabels = const [],
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final createdAt =
        "${entry.createdAt.day.toString().padLeft(2, '0')}/${entry.createdAt.month.toString().padLeft(2, '0')}/${entry.createdAt.year}";
    final targetSummary = targetLabels.join(', ');

    return Card(
      color: const Color(0xFFFDF6E3),
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: const Icon(Icons.article, color: Colors.brown),
        title: Text(
          entry.title,
          style: TextStyle(
            color: Colors.brown[900],
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              createdAt,
              style: TextStyle(color: Colors.brown[700]),
            ),
            if (isGM && targetSummary.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                "Destinataires: $targetSummary",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.brown[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        trailing: isGM
            ? PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit' && onEdit != null) onEdit!();
                  if (value == 'delete' && onDelete != null) onDelete!();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text("Visibilite")),
                  PopupMenuItem(value: 'delete', child: Text("Supprimer")),
                ],
              )
            : null,
        children: [
          if (isGM && targetLabels.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Destinataires",
                      style: TextStyle(
                        color: Colors.brown[900],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: targetLabels
                          .map(
                            (label) => Chip(
                              label: Text(label),
                              backgroundColor: const Color(0xFFE7DEC6),
                              side: BorderSide.none,
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                entry.content.isEmpty ? "Aucun contenu." : entry.content,
                style: TextStyle(color: Colors.brown[900]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

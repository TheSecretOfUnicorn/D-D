import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../rules_engine/data/models/rule_system_model.dart';
import '../../data/models/character_model.dart';
import '../../data/repositories/character_repository_impl.dart';
import '../widgets/stat_input_widget.dart';
import '../widgets/dynamic_list_widget.dart';
import '../widgets/character_avatar.dart';
import '../../../../core/services/data_sharing_service.dart';

class CharacterSheetPage extends StatefulWidget {
  final CharacterModel character;
  final RuleSystemModel rules;

  const CharacterSheetPage({
    super.key,
    required this.character,
    required this.rules,
  });

  @override
  State<CharacterSheetPage> createState() => _CharacterSheetPageState();
}

class _CharacterSheetPageState extends State<CharacterSheetPage> {
  final CharacterRepositoryImpl _repo = CharacterRepositoryImpl();
  final DataSharingService _sharingService = DataSharingService();

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final newChar = CharacterModel(
        id: widget.character.id,
        name: widget.character.name,
        imagePath: image.path,
        stats: Map<String, dynamic>.from(widget.character.stats),
      );
      await _repo.saveCharacter(newChar);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, anim1, anim2) => CharacterSheetPage(character: newChar, rules: widget.rules),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      }
    }
  }

  StatDefinition? _getDef(String id) {
    try {
      return widget.rules.statDefinitions.firstWhere((e) => e.id == id);
    } catch (e) {
      return null;
    }
  }

  void _onStatChanged(String id, dynamic value) {
    widget.character.setStat(id, value);
    _repo.saveCharacter(widget.character);
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.copy), title: const Text("Copier le JSON"),
            onTap: () {
              _sharingService.copyToClipboard(widget.character);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copié !")));
            },
          ),
          ListTile(
            leading: const Icon(Icons.share), title: const Text("Partager le fichier"),
            onTap: () {
              _sharingService.shareCharacter(widget.character);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rules.layout == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.character.name)),
        body: const Center(child: Text("Erreur: Pas de 'layout' dans le fichier JSON.")),
      );
    }

    final layout = widget.rules.layout!;

    return DefaultTabController(
      length: layout.tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.character.name),
          actions: [
            IconButton(icon: const Icon(Icons.share), onPressed: _showExportOptions),
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: CharacterAvatar(imagePath: widget.character.imagePath, size: 20, onTap: _pickImage),
            ),
          ],
          bottom: TabBar(isScrollable: true, tabs: layout.tabs.map((t) => Tab(text: t)).toList()),
        ),
        body: TabBarView(
          children: layout.tabs.map((tabName) => _buildTabContent(tabName, layout)).toList(),
        ),
      ),
    );
  }

  Widget _buildTabContent(String tabName, LayoutDefinition layout) {
    final sections = layout.sections.where((s) => s.tab == tabName).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: sections.map((section) {
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(section.title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                const Divider(),
                ...section.contains.map((statId) {
                  final def = _getDef(statId);
                  if (def == null) return Text("Erreur ID: $statId", style: const TextStyle(color: Colors.red));

                  // CAS LISTE AVEC PRESETS (INVENTAIRE / SORTS)
                  if (def.type == 'list' && def.dataRef != null) {
                    final dataDefs = widget.rules.dataDefinitions[def.dataRef] ?? [];
                    final presets = widget.rules.library[def.id] ?? [];
                    final rawList = widget.character.getStat(statId);
                    final List<Map<String, dynamic>> items = (rawList is List) ? List<Map<String, dynamic>>.from(rawList) : [];

                    // ICI c'est corrigé : on utilise dataDefs et non itemStructure
                    return DynamicListWidget(
                      key: ValueKey(statId),
                      definition: def,
                      items: items,
                      dataDefs: dataDefs, // <--- Correction critique
                      presets: presets,
                      onChanged: (newList) => _onStatChanged(statId, newList),
                    );
                  }

                  // CAS SIMPLE
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: StatInputWidget(
                      key: ValueKey(statId),
                      definition: def,
                      currentValue: widget.character.getStat(statId),
                      onChanged: (val) => _onStatChanged(statId, val),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
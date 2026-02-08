import 'package:flutter/material.dart';
import '../../data/models/character_model.dart';
import '../../data/repositories/character_repository_impl.dart';
import '../../../rules_engine/data/models/rule_system_model.dart';

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

class _CharacterSheetPageState extends State<CharacterSheetPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CharacterRepositoryImpl _repo = CharacterRepositoryImpl();
  
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _raceController;

  @override
  void initState() {
    super.initState();
    // On ajoute 2 onglets : Inventaire et Sorts
    _tabController = TabController(length: 4, vsync: this);
    
    _nameController = TextEditingController(text: widget.character.name);
    _bioController = TextEditingController(text: widget.character.getStat<String>('bio', ''));
    _raceController = TextEditingController(text: widget.character.getStat<String>('race', ''));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    _raceController.dispose();
    super.dispose();
  }

  void _saveChanges() async {
    widget.character.name = _nameController.text;
    widget.character.setStat('bio', _bioController.text);
    widget.character.setStat('race', _raceController.text);

    try {
      await _repo.saveCharacter(widget.character);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Sauvegardé !"), duration: Duration(milliseconds: 500)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur save: $e")));
      }
    }
  }

  void _updateStat(String key, dynamic value) {
    setState(() {
      widget.character.setStat(key, value);
    });
    _saveChanges();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _nameController,
          style: const TextStyle(color: Colors.white, fontSize: 20),
          decoration: const InputDecoration(border: InputBorder.none, hintText: "Nom du personnage"),
          onSubmitted: (_) => _saveChanges(),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true, // Permet de scroller si les onglets sont nombreux
          tabs: const [
            Tab(icon: Icon(Icons.bar_chart), text: "Stats"),
            Tab(icon: Icon(Icons.person), text: "Bio"),
            Tab(icon: Icon(Icons.backpack), text: "Inventaire"),
            Tab(icon: Icon(Icons.auto_fix_high), text: "Sorts"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStatsTab(),
          _buildBioTab(),
          _buildPlaceholderTab("Inventaire"),
          _buildPlaceholderTab("Livre de Sorts"),
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    final List<String> statsList = widget.rules.stats; 

    if (statsList.isEmpty) {
      return const Center(child: Text("Aucune statistique définie."));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text("Caractéristiques", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
        const Divider(),
        ...statsList.map((statId) {
          final int currentValue = widget.character.getStat<int>(statId, 10);
          final int modifier = ((currentValue - 10) / 2).floor();
          final String modSign = modifier >= 0 ? "+" : "";

          // --- CORRECTION DU NOM ---
          // On utilise getStatName pour avoir "Force" au lieu de "str"
          final String displayName = widget.rules.getStatName(statId);

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("Modif: $modSign$modifier"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => _updateStat(statId, currentValue - 1),
                  ),
                  Container(
                    width: 40,
                    alignment: Alignment.center,
                    child: Text("$currentValue", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => _updateStat(statId, currentValue + 1),
                  ),
                ],
              ),
            ),
          );
        }).toList(),

        const SizedBox(height: 20),
        const Text("État", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
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
      child: ListTile(
        title: Text(label),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.remove), onPressed: () => _updateStat(key, val - 1)),
            Text("$val", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.add), onPressed: () => _updateStat(key, val + 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildBioTab() {
    final List<String> validClasses = widget.rules.classes;
    String? currentClass = widget.character.getStat<String?>('class', null);
    if (currentClass != null && !validClasses.contains(currentClass)) {
      currentClass = null;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Identité", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: currentClass,
            decoration: const InputDecoration(labelText: "Classe", border: OutlineInputBorder()),
            items: validClasses.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (val) => _updateStat('class', val),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _raceController,
            decoration: const InputDecoration(labelText: "Race", border: OutlineInputBorder()),
            onSubmitted: (_) => _saveChanges(),
          ),
          const SizedBox(height: 20),
          const Text("Biographie", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TextField(
            controller: _bioController,
            maxLines: 10,
            decoration: const InputDecoration(hintText: "L'histoire...", border: OutlineInputBorder()),
            onEditingComplete: _saveChanges,
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _saveChanges,
            icon: const Icon(Icons.save),
            label: const Text("Sauvegarder"),
          )
        ],
      ),
    );
  }

  // Placeholder pour Inventaire et Sorts (à remplacer par tes vraies pages)
  Widget _buildPlaceholderTab(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text("Module $title", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text("À connecter avec tes modules existants."),
        ],
      ),
    );
  }
}
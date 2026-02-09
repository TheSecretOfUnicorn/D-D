import 'package:flutter/material.dart';
import '../../data/models/character_model.dart';
import '../../data/repositories/character_repository_impl.dart';
import '../../../rules_engine/data/models/rule_system_model.dart';
import '../../../compendium/data/repositories/compendium_repository.dart';

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
  
  // --- Le Repo Compendium (Connecté au serveur Node.js) ---
  final CompendiumRepository _compendiumRepo = CompendiumRepository();
  
  // Listes dynamiques chargées depuis le serveur
  List<Map<String, dynamic>> _onlineItems = [];
  List<Map<String, dynamic>> _onlineSpells = [];
  bool _isLoadingCompendium = true;

  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _raceController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    _nameController = TextEditingController(text: widget.character.name);
    _bioController = TextEditingController(text: widget.character.getStat<String>('bio', ''));
    _raceController = TextEditingController(text: widget.character.getStat<String>('race', ''));

    // --- Chargement des données Cloud ---
    _loadCompendium();
  }

  Future<void> _loadCompendium() async {
    // On récupère tout le compendium (items et sorts) depuis l'API
    final data = await _compendiumRepo.fetchFullCompendium(null);
    
    if (mounted) {
      setState(() {
        _onlineItems = data['items']!;
        _onlineSpells = data['spells']!;
        _isLoadingCompendium = false;
      });
    }
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
          isScrollable: true,
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
          
          // --- Onglet Inventaire Connecté ---
          InventoryTab(
            character: widget.character, 
            availableItems: _onlineItems, // Passe la liste chargée du serveur
            isLoading: _isLoadingCompendium,
            onSave: _saveChanges
          ),
          
          // --- Onglet Sorts Connecté ---
          SpellbookTab(
            character: widget.character, 
            availableSpells: _onlineSpells, // Passe la liste chargée du serveur
            isLoading: _isLoadingCompendium,
            onSave: _saveChanges
          ),
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
}

// --- WIDGET INVENTAIRE OPTIMISÉ ---
class InventoryTab extends StatefulWidget {
  final CharacterModel character;
  final List<Map<String, dynamic>> availableItems; // Reçoit les données du serveur
  final bool isLoading;
  final VoidCallback onSave;

  const InventoryTab({
    super.key, 
    required this.character, 
    required this.availableItems, 
    required this.isLoading,
    required this.onSave
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

  void _addItem() {
    if (widget.isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chargement du compendium...")));
      return;
    }

    String selectedName = "";
    String selectedDesc = "";
    TextEditingController qtyCtrl = TextEditingController(text: "1");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Ajouter un objet"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Autocomplete<Map<String, dynamic>>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text == '') return const Iterable.empty();
                // Filtre la liste reçue du serveur
                return widget.availableItems.where((Map<String, dynamic> option) {
                  return option['name'].toString().toLowerCase()
                      .contains(textEditingValue.text.toLowerCase());
                });
              },
              displayStringForOption: (Map<String, dynamic> option) => option['name'],
              onSelected: (Map<String, dynamic> selection) {
                selectedName = selection['name'];
                selectedDesc = selection['desc'] ?? "";
              },
              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: "Nom de l'objet (Recherche...)",
                    suffixIcon: Icon(Icons.search),
                  ),
                  onChanged: (val) => selectedName = val,
                );
              },
            ),
            const SizedBox(height: 10),
            TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: "Quantité"), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
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

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      widget.character.setStat('inventory', _items);
    });
    widget.onSave();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        backgroundColor: Colors.brown,
        child: const Icon(Icons.add),
      ),
      body: _items.isEmpty
          ? const Center(child: Text("Sac à dos vide."))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: _items.length,
              itemBuilder: (ctx, i) {
                final item = _items[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.brown[100],
                      child: Text("${item['qty']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brown)),
                    ),
                    title: Text(item['name'] ?? "Objet inconnu"),
                    children: [
                      if (item['desc'] != null && item['desc'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(item['desc'], style: const TextStyle(fontStyle: FontStyle.italic)),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            label: const Text("Jeter", style: TextStyle(color: Colors.red)),
                            onPressed: () => _removeItem(i),
                          )
                        ],
                      )
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// --- WIDGET GRIMOIRE OPTIMISÉ ---
class SpellbookTab extends StatefulWidget {
  final CharacterModel character;
  final List<Map<String, dynamic>> availableSpells; // Reçoit les données du serveur
  final bool isLoading;
  final VoidCallback onSave;

  const SpellbookTab({
    super.key, 
    required this.character, 
    required this.availableSpells, 
    required this.isLoading, 
    required this.onSave
  });

  @override
  State<SpellbookTab> createState() => _SpellbookTabState();
}

class _SpellbookTabState extends State<SpellbookTab> {
  late List<dynamic> _spells;

  @override
  void initState() {
    super.initState();
    // 'spells' est la clé de sauvegarde dans le CharacterModel
    _spells = widget.character.getStat<List<dynamic>>('spells', []);
  }

  void _addSpell() {
    if (widget.isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chargement du compendium...")));
      return;
    }

    String selectedName = "";
    int selectedLevel = 0;
    TextEditingController levelCtrl = TextEditingController(text: "0");
    TextEditingController nameDisplayCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Apprendre un sort"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Autocomplete<Map<String, dynamic>>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text == '') return const Iterable.empty();
                // Filtre la liste reçue du serveur
                return widget.availableSpells.where((Map<String, dynamic> option) {
                  return option['name'].toString().toLowerCase()
                      .contains(textEditingValue.text.toLowerCase());
                });
              },
              displayStringForOption: (Map<String, dynamic> option) => option['name'],
              onSelected: (Map<String, dynamic> selection) {
                selectedName = selection['name'];
                selectedLevel = selection['level'] ?? 0;
                levelCtrl.text = selectedLevel.toString();
              },
              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                nameDisplayCtrl = textEditingController;
                return TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: "Nom du sort",
                    suffixIcon: Icon(Icons.auto_fix_high),
                  ),
                  onChanged: (val) => selectedName = val,
                );
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: levelCtrl, 
              decoration: const InputDecoration(labelText: "Niveau (0 = Cantrip)"), 
              keyboardType: TextInputType.number
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () {
              if (selectedName.isNotEmpty) {
                setState(() {
                  _spells.add({
                    'name': selectedName,
                    'level': int.tryParse(levelCtrl.text) ?? 0,
                    'prepared': false
                  });
                  widget.character.setStat('spells', _spells);
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
      floatingActionButton: FloatingActionButton(
        onPressed: _addSpell,
        backgroundColor: Colors.purple,
        child: const Icon(Icons.auto_fix_high),
      ),
      body: _spells.isEmpty
          ? const Center(child: Text("Grimoire vide."))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: _spells.length,
              itemBuilder: (ctx, i) {
                final spell = _spells[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.purple[100],
                      child: Text("${spell['level']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                    ),
                    title: Text(spell['name'] ?? "Sort inconnu"),
                    subtitle: Text(spell['level'] == 0 ? "Tour de magie" : "Niveau ${spell['level']}"),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.grey),
                      onPressed: () {
                        setState(() {
                          _spells.removeAt(i);
                          widget.character.setStat('spells', _spells);
                        });
                        widget.onSave();
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
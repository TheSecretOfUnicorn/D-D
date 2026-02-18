import 'dart:async';
import 'dart:math'; // Pour les jets de dés
import 'package:flutter/material.dart';

import '../../data/models/character_model.dart';
import '../../data/repositories/character_repository_impl.dart';
import '../../../rules_engine/data/models/rule_system_model.dart';
import '../../../compendium/data/repositories/compendium_repository.dart';
import '../../../compendium/presentation/pages/compendium_editor_page.dart';
// 👇 Import nécessaire pour parler au Chat
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

class _CharacterSheetPageState extends State<CharacterSheetPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CharacterRepositoryImpl _repo = CharacterRepositoryImpl();
  final CampaignRepository _campaignRepo = CampaignRepository(); // Pour envoyer les dés
  
  final CompendiumRepository _compendiumRepo = CompendiumRepository();
  List<Map<String, dynamic>> _onlineItems = [];
  List<Map<String, dynamic>> _onlineSpells = [];
  bool _isLoadingCompendium = true;

  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _raceController;

  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    _nameController = TextEditingController(text: widget.character.name);
    _bioController = TextEditingController(text: widget.character.getStat<String>('bio', ''));
    _raceController = TextEditingController(text: widget.character.getStat<String>('race', ''));

    _loadCompendium();
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

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _tabController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    _raceController.dispose();
    super.dispose();
  }

  void _saveChanges() async {
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
      await _repo.saveCharacter(charToSave);
      if (mounted) {
        // Discret en mode jeu, visible en mode édition
        if (widget.campaignId == null) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sauvegardé !"), duration: Duration(milliseconds: 500)));
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

  // 🔥 FONCTION CLÉ : Lancer un dé et l'envoyer au chat 🔥
  void _rollStat(String statName, int value) async {
    if (widget.campaignId == null) return; // Pas de campagne = pas de chat

    final mod = ((value - 10) / 2).floor();
    final d20 = Random().nextInt(20) + 1;
    final total = d20 + mod;
    
    final sign = mod >= 0 ? "+" : "";
    final msg = "a testé $statName ($sign$mod) : $total"; // ex: "a testé Force (+3) : 15"

    await _campaignRepo.sendLog(widget.campaignId!, msg, type: 'DICE', resultValue: total);
    
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
        title: TextField(
          controller: _nameController,
          style: const TextStyle(color: Colors.white, fontSize: 20),
          decoration: const InputDecoration(border: InputBorder.none, hintText: "Nom du personnage"),
          onSubmitted: (_) => _saveChanges(),
        ),
        actions: [
          // Raccourci MJ (visible seulement si on n'est PAS en mode jeu pour éviter la confusion)
          if (widget.campaignId == null)
            IconButton(
              icon: const Icon(Icons.library_add),
              onPressed: () async {
                final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CompendiumEditorPage()));
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
      body: TabBarView(
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
            campaignId: widget.campaignId, // On passe l'ID pour permettre l'utilisation
            campaignRepo: _campaignRepo,
          ),
          SpellbookTab(
            key: ValueKey(_onlineSpells.length),
            character: widget.character, 
            availableSpells: _onlineSpells,
            isLoading: _isLoadingCompendium,
            onSave: _saveChanges,
            campaignId: widget.campaignId,
            campaignRepo: _campaignRepo,
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
        const Text("Caractéristiques", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
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
              title: Text(displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text("Modif: $modSign$modifier", style: const TextStyle(color: Colors.white54)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 👇 LE BOUTON DE JEU (Seulement si en campagne)
                  if (widget.campaignId != null)
                    IconButton(
                      icon: const Icon(Icons.casino, color: Colors.deepOrange),
                      tooltip: "Lancer le dé",
                      onPressed: () => _rollStat(displayName, currentValue),
                    ),
                  
                  // Éditeurs (Petits boutons discrets)
                  SizedBox(
                    height: 30, width: 30,
                    child: IconButton(padding: EdgeInsets.zero, icon: const Icon(Icons.remove, size: 16, color: Colors.white70), onPressed: () => _updateStat(statId, currentValue - 1)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text("$currentValue", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  SizedBox(
                    height: 30, width: 30,
                    child: IconButton(padding: EdgeInsets.zero, icon: const Icon(Icons.add, size: 16, color: Colors.white70), onPressed: () => _updateStat(statId, currentValue + 1)),
                  ),
                ],
              ),
            ),
          );
        }),
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
      color: const Color(0xFF252525),
      child: ListTile(
        title: Text(label, style: const TextStyle(color: Colors.white)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.remove, color: Colors.white70), onPressed: () => _updateStat(key, val - 1)),
            Text("$val", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.add, color: Colors.white70), onPressed: () => _updateStat(key, val + 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildBioTab() {
    final List<String> validClasses = widget.rules.classes;
    String? currentClass = widget.character.getStat<String?>('class', null);
    if (currentClass != null && !validClasses.contains(currentClass)) currentClass = null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: currentClass,
            decoration: const InputDecoration(labelText: "Classe", border: OutlineInputBorder()),
            dropdownColor: const Color(0xFF333333),
            style: const TextStyle(color: Colors.white),
            items: validClasses.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (val) => _updateStat('class', val),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _raceController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: "Race", border: OutlineInputBorder()),
            onSubmitted: (_) => _saveChanges(),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _bioController,
            maxLines: 10,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: "Biographie / Notes", border: OutlineInputBorder()),
            onEditingComplete: _saveChanges,
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

  const InventoryTab({
    super.key, 
    required this.character, 
    required this.availableItems, 
    required this.isLoading, 
    required this.onSave, 
    this.campaignId, 
    this.campaignRepo
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Utilisé : $name"), duration: const Duration(seconds: 1)));
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
        title: const Text("Ajouter un objet", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Autocomplete<Map<String, dynamic>>(
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text == '') return const Iterable.empty();
                return widget.availableItems.where((o) => o['name'].toString().toLowerCase().contains(textEditingValue.text.toLowerCase()));
              },
              displayStringForOption: (o) => o['name'],
              onSelected: (s) { selectedName = s['name']; selectedDesc = s['desc'] ?? ""; },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) => TextField(
                controller: controller, focusNode: focusNode,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Nom de l'objet", suffixIcon: Icon(Icons.search, color: Colors.white70)),
                onChanged: (val) => selectedName = val,
              ),
            ),
            TextField(
              controller: qtyCtrl, 
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Quantité"), 
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
                  _items.add({'name': selectedName, 'qty': int.tryParse(qtyCtrl.text) ?? 1, 'desc': selectedDesc});
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
      floatingActionButton: FloatingActionButton(onPressed: _addItem, backgroundColor: Colors.brown, child: const Icon(Icons.add)),
      body: _items.isEmpty 
        ? const Center(child: Text("Sac à dos vide.", style: TextStyle(color: Colors.white54))) 
        : ListView.builder(
            itemCount: _items.length,
            itemBuilder: (ctx, i) => Card(
              color: const Color(0xFF252525),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ExpansionTile(
                leading: CircleAvatar(backgroundColor: Colors.brown[100], child: Text("${_items[i]['qty']}", style: const TextStyle(color: Colors.brown))),
                title: Text(_items[i]['name'] ?? "Objet", style: const TextStyle(color: Colors.white)),
                children: [
                  if (_items[i]['desc'] != null && _items[i]['desc'].toString().isNotEmpty) 
                    Padding(padding: const EdgeInsets.all(16), child: Text(_items[i]['desc'], style: const TextStyle(color: Colors.white70))),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    // 👇 BOUTON UTILISER (Visible seulement si en campagne)
                    if (widget.campaignId != null)
                      TextButton.icon(
                        icon: const Icon(Icons.touch_app, color: Colors.green), 
                        label: const Text("Utiliser"), 
                        onPressed: () => _useItem(_items[i]['name']),
                      ),
                    TextButton.icon(icon: const Icon(Icons.delete, color: Colors.red), label: const Text("Jeter"), onPressed: () {
                      setState(() { _items.removeAt(i); widget.character.setStat('inventory', _items); });
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

  const SpellbookTab({
    super.key, 
    required this.character, 
    required this.availableSpells, 
    required this.isLoading, 
    required this.onSave, 
    this.campaignId, 
    this.campaignRepo
  });

  @override
  State<SpellbookTab> createState() => _SpellbookTabState();
}

class _SpellbookTabState extends State<SpellbookTab> {
  late List<dynamic> _spells;

  @override
  void initState() {
    super.initState();
    _spells = widget.character.getStat<List<dynamic>>('spells', []);
  }

  // 👇 LOGIQUE DE LANCER DE SORT
  void _castSpell(String name) {
    if (widget.campaignId != null && widget.campaignRepo != null) {
      widget.campaignRepo!.sendLog(widget.campaignId!, "incante : $name ✨");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lancé : $name"), duration: const Duration(seconds: 1)));
    }
  }

  void _addSpell() {
    String selectedName = "";
    TextEditingController levelCtrl = TextEditingController(text: "0");
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: const Text("Apprendre un sort", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Autocomplete<Map<String, dynamic>>(
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text == '') return const Iterable.empty();
                return widget.availableSpells.where((o) => o['name'].toString().toLowerCase().contains(textEditingValue.text.toLowerCase()));
              },
              displayStringForOption: (o) => o['name'],
              onSelected: (s) { selectedName = s['name']; levelCtrl.text = (s['level'] ?? 0).toString(); },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) => TextField(
                controller: controller, focusNode: focusNode,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Nom du sort"),
                onChanged: (val) => selectedName = val,
              ),
            ),
            TextField(controller: levelCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Niveau"), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          ElevatedButton(onPressed: () {
            if (selectedName.isNotEmpty) {
              setState(() {
                _spells.add({'name': selectedName, 'level': int.tryParse(levelCtrl.text) ?? 0});
                widget.character.setStat('spells', _spells);
              });
              widget.onSave();
            }
            Navigator.pop(ctx);
          }, child: const Text("Ajouter")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(onPressed: _addSpell, backgroundColor: Colors.purple, child: const Icon(Icons.auto_fix_high)),
      body: _spells.isEmpty 
        ? const Center(child: Text("Grimoire vide.", style: TextStyle(color: Colors.white54))) 
        : ListView.builder(
            itemCount: _spells.length,
            itemBuilder: (ctx, i) => Card(
              color: const Color(0xFF252525),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: Colors.purple[100], child: Text("${_spells[i]['level']}", style: const TextStyle(color: Colors.purple))),
                title: Text(_spells[i]['name'] ?? "Sort", style: const TextStyle(color: Colors.white)),
                subtitle: Text("Niveau ${_spells[i]['level']}", style: const TextStyle(color: Colors.white54)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 👇 BOUTON LANCER (Visible seulement si en campagne)
                    if (widget.campaignId != null)
                      IconButton(
                        icon: const Icon(Icons.auto_awesome, color: Colors.purple), 
                        onPressed: () => _castSpell(_spells[i]['name'])
                      ),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.white70), onPressed: () {
                      setState(() { _spells.removeAt(i); widget.character.setStat('spells', _spells); });
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
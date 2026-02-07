import 'package:flutter/material.dart';
import '../../../rules_engine/data/repositories/rules_repository_impl.dart';
import '../../../rules_engine/data/models/rule_system_model.dart';
import '../../../character_sheet/data/repositories/character_repository_impl.dart';
import '../../../character_sheet/data/models/character_model.dart';
import '../../../character_sheet/domain/factories/character_factory.dart';
import '../../../character_sheet/presentation/pages/character_sheet_page.dart';
import '../../../combat/presentation/pages/combat_page.dart';
import 'wiki_page.dart';
import '../../../compendium/presentation/pages/compendium_page.dart';

class CampaignDashboardPage extends StatefulWidget {
  const CampaignDashboardPage({super.key});
                             
  @override
  State<CampaignDashboardPage> createState() => _CampaignDashboardPageState();
}

class _CampaignDashboardPageState extends State<CampaignDashboardPage> {
  final CharacterRepositoryImpl _charRepo = CharacterRepositoryImpl();
  final RulesRepositoryImpl _rulesRepo = RulesRepositoryImpl();
  
  List<CharacterModel> _characters = [];
  RuleSystemModel? _rules; // On a besoin des règles pour créer un perso
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Chargement initial
  Future<void> _loadData() async {
    // 1. Charger les règles (nécessaire pour la factory)
    final rules = await _rulesRepo.loadDefaultRules();
    // 2. Charger la liste des persos
    final chars = await _charRepo.getAllCharacters();

    if (mounted) {
      setState(() {
        _rules = rules;
        _characters = chars;
        _isLoading = false;
      });
    }
  }

  // Action : Créer un nouveau perso
  void _createNewCharacter() {
    if (_rules == null) return;
    
    final factory = CharacterFactory();
    final newChar = factory.createBlankCharacter(_rules!);
    
    // On l'ajoute à la liste locale et on sauvegarde
    setState(() {
      _characters.add(newChar);
    });
    _charRepo.saveCharacter(newChar); // Sauvegarde disque
    
    // Optionnel : Ouvrir directement la fiche
    _openCharacterSheet(newChar);
  }

  // Action : Ouvrir la fiche
  void _openCharacterSheet(CharacterModel char) async {
    if (_rules == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CharacterSheetPage(
          character: char, 
          rules: _rules!
        ),
      ),
    );
    
    // Au retour, on recharge la liste (au cas où le nom a changé)
    _loadData();
  }

  // Action : Supprimer
  void _deleteCharacter(String id) async {
    await _charRepo.deleteCharacter(id);
    _loadData(); // On rafraîchit
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Campagne : D&D Maison"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
              IconButton(
              icon: const Icon(Icons.flash_on), // Icône de combat 
              tooltip: "Lancer le Combat",
              onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CombatPage()),
      );
      
    },
  ),
      IconButton(
  icon: const Icon(Icons.menu_book), // Icône Livre
  tooltip: "Notes & Scénario",
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WikiPage()),
    );
  },
),
    IconButton(
  icon: const Icon(Icons.auto_stories), // Icône bibliothèque
  tooltip: "Compendium",
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CompendiumPage()),
    );
  },
),
],

      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _characters.isEmpty 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.groups, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text("Aucun personnage."),
                      TextButton(onPressed: _createNewCharacter, child: const Text("Créer le premier"))
                    ],
                  ),
                )
              
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _characters.length,
                  itemBuilder: (context, index) {
                    final char = _characters[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigo.shade100,
                          child: Text(char.name.isNotEmpty ? char.name[0].toUpperCase() : "?"),
                        ),
                        title: Text(char.name.isEmpty ? "Sans Nom" : char.name),
                        subtitle: Text("Niveau ${char.getStat('level') ?? '?'}"),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.grey),
                          onPressed: () => _deleteCharacter(char.id),
                        ),
                        onTap: () => _openCharacterSheet(char),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewCharacter,
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.add, color: Colors.white),
        
      ),
    );
  }
}
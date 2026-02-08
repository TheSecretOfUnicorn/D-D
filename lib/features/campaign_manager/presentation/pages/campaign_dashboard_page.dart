import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Nécessaire pour le presse-papier

// --- Vos Imports ---
import '../../../../core/services/data_sharing_service.dart';
import '../../../character_sheet/data/models/character_model.dart';
import '../../../character_sheet/data/repositories/character_repository_impl.dart';
import '../../../character_sheet/presentation/pages/character_sheet_page.dart';
import '../../../rules_engine/data/models/rule_system_model.dart';
import '../../../rules_engine/data/repositories/rules_repository_impl.dart';
import '../../../compendium/presentation/pages/compendium_page.dart';
import '../../../combat/presentation/pages/combat_page.dart';
import '../../../wiki/presentation/pages/wiki_page.dart';

class CampaignDashboardPage extends StatefulWidget {
  const CampaignDashboardPage({super.key});

  @override
  State<CampaignDashboardPage> createState() => _CampaignDashboardPageState();
}

class _CampaignDashboardPageState extends State<CampaignDashboardPage> {
  // --- Dépendances ---
  final RulesRepositoryImpl _rulesRepo = RulesRepositoryImpl();
  final CharacterRepositoryImpl _charRepo = CharacterRepositoryImpl();
  final DataSharingService _sharingService = DataSharingService();

  // --- État ---
  RuleSystemModel? _loadedRules;
  List<CharacterModel> _characters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // --- 1. Chargement des Données ---
  Future<void> _loadData() async {
    try {
      final rules = await _rulesRepo.loadDefaultRules();
      final chars = await _charRepo.getAllCharacters();

      if (mounted) {
        setState(() {
          _loadedRules = rules;
          _characters = chars;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Erreur chargement: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 2. Navigation vers la Fiche ---
  void _openCharacterSheet(CharacterModel char) async {
    if (_loadedRules == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CharacterSheetPage(
          character: char, 
          rules: _loadedRules!
        ),
      ),
    );
    // Rechargement au retour pour mettre à jour le nom/niveau
    _loadData();
  }

  // --- 3. Création ---
  void _createNewCharacter() async {
    if (_loadedRules == null) return;

    final newChar = CharacterModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: "Nouveau Personnage",
      stats: {},
    );

    await _charRepo.saveCharacter(newChar);
    if (mounted) _openCharacterSheet(newChar);
  }

  // --- 4. Suppression ---
  void _deleteCharacter(String id) async {
    await _charRepo.deleteCharacter(id);
    _loadData();
  }

  // --- 5. Import (Réintégré et Sécurisé) ---
  void _importCharacter() async {
    // A. Lire le presse-papier
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    
    if (data == null || data.text == null || data.text!.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Presse-papier vide")));
      return;
    }

    // B. Convertir
    final newChar = _sharingService.importCharacter(data.text!);

    if (newChar != null && mounted) {
      // C. Afficher la confirmation (Sécurisée contre le crash layout)
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Importer ce personnage ?"),
          // SingleChildScrollView évite le crash "RenderIntrinsicWidth" si le contenu est trop grand
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min, // IMPORTANT pour éviter le crash
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Nom : ${newChar.name}"),
                Text("ID : ${newChar.id}"),
                const SizedBox(height: 10),
                const Text("Voulez-vous l'ajouter à votre campagne ?"),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx), 
              child: const Text("Annuler")
            ),
            ElevatedButton(
              onPressed: () async {
                // Sauvegarder
                await _charRepo.saveCharacter(newChar);
                Navigator.pop(ctx);
                _loadData(); // Rafraîchir la liste
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Personnage importé !")));
              },
              child: const Text("Confirmer"),
            ),
          ],
        ),
      );
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Code JSON invalide")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_loadedRules == null) return const Scaffold(body: Center(child: Text("Erreur de règles JSON")));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Campagne"),
        // --- VOS BOUTONS SONT DE RETOUR ICI ---
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: "Importer",
            onPressed: _importCharacter,
          ),
          
          // BOUTON WIKI
          IconButton(
            icon: const Icon(Icons.menu_book),
            tooltip: "Wiki / Notes",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const WikiPage()));
            },
          ),
          
          // BOUTON COMPENDIUM
          IconButton(
            icon: const Icon(Icons.auto_stories),
            tooltip: "Compendium",
            onPressed: () {
              if (_loadedRules != null) {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => CompendiumPage(rules: _loadedRules!)
                ));
              }
            },
          ),
          
          // BOUTON COMBAT
          IconButton(
            icon: const Icon(Icons.flash_on),
            tooltip: "Combat Tracker",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => CombatPage(characters: _characters)
              ));
            },
          ),
        ],
      ),

      body: _characters.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Aucun aventurier."),
                  const SizedBox(height: 10),
                  ElevatedButton(onPressed: _createNewCharacter, child: const Text("Créer un personnage"))
                ],
              ),
            )
          : ListView.builder(
              itemCount: _characters.length,
              itemBuilder: (context, index) {
                final char = _characters[index];
                
                // Logique d'affichage du nom (Fallack sur les stats)
                String displayName = char.name;
                if (displayName.isEmpty || displayName == "Nouveau Personnage") {
                   displayName = char.stats['name']?.toString() ?? char.name;
                }
                if (displayName.isEmpty) displayName = "Sans Nom";

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: char.imagePath != null
                        ? CircleAvatar(backgroundImage: FileImage(File(char.imagePath!)))
                        : const CircleAvatar(child: Icon(Icons.person)),
                    
                    title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Niveau ${char.stats['level'] ?? 1} - ${char.stats['class'] ?? 'Classe ?'}"),
                    
                    onTap: () => _openCharacterSheet(char),
                    
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteCharacter(char.id),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewCharacter,
        child: const Icon(Icons.add),
      ),
    );
  }
}
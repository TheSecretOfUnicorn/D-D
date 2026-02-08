import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Pour le presse-papier

// --- Imports ---
import '../../../../core/services/data_sharing_service.dart';
import '../../../character_sheet/data/models/character_model.dart';
import '../../../character_sheet/data/repositories/character_repository_impl.dart';
import '../../../character_sheet/presentation/pages/character_sheet_page.dart';
import '../../../rules_engine/data/models/rule_system_model.dart';
import '../../../rules_engine/data/repositories/rules_repository_impl.dart';
import '../../../compendium/presentation/pages/compendium_page.dart';
import '../../../combat/presentation/pages/combat_page.dart';
import '../../../wiki/presentation/pages/wiki_page.dart';
import 'campaign_game_page.dart';

// --- Imports Cloud ---
import '../../data/models/campaign_model.dart';
import '../../data/repositories/campaign_repository.dart';

class CampaignDashboardPage extends StatefulWidget {
  const CampaignDashboardPage({super.key});

  @override
  State<CampaignDashboardPage> createState() => _CampaignDashboardPageState();
}

class _CampaignDashboardPageState extends State<CampaignDashboardPage> with SingleTickerProviderStateMixin {
  // --- Dépendances ---
  final RulesRepositoryImpl _rulesRepo = RulesRepositoryImpl();
  final CharacterRepositoryImpl _charRepo = CharacterRepositoryImpl();
  final DataSharingService _sharingService = DataSharingService();
  final CampaignRepository _campaignRepo = CampaignRepository();

  // --- Contrôleurs & État ---
  late TabController _tabController;
  RuleSystemModel? _loadedRules;
  List<CharacterModel> _characters = [];
  List<CampaignModel> _campaigns = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- CHARGEMENT ---
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _rulesRepo.loadDefaultRules(),
        _charRepo.getAllCharacters(),
        _campaignRepo.getAllCampaigns(),
      ]);

      if (mounted) {
        setState(() {
          _loadedRules = results[0] as RuleSystemModel;
          _characters = results[1] as List<CharacterModel>;
          _campaigns = results[2] as List<CampaignModel>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // On n'affiche l'erreur que si ce n'est pas juste un log vide
        if (!e.toString().contains("ClientException")) { 
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Info: ${e.toString().substring(0, 50)}...")));
        }
      }
    }
  }

  // --- ACTIONS PERSONNAGES ---

  void _createNewCharacter() async {
    if (_loadedRules == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Règles non chargées.")));
      return;
    }

    final newChar = CharacterModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: "Nouveau Héros",
      stats: {},
    );

    await _charRepo.saveCharacter(newChar);
    if (mounted) _openCharacterSheet(newChar);
  }

  void _openCharacterSheet(CharacterModel char) async {
    if (_loadedRules == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CharacterSheetPage(character: char, rules: _loadedRules!),
      ),
    );
    _loadData();
  }

  void _deleteCharacter(String id) async {
    await _charRepo.deleteCharacter(id);
    _loadData();
  }

  // --- IMPORT (RÉINTÉGRÉ) ---
  void _importCharacter() async {
    // 1. Lire le presse-papier
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    
    if (data == null || data.text == null || data.text!.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Presse-papier vide")));
      return;
    }

    // 2. Convertir
    final newChar = _sharingService.importCharacter(data.text!);

    if (newChar != null && mounted) {
      // 3. Demander confirmation
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Importer ce personnage ?"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Nom : ${newChar.name}", style: const TextStyle(fontWeight: FontWeight.bold)),
                Text("ID : ${newChar.id}"),
                const SizedBox(height: 10),
                const Text("Voulez-vous l'ajouter à vos fiches locales ?"),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
            ElevatedButton(
              onPressed: () async {
                await _charRepo.saveCharacter(newChar);
                Navigator.pop(ctx);
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Personnage importé !")));
              },
              child: const Text("Confirmer"),
            ),
          ],
        ),
      );
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Format JSON invalide")));
    }
  }

  // --- ACTIONS CAMPAGNES ---

  void _createNewCampaign() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Nouvelle Campagne (Cloud)"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Titre de l'aventure"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                try {
                  await _campaignRepo.createCampaign(controller.text);
                  await _loadData();
                  if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Campagne créée !")));
                } catch (e) {
                  if (mounted) {
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
                  }
                }
              }
            },
            child: const Text("Créer"),
          )
        ],
      ),
    );
  }


  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Table de Jeu"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: "Personnages"),
            Tab(icon: Icon(Icons.cloud), text: "Campagnes"),
          ],
        ),
        // --- BOUTONS RÉINTÉGRÉS ICI ---
        actions: [
          // 1. IMPORT
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: "Importer JSON",
            onPressed: _importCharacter,
          ),
          // 2. WIKI
          IconButton(
            icon: const Icon(Icons.menu_book),
            tooltip: "Wiki / Notes",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WikiPage())),
          ),
          // 3. COMPENDIUM (Règles)
          IconButton(
            icon: const Icon(Icons.auto_stories),
            tooltip: "Compendium",
            onPressed: () {
              if (_loadedRules != null) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => CompendiumPage(rules: _loadedRules!)));
              } else {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Règles non chargées")));
              }
            },
          ),
          // 4. COMBAT
          IconButton(
            icon: const Icon(Icons.flash_on),
            tooltip: "Combat Tracker",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CombatPage(characters: _characters))),
          ),
        ],
      ),
      
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: _tabController,
            children: [
              // --- ONGLET 1 : PERSONNAGES (Local) ---
              Scaffold(
                // Bouton Créer Perso
                floatingActionButton: FloatingActionButton(
                  heroTag: "btnCreateChar", // Tag unique obligatoire quand il y a 2 FAB
                  onPressed: _createNewCharacter,
                  backgroundColor: Colors.teal,
                  tooltip: "Créer un Personnage",
                  child: const Icon(Icons.person_add),
                ),
                body: _characters.isEmpty 
                  ? const Center(child: Text("Aucun personnage local."))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: _characters.length,
                      itemBuilder: (ctx, i) {
                        final c = _characters[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          child: ListTile(
                            leading: c.imagePath != null
                                ? CircleAvatar(backgroundImage: FileImage(File(c.imagePath!)))
                                : const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(c.name.isEmpty ? "Sans Nom" : c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("Niveau ${c.stats['level'] ?? 1}"),
                            onTap: () => _openCharacterSheet(c),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.grey),
                              onPressed: () => _deleteCharacter(c.id),
                            ),
                          ),
                        );
                      },
                    ),
              ),

             // --- ONGLET 2 : CAMPAGNES (Cloud) ---
              Scaffold(
                // On utilise une Row ou une Column pour le FAB, ou mieux : un SpeedDial.
                // Pour faire simple sans librairie externe, on met deux boutons en bas à droite.
                floatingActionButton: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Bouton REJOINDRE (Blanc/Gris)
                    FloatingActionButton.extended(
                      heroTag: "btnJoinCamp",
                      onPressed: _showJoinDialog,
                      label: const Text("Rejoindre"),
                      icon: const Icon(Icons.group_add),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.indigo,
                    ),
                    const SizedBox(height: 16),
                    // Bouton CRÉER (Indigo)
                    FloatingActionButton.extended(
                      heroTag: "btnCreateCamp",
                      onPressed: _createNewCampaign,
                      label: const Text("Nouvelle"),
                      icon: const Icon(Icons.add),
                      backgroundColor: Colors.indigo,
                    ),
                  ],
                ),
                body: _campaigns.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cloud_off, size: 64, color: Colors.indigo),
                          const SizedBox(height: 16),
                          const Text("Aucune campagne en ligne."),
                          const SizedBox(height: 10),
                          Text("Créez-en une ou rejoignez un ami !", style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 150), // Place pour les 2 boutons
                      itemCount: _campaigns.length,
                      itemBuilder: (ctx, i) {
                        final camp = _campaigns[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          elevation: 3,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.indigo,
                              child: Icon(
                                // Icône différente si je suis MJ ou Joueur (info à ajouter dans le modèle plus tard)
                                Icons.castle, 
                                color: Colors.white
                              ),
                            ),
                            title: Text(camp.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("Code: ${camp.inviteCode}"),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                            onTap: () {
                              // NAVIGATION VERS LA SALLE DE JEU
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CampaignGamePage(campaign: camp),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
    );
  }

// Fonction pour afficher la popup "Entrer le code"
  void _showJoinDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Rejoindre une Table"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Code invitation (ex: X7Z9)",
            labelText: "Code",
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters, // Clavier majuscules
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                try {
                  await _campaignRepo.joinCampaign(controller.text);
                  await _loadData(); // Recharger la liste pour voir la nouvelle campagne
                  if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bienvenue dans l'aventure !")));
                } catch (e) {
                  if (mounted) {
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll("Exception: ", ""))));
                  }
                }
              }
            },
            child: const Text("Rejoindre"),
          )
        ],
      ),
    );
  }


}
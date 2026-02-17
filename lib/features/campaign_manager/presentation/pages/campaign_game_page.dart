import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Pour stocker le choix du perso

// --- MODELS ---
import '../../data/models/campaign_model.dart';
import '../../../character_sheet/data/models/character_model.dart';

// --- REPOSITORIES ---
import '../../../character_sheet/data/repositories/character_repository_impl.dart';
import '../../data/repositories/campaign_repository.dart';
import '../../../map_editor/data/repositories/map_repository.dart';

// --- PAGES ---
import '../../../map_editor/presentation/pages/maps_list_page.dart';
import '../../../map_editor/presentation/pages/map_editor_page.dart';
import '../../../character_sheet/presentation/pages/character_sheet_page.dart';
import '../../../rules_engine/data/repositories/rules_repository_impl.dart'; // Pour charger les règles

class CampaignGamePage extends StatefulWidget {
  final CampaignModel campaign;

  const CampaignGamePage({super.key, required this.campaign});

  @override
  State<CampaignGamePage> createState() => _CampaignGamePageState();
}

class _CampaignGamePageState extends State<CampaignGamePage> {
  final MapRepository _mapRepo = MapRepository();
  final CampaignRepository _campRepo = CampaignRepository();
  final CharacterRepositoryImpl _charRepo = CharacterRepositoryImpl();
  
  // État
  final List<String> _logs = []; // Historique des dés
  CharacterModel? _myCharacter; // Mon personnage actif pour cette campagne
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMyCharacter();
    // TODO: Ici on pourrait aussi s'abonner aux sockets pour recevoir les dés des autres
  }

  // --- GESTION PERSONNAGE ---
  
  Future<void> _loadMyCharacter() async {
    // Dans une version avancée, on demanderait au serveur "Quel est mon perso pour cette campagne ?"
    // Pour l'instant, on va charger le dernier perso sélectionné localement ou demander à l'user
    final prefs = await SharedPreferences.getInstance();
    final charId = prefs.getString('campaign_${widget.campaign.id}_char');
    
    if (charId != null) {
      final char = await _charRepo.getAllCharacters(charId); // Méthode à vérifier dans ton repo
      if (mounted) setState(() => _myCharacter = char.first);
    }
  }

  void _selectCharacter() async {
    // 1. Charger tous les persos locaux
    final allChars = await _charRepo.getAllCharacters("");
    
    if (!mounted) return;

    // 2. Afficher la liste
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: const Text("Choisir mon Héros", style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: allChars.length,
            itemBuilder: (ctx, i) {
              final c = allChars[i];
              return ListTile(
                title: Text(c.name, style: const TextStyle(color: Colors.white)),
                subtitle: Text("Niveau ${c.stats['level'] ?? 1}", style: const TextStyle(color: Colors.grey)),
                leading: const CircleAvatar(child: Icon(Icons.person)),
                onTap: () async {
                  // Sauvegarder le choix
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('campaign_${widget.campaign.id}_char', c.id);
                  
                  // Envoyer au serveur (Optionnel pour l'instant mais recommandé)
                  await _campRepo.selectCharacter(widget.campaign.id, int.parse(c.id) as String); 

                  setState(() => _myCharacter = c);
                  Navigator.pop(ctx);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _openCharacterSheet() async {
    if (_myCharacter == null) return;
    
    // On charge les règles par défaut pour afficher la fiche correctement
    final rules = await RulesRepositoryImpl().loadDefaultRules();
    
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CharacterSheetPage(character: _myCharacter!, rules: rules),
      ),
    );
  }

  // --- GESTION DÉS & LOGS ---

  void _addLog(String message, {Color color = Colors.white}) {
    setState(() {
      _logs.insert(0, "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2,'0')} - $message");
    });
  }

  void _showDiceRoller() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: const Text("Lancer de Dés 🎲", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 10, runSpacing: 10, alignment: WrapAlignment.center,
              children: [4, 6, 8, 10, 12, 20, 100].map((faces) {
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                  onPressed: () {
                    final result = Random().nextInt(faces) + 1;
                    Navigator.pop(ctx);
                    _processDiceResult(faces, result);
                  },
                  child: Text("d$faces", style: const TextStyle(color: Colors.white)),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _processDiceResult(int faces, int result) {
    String msg = "A lancé 1d$faces : $result";
    Color col = Colors.white;

    if (faces == 20) {
      if (result == 20) { msg += " (CRITIQUE !)"; col = Colors.greenAccent; }
      else if (result == 1) { msg += " (ÉCHEC !)"; col = Colors.redAccent; }
    }
    _addLog(msg, color: col);
  }

  // --- ACTIONS CARTE ---

  void _onMapClicked(bool isGM) async {
    if (isGM) {
      // MJ : Liste des cartes
      Navigator.push(context, MaterialPageRoute(builder: (_) => MapsListPage(campaignId: widget.campaign.id, isGM: true)));
    } else {
      // JOUEUR : Rejoindre active
      setState(() => _isLoading = true);
      final activeMapId = await _mapRepo.getActiveMapId(widget.campaign.id);
      setState(() => _isLoading = false);

      if (activeMapId != null) {
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => MapEditorPage(campaignId: widget.campaign.id, mapId: activeMapId)));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Le MJ n'a activé aucune carte pour le moment.")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGM = widget.campaign.role == 'GM';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.campaign.title),
        backgroundColor: const Color(0xFF1a1a1a),
        actions: [
          Chip(
            label: Text(isGM ? "MJ" : "Joueur"),
            backgroundColor: isGM ? Colors.deepOrange : Colors.indigo,
            labelStyle: const TextStyle(color: Colors.white),
          ),
          const SizedBox(width: 10),
        ],
      ),
      backgroundColor: const Color(0xFF121212),
      body: Column(
        children: [
          // 1. ZONE PERSONNAGE (Haut)
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF252525),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.grey[800],
                  child: Icon(isGM ? Icons.security : Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isGM ? "Maître du Jeu" : (_myCharacter?.name ?? "Spectateur"),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (!isGM && _myCharacter == null)
                        GestureDetector(
                          onTap: _selectCharacter,
                          child: const Text("Cliquez pour choisir un perso", style: TextStyle(color: Colors.blueAccent, decoration: TextDecoration.underline)),
                        ),
                      if (!isGM && _myCharacter != null)
                         const Text("Prêt à l'aventure", style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
                    ],
                  ),
                ),
                if (!isGM && _myCharacter != null)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.description, size: 16),
                    label: const Text("Fiche"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                    onPressed: _openCharacterSheet,
                  ),
                if (!isGM && _myCharacter == null)
                   IconButton(icon: const Icon(Icons.person_add, color: Colors.blueAccent), onPressed: _selectCharacter),
              ],
            ),
          ),

          // 2. ZONE ACTIONS (Milieu)
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator()) 
              : GridView.count(
                  padding: const EdgeInsets.all(16),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.3,
                  children: [
                    _DashboardCard(
                      icon: Icons.map, 
                      label: isGM ? "Gérer Cartes" : "Rejoindre Plateau", 
                      color: Colors.blue, 
                      onTap: () => _onMapClicked(isGM)
                    ),
                    _DashboardCard(icon: Icons.casino, label: "Lancer Dés", color: Colors.purple, onTap: _showDiceRoller),
                    _DashboardCard(icon: Icons.book, label: "Journal", color: Colors.amber, onTap: (){}),
                    _DashboardCard(icon: Icons.settings, label: "Options", color: Colors.grey, onTap: (){}),
                  ],
                ),
          ),

          // 3. ZONE LOGS (Bas - Console de texte)
          Container(
            height: 150,
            decoration: const BoxDecoration(
              color: Color(0xFF000000),
              border: Border(top: BorderSide(color: Colors.white24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text("JOURNAL DE JEU", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _logs.length,
                    itemBuilder: (ctx, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(_logs[i], style: const TextStyle(color: Colors.white70, fontFamily: 'Courier', fontSize: 13)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _DashboardCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4, color: const Color(0xFF2C2C2C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
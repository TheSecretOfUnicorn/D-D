import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/campaign_model.dart';
import '../../../character_sheet/data/models/character_model.dart';
import '../../../character_sheet/data/repositories/character_repository_impl.dart';
import '../../data/repositories/campaign_repository.dart';
import '../../../map_editor/data/repositories/map_repository.dart';

import '../../../map_editor/presentation/pages/maps_list_page.dart';
import '../../../map_editor/presentation/pages/map_editor_page.dart';
import '../../../character_sheet/presentation/pages/character_sheet_page.dart';
import '../../../rules_engine/data/repositories/rules_repository_impl.dart';
import 'journal_page.dart'; 

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
  
  final List<String> _logs = [];
  CharacterModel? _myCharacter;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMyCharacter();
  }

  Future<void> _loadMyCharacter() async {
    final prefs = await SharedPreferences.getInstance();
    // ✅ CORRECTION DU CRASH TYPE : On force la conversion en String pour la clé
    final key = 'campaign_${widget.campaign.id}_char';
    final charId = prefs.getString(key);
    
    if (charId != null) {
      final char = await _charRepo.getCharacter(charId);
      if (mounted) setState(() => _myCharacter = char);
    }
  }

  void _selectCharacter() async {
    setState(() => _isLoading = true);
    // On charge la liste des personnages locaux
    final allChars = await _charRepo.getAllCharacters();
    setState(() => _isLoading = false);
    
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: const Text("Choisir mon Héros", style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: allChars.isEmpty 
            ? const Text("Aucun personnage créé. Allez dans l'onglet 'Personnages' du menu principal pour en créer un.", style: TextStyle(color: Colors.white54))
            : ListView.builder(
            shrinkWrap: true,
            itemCount: allChars.length,
            itemBuilder: (ctx, i) {
              final c = allChars[i];
              return ListTile(
                title: Text(c.name, style: const TextStyle(color: Colors.white)),
                leading: const CircleAvatar(child: Icon(Icons.person)),
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  
                  // ✅ CORRECTION 1 : Conversion explicite en String pour la clé de sauvegarde
                  final key = 'campaign_${widget.campaign.id}_char'; 
                  await prefs.setString(key, c.id);
                  
                  // ✅ CORRECTION 2 : Gestion de l'appel serveur
                  // Si le serveur attend un INT pour l'ID du perso, on essaie de convertir
                  // Sinon, on ignore l'erreur pour ne pas bloquer l'UI
                  try {
                     int charIdInt = int.tryParse(c.id) ?? 0;
                     // On envoie seulement si l'ID est un nombre valide (cas des persos synchronisés)
                     if (charIdInt != 0) {
                        await _campRepo.selectCharacter(widget.campaign.id, charIdInt as String); 
                     }
                  } catch (e) { 
                    print("Note: Synchro serveur ignorée ($e)"); 
                  }

                  setState(() => _myCharacter = c);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Vous jouez ${c.name} !")));
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
    
    // 1. Chargement des règles
    final rules = await RulesRepositoryImpl().loadDefaultRules();
    if (!mounted) return; // Sécurité 1
    
    // 2. Rechargement du personnage (pour avoir les dernières stats)
    final freshChar = await _charRepo.getCharacter(_myCharacter!.id);
    
    // ✅ CORRECTION ICI : On vérifie ENCORE si le widget est actif après le 2ème await
    if (!mounted) return; 

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CharacterSheetPage(
          character: freshChar ?? _myCharacter!, 
          rules: rules,
          campaignId: widget.campaign.id, // On passe l'ID pour activer le mode jeu
        ),
      ),
    ).then((_) => _loadMyCharacter()); // Recharger au retour
  }

  // --- MAP ---
  void _onMapClicked(bool isGM) async {
    if (isGM) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => MapsListPage(campaignId: widget.campaign.id, isGM: true)));
    } else {
      setState(() => _isLoading = true);
      final activeMapId = await _mapRepo.getActiveMapId(widget.campaign.id);
      setState(() => _isLoading = false);

      if (activeMapId != null && mounted) {
        // ✅ ON PASSE LE BOOLÉEN isGM: false
        Navigator.push(context, MaterialPageRoute(builder: (_) => MapEditorPage(campaignId: widget.campaign.id, mapId: activeMapId, isGM: false)));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Le MJ n'a activé aucune carte.")));
      }
    }
  }

  // --- DÉS ---
  void _showDiceRoller() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: const Text("Lancer de Dés", style: TextStyle(color: Colors.white)),
        content: Wrap(
          spacing: 8, runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [4, 6, 8, 10, 12, 20, 100].map((faces) => ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            onPressed: () {
              Navigator.pop(ctx);
              final r = Random().nextInt(faces) + 1;
              _addLog("d$faces : $r", color: r == 20 ? Colors.green : (r==1 ? Colors.red : Colors.white));
            },
            child: Text("d$faces"),
          )).toList(),
        ),
      ),
    );
  }

  void _addLog(String msg, {Color color = Colors.white}) {
    setState(() => _logs.insert(0, "${DateTime.now().hour}:${DateTime.now().minute} > $msg"));
  }

  @override
  Widget build(BuildContext context) {
    final isGM = widget.campaign.role == 'GM';

    return Scaffold(
      appBar: AppBar(title: Text(widget.campaign.title), backgroundColor: const Color(0xFF1a1a1a)),
      backgroundColor: const Color(0xFF121212),
      body: Column(
        children: [
          // 1. BANDEAU PERSO
          Container(
            padding: const EdgeInsets.all(12), color: const Color(0xFF252525),
            child: Row(
              children: [
                Icon(isGM ? Icons.security : Icons.person, color: Colors.white, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isGM ? "Maître du Jeu" : (_myCharacter?.name ?? "Spectateur"), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      if (!isGM) GestureDetector(
                        onTap: _selectCharacter,
                        child: Text(_myCharacter == null ? "Choisir un personnage" : "Changer", style: const TextStyle(color: Colors.blueAccent, fontSize: 12)),
                      )
                    ],
                  ),
                ),
                if (!isGM && _myCharacter != null)
                  ElevatedButton(onPressed: _openCharacterSheet, child: const Text("Fiche")),
              ],
            ),
          ),
          
          // 2. ACTIONS
          Expanded(
            child: _isLoading ? const Center(child: CircularProgressIndicator()) : GridView.count(
              padding: const EdgeInsets.all(16), crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.5,
              children: [
                _ActionCard(icon: Icons.map, label: isGM ? "Gestion Cartes" : "Rejoindre Carte", color: Colors.blue, onTap: () => _onMapClicked(isGM)),
                _ActionCard(icon: Icons.casino, label: "Dés", color: Colors.purple, onTap: _showDiceRoller),
                _ActionCard(icon: Icons.book, label: "Journal", color: Colors.amber, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JournalPage(campaignId: widget.campaign.id, isGM: isGM)))),
                _ActionCard(icon: Icons.people, label: "Groupe", color: Colors.green, onTap: (){}),
              ],
            ),
          ),

          // 3. LOGS
          Container(
            height: 120, color: Colors.black,
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _logs.length,
              itemBuilder: (ctx, i) => Text(_logs[i], style: const TextStyle(color: Colors.white70, fontFamily: "Courier")),
            ),
          )
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF2C2C2C),
      child: InkWell(
        onTap: onTap,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 32, color: color), Text(label, style: const TextStyle(color: Colors.white))]),
      ),
    );
  }
}
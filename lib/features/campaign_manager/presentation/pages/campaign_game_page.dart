import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../data/models/campaign_model.dart';
import '../../data/repositories/campaign_repository.dart';
import '../../../character_sheet/data/repositories/character_repository_impl.dart'; // Pour charger mes persos
import '../../../character_sheet/data/models/character_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CampaignGamePage extends StatefulWidget {
  final CampaignModel campaign;
  const CampaignGamePage({super.key, required this.campaign});

  @override
  State<CampaignGamePage> createState() => _CampaignGamePageState();
}

class _CampaignGamePageState extends State<CampaignGamePage> {
  final CampaignRepository _campRepo = CampaignRepository();
  final CharacterRepositoryImpl _charRepo = CharacterRepositoryImpl();
  
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _members = []; // La liste des joueurs présents
  
  Timer? _refreshTimer;
  late bool _allowDice;
  String? _currentUserId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _allowDice = widget.campaign.allowDice;
    _initSession();
    
    // Polling : Chat + Liste des membres (pour voir les PV changer en temps réel plus tard)
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchLogs();
      _fetchMembers();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initSession() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.get('user_id')?.toString();
    
    await _fetchLogs();
    await _fetchMembers();
    
    if (mounted) setState(() => _isLoading = false);

    // Si je suis joueur et que je n'ai pas de perso assigné dans cette liste -> Popup
    _checkMyCharacter();
  }

  Future<void> _fetchLogs() async {
    try {
      final logs = await _campRepo.getLogs(widget.campaign.id);
      if (mounted) setState(() => _logs = logs);
    } catch (_) {}
  }

  Future<void> _fetchMembers() async {
    try {
      final members = await _campRepo.getMembers(widget.campaign.id);
      if (mounted) setState(() => _members = members);
    } catch (_) {}
  }

  // --- LOGIQUE DE SÉLECTION DE PERSONNAGE ---
  void _checkMyCharacter() {
    if (_currentUserId == null || widget.campaign.role == 'GM') return;

    // Je cherche mon entrée dans la liste des membres
    final myEntry = _members.firstWhere(
      (m) => m['user_id'].toString() == _currentUserId, 
      orElse: () => {},
    );

    // Si je n'ai pas de 'char_id', je dois en choisir un
    if (myEntry.isNotEmpty && myEntry['char_id'] == null) {
      _showCharacterSelector();
    }
  }

  void _showCharacterSelector() async {
    // 1. Charger mes personnages locaux/cloud
    final myCharacters = await _charRepo.getAllCharacters();

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false, // Obligatoire de choisir
      builder: (ctx) => AlertDialog(
        title: const Text("Qui jouez-vous ?"),
        content: SizedBox(
          width: double.maxFinite,
          child: myCharacters.isEmpty 
            ? const Text("Vous n'avez aucun personnage. Créez-en un d'abord !") 
            : ListView.builder(
                shrinkWrap: true,
                itemCount: myCharacters.length,
                itemBuilder: (ctx, i) {
                  final c = myCharacters[i];
                  return ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(c.name),
                    subtitle: Text("Niveau ${c.stats['level'] ?? 1}"),
                    onTap: () {
                      _selectCharacter(c);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
        ),
        actions: [
          if (myCharacters.isEmpty)
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Je regarderai seulement"))
        ],
      ),
    );
  }

  void _selectCharacter(CharacterModel c) async {
    await _campRepo.selectCharacter(widget.campaign.id, c.id);
    _fetchMembers(); // Rafraîchir pour voir que je suis bien assigné
    
    // Petit message système
    _campRepo.sendLog(widget.campaign.id, "a rejoint la table en tant que ${c.name} !");
  }

  // --- ACTIONS DE JEU ---

  void _sendMessage() async {
    if (_msgController.text.trim().isEmpty) return;
    await _campRepo.sendLog(widget.campaign.id, _msgController.text, type: 'MSG');
    _msgController.clear();
    _fetchLogs();
  }

  void _rollDice() async {
    if (!_allowDice) return;
    final result = Random().nextInt(20) + 1;
    await _campRepo.sendLog(widget.campaign.id, "a lancé un D20", type: 'DICE', resultValue: result);
    _fetchLogs();
  }

  @override
  Widget build(BuildContext context) {
    final isGM = widget.campaign.role == 'GM';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.campaign.title),
            Text("Code: ${widget.campaign.inviteCode}", style: const TextStyle(fontSize: 10)),
          ],
        ),
        actions: [
          // Bouton pour ouvrir le panneau des joueurs (Drawer) à droite
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.people),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      // LE PANNEAU LATÉRAL (Pour voir les joueurs et leurs stats)
      endDrawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.indigo),
              child: Center(child: Text("Joueurs (${_members.length})", style: const TextStyle(color: Colors.white, fontSize: 20))),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _members.length,
                itemBuilder: (ctx, i) {
                  final m = _members[i];
                  final hasChar = m['char_id'] != null;
                  
                  // Récupération des stats depuis le JSON
                  final stats = hasChar ? m['char_data']['stats'] : {};
                  final hp = stats != null ? stats['hp_current'] : '?';
                  final ac = stats != null ? stats['ac'] : '?';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: m['role'] == 'GM' ? Colors.red : Colors.blue,
                      child: Text(m['username'][0].toUpperCase()),
                    ),
                    title: Text(m['username']),
                    subtitle: Text(hasChar ? "${m['char_name']}" : "Spectateur"),
                    trailing: hasChar 
                      ? SizedBox(
                          width: 60,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("PV: $hp", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                              Text("CA: $ac", style: const TextStyle(fontSize: 10)),
                            ],
                          ),
                        ) 
                      : null,
                    onTap: isGM && hasChar ? () {
                      // ICI : Future fonctionnalité "Action MJ"
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Action sur ${m['char_name']} à venir !")));
                    } : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.all(16),
              itemCount: _logs.length,
              itemBuilder: (ctx, i) {
                final log = _logs[i];
                final isDice = log['type'] == 'DICE';
                final isMe = log['user_id'].toString() == _currentUserId;
                
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDice ? Colors.amber[100] : (isMe ? Colors.indigo[100] : Colors.grey[200]),
                      borderRadius: BorderRadius.circular(8),
                      border: isDice ? Border.all(color: Colors.orange) : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(log['username'] ?? '?', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        if (isDice)
                          Text("${log['result_value']} (D20)", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
                        else
                          Text(log['content'] ?? ""),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Zone de saisie (identique à avant)
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.casino), onPressed: _allowDice ? _rollDice : null),
                Expanded(child: TextField(controller: _msgController, onSubmitted: (_) => _sendMessage())),
                IconButton(icon: const Icon(Icons.send), onPressed: _sendMessage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
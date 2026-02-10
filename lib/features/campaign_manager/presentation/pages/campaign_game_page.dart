import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../data/models/campaign_model.dart';
import '../../data/repositories/campaign_repository.dart';
import '../../../character_sheet/data/repositories/character_repository_impl.dart'; // Pour charger mes persos
import '../../../character_sheet/data/models/character_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 👇 Nouveaux imports pour ouvrir la fiche
import '../../../character_sheet/presentation/pages/character_sheet_page.dart';
import '../../../rules_engine/data/repositories/rules_repository_impl.dart';

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
  List<Map<String, dynamic>> _members = []; 
  
  Timer? _refreshTimer;
  late bool _allowDice;
  String? _currentUserId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _allowDice = widget.campaign.allowDice;
    _initSession();
    
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

  void _checkMyCharacter() {
    if (_currentUserId == null || widget.campaign.role == 'GM') return;

    final myEntry = _members.firstWhere(
      (m) => m['user_id'].toString() == _currentUserId, 
      orElse: () => {},
    );

    if (myEntry.isNotEmpty && myEntry['char_id'] == null) {
      _showCharacterSelector();
    }
  }

  void _showCharacterSelector() async {
    final myCharacters = await _charRepo.getAllCharacters();

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false, 
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
    _fetchMembers(); 
    _campRepo.sendLog(widget.campaign.id, "a rejoint la table en tant que ${c.name} !");
  }

  // 👇 NOUVELLE FONCTION : OUVRIR MA FICHE DEPUIS LE JEU 👇
  void _openMySheet() async {
    if (_currentUserId == null) return;
    
    final myEntry = _members.firstWhere(
      (m) => m['user_id'].toString() == _currentUserId, 
      orElse: () => {},
    );

    if (myEntry.isEmpty || myEntry['char_data'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Aucun personnage sélectionné.")));
      return;
    }

    // Reconstruction du personnage pour l'affichage
    final character = CharacterModel.fromJson({
      ...myEntry['char_data'], 
      'id': myEntry['char_id'], 
      'name': myEntry['char_name']
    });

    final rules = await RulesRepositoryImpl().loadDefaultRules();

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CharacterSheetPage(
          character: character, 
          rules: rules,
          campaignId: widget.campaign.id, // 👈 Active le mode "Jeu" avec les dés
        )),
      );
    }
  }

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
          // 👇 BOUTON "MA FICHE" (Seulement pour les joueurs)
          if (!isGM)
            IconButton(
              icon: const Icon(Icons.assignment_ind),
              tooltip: "Ma Fiche",
              onPressed: _openMySheet,
            ),

          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.people),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
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
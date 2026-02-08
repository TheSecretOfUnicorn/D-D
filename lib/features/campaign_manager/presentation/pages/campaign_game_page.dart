import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Pour savoir si je suis GM
import '../../data/models/campaign_model.dart';
import '../../data/repositories/campaign_repository.dart';

class CampaignGamePage extends StatefulWidget {
  final CampaignModel campaign;
  const CampaignGamePage({super.key, required this.campaign});

  @override
  State<CampaignGamePage> createState() => _CampaignGamePageState();
}

class _CampaignGamePageState extends State<CampaignGamePage> {
  final CampaignRepository _repo = CampaignRepository();
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _logs = [];
  Timer? _refreshTimer;
  bool _isLoading = true;
  bool _isGM = false; // Suis-je le maître du jeu ?
  late bool _allowDice; // État local des dés

  @override
  void initState() {
    super.initState();
    _allowDice = widget.campaign.allowDice;
    _checkRole();
    _loadLogs();
    // Rafraîchir toutes les 3s
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) => _loadLogs(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // Vérifier si je suis le créateur de cette campagne (stocké en local ou via API)
  Future<void> _checkRole() async {
    final prefs = await SharedPreferences.getInstance();
    final myId = prefs.getInt('user_id');
    // On peut aussi le vérifier via l'API members, mais ceci est plus rapide pour l'UI
    // Note: Pour une vraie sécurité, le serveur bloque déjà les actions MJ.
    // Ici on suppose que le MJ est celui qui a créé la campagne, ou on le récupère via members.
    // Simplification : On va demander à l'API qui est le GM via getMembers si besoin, 
    // mais pour l'instant on va faire un check rapide lors du chargement des membres.
    _loadMembersAndRole(myId);
  }

  Future<void> _loadMembersAndRole(int? myId) async {
    try {
      final members = await _repo.getCampaignMembers(widget.campaign.id);
      final me = members.firstWhere((m) => m['id'] == myId, orElse: () => {});
      if (mounted && me.isNotEmpty) {
        setState(() {
          _isGM = me['role'] == 'GM';
        });
      }
    } catch (e) {
      print("Erreur rôle: $e");
    }
  }

  Future<void> _loadLogs({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final logs = await _repo.getCampaignLogs(widget.campaign.id);
      if (mounted) {
        setState(() {
          _logs = logs;
          _isLoading = false;
        });
        // Scroll automatique en bas si nouveaux messages
        if (!silent && _logs.isNotEmpty) {
           Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
        }
      }
    } catch (e) {
      print("Erreur logs: $e"); // Voir la console pour le debug
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _rollDice(int faces) async {
    final result = Random().nextInt(faces) + 1;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Lancement D$faces... $result !"), duration: const Duration(milliseconds: 500)),
    );

    try {
      await _repo.sendLog(
        widget.campaign.id, 
        "a lancé un D$faces et a fait $result", 
        "DICE", 
        result
      );
      _loadLogs(silent: true);
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur envoi: $e")));
    }
  }

  // --- PARAMÈTRES MJ ---
  void _openSettings() {
    showDialog(
      context: context,
      builder: (ctx) {
        bool localSwitch = _allowDice;
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              title: const Text("Paramètres MJ"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text("Autoriser les dés"),
                    subtitle: const Text("Si désactivé, les joueurs ne verront plus la barre de dés."),
                    value: localSwitch,
                    onChanged: (val) {
                      setStateSB(() => localSwitch = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _repo.updateSettings(widget.campaign.id, localSwitch);
                    setState(() => _allowDice = localSwitch); // Mise à jour locale immédiate
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Paramètres mis à jour !")));
                  },
                  child: const Text("Sauvegarder"),
                )
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.campaign.title),
        actions: [
          // BOUTON PARAMÈTRES (VISIBLE SEULEMENT SI GM)
          if (_isGM)
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: "Paramètres MJ",
              onPressed: _openSettings,
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Code Invitation"),
                  content: Text(widget.campaign.inviteCode ?? "Aucun", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ),
              );
            },
          )
        ],
      ),
      body: Column(
        children: [
          // BANDEAU INFO (Optionnel)
          if (!_allowDice)
            Container(
              width: double.infinity,
              color: Colors.red[100],
              padding: const EdgeInsets.all(4),
              child: const Text("Les dés sont temporairement désactivés par le MJ.", textAlign: TextAlign.center, style: TextStyle(color: Colors.red)),
            ),

          // ZONE DE CHAT
          Expanded(
            child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _logs.isEmpty 
                ? const Center(child: Text("Journal vide."))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      final isDice = log['type'] == 'DICE';
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDice ? Colors.indigo.withOpacity(0.1) : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                          border: isDice ? Border.all(color: Colors.indigo.withOpacity(0.3)) : null,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(isDice ? Icons.casino : Icons.chat_bubble, size: 20, color: isDice ? Colors.indigo : Colors.grey),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(log['username'] ?? "Inconnu", style: TextStyle(fontWeight: FontWeight.bold, color: isDice ? Colors.indigo : Colors.black87, fontSize: 12)),
                                  Text(log['content'] ?? "", style: TextStyle(fontSize: 16, fontWeight: isDice ? FontWeight.bold : FontWeight.normal)),
                                ],
                              ),
                            ),
                            if (isDice && log['result_value'] != null)
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(color: Colors.indigo, shape: BoxShape.circle),
                                child: Text("${log['result_value']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              )
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // BARRE DE DÉS (VISIBLE SEULEMENT SI ALLOW_DICE EST TRUE)
          if (_allowDice)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, -2))],
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _DiceButton(faces: 4, onPressed: () => _rollDice(4)),
                    _DiceButton(faces: 6, onPressed: () => _rollDice(6)),
                    _DiceButton(faces: 8, onPressed: () => _rollDice(8)),
                    _DiceButton(faces: 10, onPressed: () => _rollDice(10)),
                    _DiceButton(faces: 12, onPressed: () => _rollDice(12)),
                    _DiceButton(faces: 20, onPressed: () => _rollDice(20), isPrimary: true),
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }
}

class _DiceButton extends StatelessWidget {
  final int faces;
  final VoidCallback onPressed;
  final bool isPrimary;
  const _DiceButton({required this.faces, required this.onPressed, this.isPrimary = false});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: isPrimary ? 50 : 40,
        height: isPrimary ? 50 : 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isPrimary ? Colors.indigo : Colors.white,
          border: Border.all(color: Colors.indigo),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text("D$faces", style: TextStyle(color: isPrimary ? Colors.white : Colors.indigo, fontWeight: FontWeight.bold, fontSize: isPrimary ? 16 : 12)),
      ),
    );
  }
}
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../data/models/campaign_model.dart';
import '../../data/repositories/campaign_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CampaignGamePage extends StatefulWidget {
  final CampaignModel campaign;

  const CampaignGamePage({super.key, required this.campaign});

  @override
  State<CampaignGamePage> createState() => _CampaignGamePageState();
}

class _CampaignGamePageState extends State<CampaignGamePage> {
  final CampaignRepository _repo = CampaignRepository();
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _logs = [];
  Timer? _refreshTimer;
  bool _allowDice = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _allowDice = widget.campaign.allowDice;
    _loadCurrentUser();
    
    // 1. Chargement initial
    _fetchLogs();
    
    // 2. Rafraîchissement automatique toutes les 3 secondes (Polling)
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchLogs());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getString('user_id');
    });
  }

  Future<void> _fetchLogs() async {
    final logs = await _repo.getLogs(widget.campaign.id);
    if (mounted) {
      setState(() {
        _logs = logs;
      });
      // Scroll automatique en bas si on reçoit un nouveau message
      // (Optionnel, à affiner selon l'UX voulue)
    }
  }

  void _sendMessage() async {
    if (_msgController.text.trim().isEmpty) return;
    final text = _msgController.text;
    _msgController.clear();

    await _repo.sendLog(widget.campaign.id, text, type: 'MSG');
    _fetchLogs(); // Refresh immédiat
  }

  void _rollDice() async {
    if (!_allowDice) return;
    
    // Simulation d'un D20
    final result = Random().nextInt(20) + 1;
    final msg = "a lancé un D20 : $result";

    await _repo.sendLog(widget.campaign.id, msg, type: 'DICE', resultValue: result);
    _fetchLogs();
  }

  void _toggleDice(bool value) async {
    // Optimistic UI : On change tout de suite visuellement
    setState(() => _allowDice = value);
    
    // On envoie au serveur
    bool success = await _repo.updateSettings(widget.campaign.id, value);
    
    if (!success) {
      // Si ça rate, on remet comme avant
      if (mounted) {
        setState(() => _allowDice = !value); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur connexion")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGM = widget.campaign.role == 'GM';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.campaign.title, style: const TextStyle(fontSize: 16)),
            Text("Code: ${widget.campaign.inviteCode}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w300)),
          ],
        ),
        actions: [
          // Switch MJ pour les dés
          if (isGM) 
            Row(
              children: [
                const Icon(Icons.casino, size: 16),
                Switch(
                  value: _allowDice,
                  activeColor: Colors.greenAccent,
                  onChanged: _toggleDice,
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // ZONE DE CHAT
          Expanded(
            child: _logs.isEmpty 
              ? Center(child: Text("La table est calme...", style: TextStyle(color: Colors.grey[400])))
              : ListView.builder(
                  controller: _scrollController,
                  reverse: true, // Les messages récents en bas
                  padding: const EdgeInsets.all(16),
                  itemCount: _logs.length,
                  itemBuilder: (ctx, i) {
                    final log = _logs[i];
                    final isMe = log['user_id'].toString() == _currentUserId;
                    final isDice = log['type'] == 'DICE';

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDice 
                              ? Colors.amber[100] 
                              : (isMe ? Colors.indigo[100] : Colors.grey[200]),
                          borderRadius: BorderRadius.circular(12),
                          border: isDice ? Border.all(color: Colors.orange) : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log['username'] ?? "Inconnu", 
                              style: TextStyle(
                                fontSize: 10, 
                                fontWeight: FontWeight.bold,
                                color: isMe ? Colors.indigo : Colors.black54
                              )
                            ),
                            if (isDice) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.casino, size: 16, color: Colors.orange),
                                  const SizedBox(width: 8),
                                  Text(
                                    "${log['result_value']}", 
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                                  ),
                                ],
                              )
                            ] else
                              Text(log['content'] ?? ""),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),

          // BARRE DE SAISIE
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: Row(
              children: [
                // Bouton Dé (Désactivé si le MJ l'a interdit)
                IconButton(
                  icon: Icon(Icons.casino, color: _allowDice ? Colors.orange : Colors.grey),
                  onPressed: _allowDice ? _rollDice : null,
                ),
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: const InputDecoration(
                      hintText: "Parler...",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.indigo),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
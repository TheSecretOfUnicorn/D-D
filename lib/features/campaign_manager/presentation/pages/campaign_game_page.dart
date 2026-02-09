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
  
  late bool _allowDice;
  late String _campaignTitle;
  late String _inviteCode;
  
  String? _currentUserId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _allowDice = widget.campaign.allowDice;
    _campaignTitle = widget.campaign.title;
    _inviteCode = widget.campaign.inviteCode;

    _loadCurrentUser();
    _fetchLogs();
    
    // Polling toutes les 3s
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchLogs();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 👇 LA CORRECTION EST ICI 👇
  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        // On utilise .get() pour récupérer l'objet (qu'il soit int ou String)
        // Puis on force le .toString() pour avoir du texte
        _currentUserId = prefs.get('user_id')?.toString();
      });
    }
  }
  // 👆 FIN DE LA CORRECTION 👆

  Future<void> _fetchLogs() async {
    try {
      final logs = await _repo.getLogs(widget.campaign.id);
      if (mounted) {
        setState(() {
          _logs = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Erreur logs: $e");
    }
  }

  void _sendMessage() async {
    if (_msgController.text.trim().isEmpty) return;
    final text = _msgController.text;
    _msgController.clear();

    await _repo.sendLog(widget.campaign.id, text, type: 'MSG');
    _fetchLogs(); 
  }

  void _rollDice() async {
    if (!_allowDice) return;
    final result = Random().nextInt(20) + 1;
    final msg = "a lancé un D20"; 

    await _repo.sendLog(widget.campaign.id, msg, type: 'DICE', resultValue: result);
    _fetchLogs();
  }

  void _toggleDice(bool value) async {
    setState(() => _allowDice = value);
    
    bool success = await _repo.updateSettings(widget.campaign.id, value);
    
    if (!success) {
      if (mounted) {
        setState(() => _allowDice = !value); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur connexion serveur")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si _currentUserId est null (pas encore chargé), on attend un peu pour éviter les erreurs d'affichage
    if (_currentUserId == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Le modèle CampaignModel a maintenant un getter 'role' grâce au correctif précédent
    final isGM = widget.campaign.role == 'GM'; 

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_campaignTitle, style: const TextStyle(fontSize: 16)),
            Text("Code: $_inviteCode", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w300)),
          ],
        ),
        actions: [
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
          Expanded(
            child: _logs.isEmpty 
              ? Center(child: Text(_isLoading ? "Chargement..." : "Aucun message."))
              : ListView.builder(
                  controller: _scrollController,
                  reverse: true, 
                  padding: const EdgeInsets.all(16),
                  itemCount: _logs.length,
                  itemBuilder: (ctx, i) {
                    final log = _logs[i];
                    
                    // Sécurité anti-crash si user_id est manquant dans le log
                    final logUserId = log['user_id']?.toString() ?? "0";
                    final isMe = logUserId == _currentUserId;
                    
                    final isDice = log['type'] == 'DICE';
                    final date = DateTime.tryParse(log['created_at'].toString()) ?? DateTime.now();

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
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
                              "${log['username'] ?? 'Inconnu'} • ${date.hour}h${date.minute.toString().padLeft(2, '0')}", 
                              style: TextStyle(
                                fontSize: 10, 
                                fontWeight: FontWeight.bold,
                                color: isMe ? Colors.indigo : Colors.black54
                              )
                            ),
                            const SizedBox(height: 4),
                            if (isDice) 
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.casino, size: 20, color: Colors.deepOrange),
                                  const SizedBox(width: 8),
                                  Text(
                                    "${log['result_value']}", 
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)
                                  ),
                                  const SizedBox(width: 8),
                                  const Text("(D20)", style: TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              )
                            else
                              Text(log['content'] ?? "", style: const TextStyle(fontSize: 15)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))]
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.casino, color: _allowDice ? Colors.orange : Colors.grey[300]),
                  onPressed: _allowDice ? _rollDice : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Les dés sont désactivés par le MJ."), duration: Duration(seconds: 1))
                    );
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: const InputDecoration(
                      hintText: "Message...",
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
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
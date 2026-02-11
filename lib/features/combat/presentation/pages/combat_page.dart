import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/models/combatant_model.dart';
import '../../../campaign_manager/data/repositories/campaign_repository.dart';

class CombatPage extends StatefulWidget {
  final int campaignId; // ID de la campagne (pour parler au serveur)
  final bool isGM;      // Est-ce le MJ ?

  const CombatPage({super.key, required this.campaignId, required this.isGM});

  @override
  State<CombatPage> createState() => _CombatPageState();
}

class _CombatPageState extends State<CombatPage> {
  final CampaignRepository _repo = CampaignRepository();
  List<CombatantModel> _participants = [];
  bool _isActive = false;
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadCombat();
    // Actualisation auto toutes les 3 secondes
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) => _loadCombat());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCombat() async {
    final data = await _repo.getCombatDetails(widget.campaignId);
    if (!mounted) return;

    setState(() {
      _isActive = data['active'] ?? false;
      if (_isActive && data['participants'] != null) {
        _participants = (data['participants'] as List)
            .map((json) => CombatantModel.fromJson(json))
            .toList();
      } else {
        _participants = [];
      }
      _isLoading = false;
    });
  }

  void _startCombat() async {
    setState(() => _isLoading = true);
    await _repo.startCombat(widget.campaignId);
    if (!mounted) return;
    _loadCombat();
  }

  void _editParticipant(CombatantModel p) {
    if (!widget.isGM) return;
    final hpCtrl = TextEditingController(text: "0");
    final initCtrl = TextEditingController(text: p.initiative.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Modifier ${p.name}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Initiative :", style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(controller: initCtrl, keyboardType: TextInputType.number),
            const SizedBox(height: 20),
            Text("PV Actuels : ${p.hpCurrent} / ${p.hpMax}", style: const TextStyle(fontWeight: FontWeight.bold)),
            TextField(controller: hpCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Modifier PV (+ Soin, - Dégâts)")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () async {
              int hpMod = int.tryParse(hpCtrl.text) ?? 0;
              int newInit = int.tryParse(initCtrl.text) ?? p.initiative;
              int newHp = (p.hpCurrent + hpMod).clamp(0, p.hpMax);

              await _repo.updateParticipant(widget.campaignId, p.id, {
                "initiative": newInit,
                "hp_current": newHp
              });

              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _loadCombat();
            },
            child: const Text("Valider"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Combat Tracker"),
        actions: [ IconButton(icon: const Icon(Icons.refresh), onPressed: _loadCombat) ],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_isActive) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sports_kabaddi, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            const Text("Aucun combat en cours."),
            const SizedBox(height: 20),
            if (widget.isGM)
              ElevatedButton.icon(
                onPressed: _startCombat,
                icon: const Icon(Icons.play_arrow),
                label: const Text("LANCER L'INITIATIVE"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              )
            else
              const Text("Attendez que le MJ lance les hostilités..."),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _participants.length,
      itemBuilder: (context, index) {
        final p = _participants[index];
        return Card(
          elevation: 3,
          child: ListTile(
            leading: CircleAvatar(backgroundColor: Colors.indigo, child: Text("${p.initiative}")),
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: LinearProgressIndicator(
              value: p.hpMax > 0 ? p.hpCurrent / p.hpMax : 0,
              color: (p.hpCurrent < p.hpMax / 4) ? Colors.red : Colors.green,
            ),
            trailing: widget.isGM ? IconButton(icon: const Icon(Icons.edit), onPressed: () => _editParticipant(p)) : null,
          ),
        );
      },
    );
  }
}
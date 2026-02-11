import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/models/combatant_model.dart';
import '../../../campaign_manager/data/repositories/campaign_repository.dart';

class CombatPage extends StatefulWidget {
  final int campaignId;
  final bool isGM;

  const CombatPage({super.key, required this.campaignId, required this.isGM});

  @override
  State<CombatPage> createState() => _CombatPageState();
}

class _CombatPageState extends State<CombatPage> {
  final CampaignRepository _repo = CampaignRepository();
  List<CombatantModel> _participants = [];
  bool _isActive = false;
  bool _isLoading = true;
  int _currentRound = 1;
  int _turnIndex = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadCombat();
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) => _loadCombat());
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
      if (_isActive) {
        if (data['participants'] != null) {
          _participants = (data['participants'] as List)
              .map((json) => CombatantModel.fromJson(json))
              .toList();
        }
        final enc = data['encounter'];
        if (enc != null) {
          _currentRound = enc['round'] ?? 1;
          _turnIndex = enc['current_turn_index'] ?? 0;
        }
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

  void _nextTurn() async {
    await _repo.nextTurn(widget.campaignId);
    if (!mounted) return;
    _loadCombat();
  }

  void _stopCombat() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Fin du combat ?"),
        content: const Text("Cela effacera l'initiative."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Finir", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await _repo.stopCombat(widget.campaignId);
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  // --- AJOUT DE MONSTRE ---
  void _showAddMonsterDialog() {
    final nameCtrl = TextEditingController();
    final hpCtrl = TextEditingController(text: "10");
    final initCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Ajouter un Ennemi"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Nom (ex: Gobelin)")),
            const SizedBox(height: 10),
            TextField(controller: hpCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "PV Max")),
            const SizedBox(height: 10),
            TextField(controller: initCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Initiative (Vide = Aléatoire)")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              
              int hp = int.tryParse(hpCtrl.text) ?? 10;
              int? init = int.tryParse(initCtrl.text); // Null si vide

              await _repo.addParticipant(widget.campaignId, nameCtrl.text, hp, init);
              
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _loadCombat(); // Rafraîchir tout de suite
            },
            child: const Text("Ajouter"),
          ),
        ],
      ),
    );
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
            TextField(controller: initCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Initiative")),
            const SizedBox(height: 10),
            TextField(controller: hpCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "PV (+ Soin, - Dégâts)")),
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
        title: _isActive ? Text("Round $_currentRound") : const Text("Combat Tracker"),
        centerTitle: true,
        actions: [
          if (widget.isGM && _isActive) ...[
            IconButton(icon: const Icon(Icons.skip_next, color: Colors.greenAccent, size: 30), tooltip: "Tour Suivant", onPressed: _nextTurn),
            IconButton(icon: const Icon(Icons.stop_circle_outlined, color: Colors.redAccent), tooltip: "Finir Combat", onPressed: _stopCombat),
          ],
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadCombat),
        ],
      ),
      // BOUTON AJOUT MONSTRE (Visible seulement si MJ et Combat Actif)
      floatingActionButton: (widget.isGM && _isActive) 
          ? FloatingActionButton(
              onPressed: _showAddMonsterDialog,
              backgroundColor: Colors.red[800],
              child: const Icon(Icons.add),
            ) 
          : null,
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
            const Text("Le champ de bataille est calme..."),
            const SizedBox(height: 20),
            if (widget.isGM)
              ElevatedButton.icon(
                onPressed: _startCombat,
                icon: const Icon(Icons.play_arrow),
                label: const Text("LANCER L'INITIATIVE"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              )
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _participants.length,
      itemBuilder: (context, index) {
        final p = _participants[index];
        final isTurn = (index == _turnIndex);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isTurn ? Colors.indigo.withValues(alpha: 0.1) : Colors.white,
            border: isTurn ? Border.all(color: Colors.indigoAccent, width: 2) : null,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isTurn ? [const BoxShadow(color: Colors.indigoAccent, blurRadius: 8, spreadRadius: 1)] : [],
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: p.isNpc ? Colors.red[800] : (isTurn ? Colors.indigoAccent : Colors.grey[700]), // Rouge pour les monstres
              foregroundColor: Colors.white,
              child: p.isNpc 
                  ? const Icon(Icons.smart_toy) // Icône Robot/Monstre pour les NPC
                  : Text("${p.initiative}", style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            title: Text(
              p.name, 
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isTurn ? Colors.indigo : Colors.black)
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: p.hpMax > 0 ? p.hpCurrent / p.hpMax : 0,
                  color: (p.hpCurrent < p.hpMax / 4) ? Colors.red : Colors.green,
                  backgroundColor: Colors.grey[300],
                ),
                Text("${p.hpCurrent} / ${p.hpMax} PV", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                if (p.isNpc) Text("Initiative: ${p.initiative}", style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic)),
              ],
            ),
            trailing: widget.isGM 
              ? IconButton(icon: const Icon(Icons.edit), onPressed: () => _editParticipant(p)) 
              : (isTurn ? const Icon(Icons.arrow_back, color: Colors.indigo) : null),
          ),
        );
      },
    );
  }
}
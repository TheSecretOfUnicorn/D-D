import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../character_sheet/data/models/character_model.dart';

class CombatPage extends StatefulWidget {
  final List<CharacterModel> characters;

  const CombatPage({super.key, required this.characters});

  @override
  State<CombatPage> createState() => _CombatPageState();
}

class _CombatPageState extends State<CombatPage> {
  late List<CharacterModel> _fighters;

  @override
  void initState() {
    super.initState();
    _fighters = List.from(widget.characters);
  }

  // Lancer l'initiative (d20 + Dex Modifier)
  void _rollInitiative(CharacterModel char) {
    final dex = char.stats['dex'] is int ? char.stats['dex'] : 10;
    final mod = ((dex - 10) / 2).floor();
    final roll = Random().nextInt(20) + 1;
    final total = roll + mod;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("${char.name} : Initiative $total (d20:$roll + Mod:$mod)"),
      backgroundColor: Colors.blueAccent,
    ));
  }

  // Gérer les Dégâts / Soins
  void _manageHealth(CharacterModel char, int index) {
    final currentHp = char.stats['hp_current'] ?? 0;
    final maxHp = char.stats['hp_max'] ?? 10;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Santé : ${char.name}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("PV Actuels: $currentHp / $maxHp"),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Valeur", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.remove, color: Colors.white),
                  label: const Text("Dégâts"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () {
                    final val = int.tryParse(controller.text) ?? 0;
                    _updateHp(index, -val);
                    Navigator.pop(ctx);
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text("Soins"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () {
                    final val = int.tryParse(controller.text) ?? 0;
                    _updateHp(index, val);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _updateHp(int index, int change) {
    setState(() {
      final char = _fighters[index];
      int current = char.stats['hp_current'] ?? 0;
      int max = char.stats['hp_max'] ?? 10;
      
      current = (current + change).clamp(0, max); // Empêche < 0 ou > Max
      
      // Mise à jour locale (Attention: cela ne sauvegarde pas sur le disque dur pour l'instant)
      char.stats['hp_current'] = current;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Combat Tracker")),
      body: ListView.builder(
        itemCount: _fighters.length,
        itemBuilder: (context, index) {
          final char = _fighters[index];
          final hp = char.stats['hp_current'] ?? 0;
          final maxHp = char.stats['hp_max'] ?? 10;
          final percent = (maxHp > 0) ? hp / maxHp : 0.0;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: ListTile(
              leading: GestureDetector(
                onTap: () => _rollInitiative(char),
                child: CircleAvatar(
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: char.imagePath != null ? FileImage(File(char.imagePath!)) : null,
                  child: char.imagePath == null ? const Icon(Icons.flash_on, color: Colors.orange) : null,
                ),
              ),
              title: Text(char.stats['name'] ?? char.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 5),
                  LinearProgressIndicator(
                    value: percent,
                    color: hp < (maxHp / 4) ? Colors.red : Colors.green, // Rouge si critique
                    backgroundColor: Colors.grey.shade300,
                    minHeight: 8,
                  ),
                  const SizedBox(height: 2),
                  Text("Cliquez sur l'avatar pour l'Initiative", style: TextStyle(fontSize: 10, color: Colors.grey.shade600))
                ],
              ),
              trailing: TextButton(
                onPressed: () => _manageHealth(char, index),
                child: Text("$hp / $maxHp PV", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          );
        },
      ),
    );
  }
}
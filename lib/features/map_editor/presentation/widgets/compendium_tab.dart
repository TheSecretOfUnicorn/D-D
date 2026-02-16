import 'package:flutter/material.dart';

class CompendiumTab extends StatelessWidget {
  const CompendiumTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Liste fictive de monstres (plus tard, ça viendra de ta BDD)
    final monsters = [
      {'id': 'gobelin', 'name': 'Gobelin', 'hp': 7, 'ac': 15, 'color': Colors.green},
      {'id': 'orc', 'name': 'Orc', 'hp': 15, 'ac': 13, 'color': Colors.greenAccent},
      {'id': 'squelette', 'name': 'Squelette', 'hp': 13, 'ac': 13, 'color': Colors.grey},
      {'id': 'dragon', 'name': 'Jeune Dragon', 'hp': 100, 'ac': 18, 'color': Colors.red},
    ];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: const Color(0xFF2C2C2C),
          width: double.infinity,
          child: const Text(
            "BESTIAIRE",
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: monsters.length,
            itemBuilder: (context, index) {
              final monster = monsters[index];
              
              // DRAGGABLE : C'est ce qui permet le glisser-déposer
              return Draggable<Map<String, dynamic>>(
                data: monster, // Les données qu'on transporte
                feedback: Material( // Ce qu'on voit sous le doigt pendant qu'on glisse
                  color: Colors.transparent,
                  child: Opacity(
                    opacity: 0.7,
                    child: _MonsterCard(monster: monster, isDragging: true),
                  ),
                ),
                childWhenDragging: Opacity( // L'élément dans la liste pendant qu'on le déplace
                  opacity: 0.3,
                  child: _MonsterCard(monster: monster),
                ),
                child: _MonsterCard(monster: monster), // L'élément normal
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MonsterCard extends StatelessWidget {
  final Map<String, dynamic> monster;
  final bool isDragging;

  const _MonsterCard({required this.monster, this.isDragging = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF333333),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      width: isDragging ? 200 : null, // Taille fixe si on drag
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: monster['color'] as Color,
            radius: 16,
            child: Text((monster['name'] as String)[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(monster['name'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text("PV: ${monster['hp']} | CA: ${monster['ac']}", style: const TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ),
          const Spacer(),
          const Icon(Icons.drag_indicator, color: Colors.white24, size: 20),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../../../rules_engine/data/models/rule_system_model.dart';

class CompendiumPage extends StatelessWidget {
  final RuleSystemModel rules;

  const CompendiumPage({super.key, required this.rules});

  @override
  Widget build(BuildContext context) {
    // On récupère les clés disponibles (inventory, spellbook...)
    final categories = rules.library.keys.toList();

    return DefaultTabController(
      length: categories.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Compendium"),
          bottom: TabBar(
            isScrollable: true,
            tabs: categories.map((c) => Tab(text: c.toUpperCase())).toList(),
          ),
        ),
        body: TabBarView(
          children: categories.map((cat) {
            final items = rules.library[cat] ?? [];
            if (items.isEmpty) return const Center(child: Text("Vide"));

            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    title: Text(item['name'] ?? "Sans nom", style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      item.entries
                          .where((e) => e.key != 'name')
                          .map((e) => "${e.key}: ${e.value}")
                          .join(", "),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    leading: Icon(cat == 'spellbook' ? Icons.auto_fix_high : Icons.backpack),
                  ),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}
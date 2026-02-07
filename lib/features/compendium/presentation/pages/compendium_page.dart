import 'package:flutter/material.dart';
import '../../data/models/compendium_item_model.dart';
import '../../data/repositories/compendium_repository.dart';

class CompendiumPage extends StatefulWidget {
  const CompendiumPage({super.key});

  @override
  State<CompendiumPage> createState() => _CompendiumPageState();
}

class _CompendiumPageState extends State<CompendiumPage> {
  final CompendiumRepository _repo = CompendiumRepository();
  
  List<CompendiumItemModel> _allItems = []; // La source
  List<CompendiumItemModel> _filteredItems = []; // Ce qu'on affiche
  bool _isLoading = true;

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final items = await _repo.loadSpells();
    if (mounted) {
      setState(() {
        _allItems = items;
        _filteredItems = items; // Au début, on affiche tout
        _isLoading = false;
      });
    }
  }

  void _filter(String query) {
    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredItems = _allItems.where((item) {
        return item.name.toLowerCase().contains(lowerQuery) || 
               item.description.toLowerCase().contains(lowerQuery);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Compendium (Sorts)"),
        backgroundColor: Colors.teal.shade800,
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                labelText: "Rechercher un sort...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _filter,
            ),
          ),
          
          // Liste des résultats
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator()) 
              : ListView.builder(
                  itemCount: _filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = _filteredItems[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal.shade100,
                          child: Text("${item.details['level'] ?? '?'}"),
                        ),
                        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(item.details['school'] ?? ''),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Affichage des détails techniques (Portée, Durée...)
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 5,
                                  children: item.details.entries.map((e) {
                                    if (e.key == 'level' || e.key == 'school') return const SizedBox.shrink();
                                    return Chip(
                                      label: Text("${e.key}: ${e.value}"),
                                      backgroundColor: Colors.teal.shade50,
                                      visualDensity: VisualDensity.compact,
                                    );
                                  }).toList(),
                                ),
                                const Divider(),
                                // Description complète
                                Text(
                                  item.description,
                                  style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black87),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../../data/repositories/compendium_repository.dart';
import '../../presentation/pages/compendium_editor_page.dart';

class CompendiumPage extends StatefulWidget {
  final String? campaignId;

  const CompendiumPage({super.key, this.campaignId});

  @override
  State<CompendiumPage> createState() => _CompendiumPageState();
}

class _CompendiumPageState extends State<CompendiumPage> with SingleTickerProviderStateMixin {
  final CompendiumRepository _compendiumRepo = CompendiumRepository();
  late TabController _tabController;

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _spells = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _compendiumRepo.fetchFullCompendium(widget.campaignId);
      if (mounted) {
        setState(() {
          _items = data['items']!;
          _spells = data['spells']!;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteEntry(int id, String name) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Supprimer ?"),
        content: Text("Veux-tu vraiment supprimer '$name' définitivement ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Non")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Oui", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      bool success = await _compendiumRepo.deleteEntry(id);
      
      // Ici on est dans une méthode de la classe State, donc 'mounted' (this.mounted) 
      // protège correctement 'context' (this.context).
      if (!mounted) return;

      if (success) {
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Élément supprimé !")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur lors de la suppression.")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Compendium"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.shield), text: "Objets"),
            Tab(icon: Icon(Icons.auto_fix_high), text: "Sorts"),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.add),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CompendiumEditorPage()),
          );
          
          if (result == true) {
            await Future.delayed(const Duration(milliseconds: 300));
            
            // 🛑 CORRECTION ICI :
            // Dans build, 'context' est un argument local.
            // Le linter exige qu'on vérifie 'context.mounted' et non 'this.mounted'.
            if (!context.mounted) return;

            _loadData();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Élément ajouté !")));
          }
        },
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_items, Icons.shield, Colors.brown),
                _buildList(_spells, Icons.auto_fix_high, Colors.purple),
              ],
            ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> list, IconData icon, Color color) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text("Aucune donnée trouvée."),
            ElevatedButton(onPressed: _loadData, child: const Text("Actualiser"))
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final entry = list[index];
          final int id = int.tryParse(entry['id'].toString()) ?? 0;

          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withAlpha(51),
                child: Icon(icon, color: color),
              ),
              title: Text(entry['name'] ?? "Inconnu", style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(entry['desc'] ?? entry['description'] ?? "Pas de description"),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.grey),
                onPressed: () => _deleteEntry(id, entry['name']),
              ),
            ),
          );
        },
      ),
    );
  }
}
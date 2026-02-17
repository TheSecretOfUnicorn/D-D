import 'package:flutter/material.dart';
import '../../data/repositories/map_repository.dart';
import 'map_editor_page.dart';

class MapsListPage extends StatefulWidget {
  final int campaignId;
  final bool isGM;

  const MapsListPage({super.key, required this.campaignId, required this.isGM});

  @override
  State<MapsListPage> createState() => _MapsListPageState();
}

class _MapsListPageState extends State<MapsListPage> {
  final MapRepository _repo = MapRepository();
  List<Map<String, dynamic>> _maps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMaps();
  }

  Future<void> _loadMaps() async {
    setState(() => _isLoading = true);
    final maps = await _repo.getCampaignMaps(widget.campaignId);
    if (mounted) setState(() { _maps = maps; _isLoading = false; });
  }

  Future<void> _activateMap(String mapId) async {
    await _repo.activateMap(mapId);
    _loadMaps(); // Rafraîchir pour voir le changement de statut
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Carte activée pour les joueurs ! 🎮")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cartes de la Campagne"),
        backgroundColor: const Color(0xFF1a1a1a),
      ),
      backgroundColor: const Color(0xFF121212),
      floatingActionButton: widget.isGM 
        ? FloatingActionButton.extended(
            onPressed: () => Navigator.push(
              context, 
              MaterialPageRoute(builder: (_) => MapEditorPage(campaignId: widget.campaignId, mapId: "new_map"))
            ).then((_) => _loadMaps()),
            label: const Text("Nouvelle Carte"),
            icon: const Icon(Icons.add),
            backgroundColor: Colors.blueAccent,
          )
        : null,
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : _maps.isEmpty 
          ? const Center(child: Text("Aucune carte créée.", style: TextStyle(color: Colors.white54)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _maps.length,
              itemBuilder: (context, index) {
                final map = _maps[index];
                final isActive = map['is_active'] == true;

                return Card(
                  color: const Color(0xFF252525),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Icon(Icons.map, color: isActive ? Colors.greenAccent : Colors.grey),
                    title: Text(map['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text("${map['width']}x${map['height']} cases", style: const TextStyle(color: Colors.white54)),
                    trailing: widget.isGM ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isActive)
                          IconButton(
                            icon: const Icon(Icons.play_circle_outline, color: Colors.green),
                            tooltip: "Activer pour les joueurs",
                            onPressed: () => _activateMap(map['id'].toString()),
                          ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blueAccent),
                          tooltip: "Éditer",
                          onPressed: (!widget.isGM && !isActive) 
                      ? null 
                      : () => Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (_) => MapEditorPage(campaignId: widget.campaignId, mapId: map['id'].toString()))
                        ).then((_) => _loadMaps()),
                        ),
                      ],
                    ) : null,
                  ),
                );
              },
            ),
    );
  }
}
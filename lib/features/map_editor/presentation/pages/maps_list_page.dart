import 'package:flutter/material.dart';

import '../../data/repositories/map_repository.dart';
import 'map_editor_page.dart';

class MapsListPage extends StatefulWidget {
  final int campaignId;
  final bool isGM;

  const MapsListPage({
    super.key,
    required this.campaignId,
    required this.isGM,
  });

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
    if (!mounted) return;
    setState(() {
      _maps = maps;
      _isLoading = false;
    });
  }

  Future<void> _activateMap(String mapId) async {
    await _repo.activateMap(mapId);
    await _loadMaps();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Carte activee pour les joueurs")),
    );
  }

  Future<void> _renameMap(Map<String, dynamic> map) async {
    final controller = TextEditingController(
      text: map['name']?.toString() ?? '',
    );
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: const Color(0xFF252525),
            title: const Text(
              "Renommer la carte",
              style: TextStyle(color: Colors.white),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Nom",
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text("Annuler"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text("Enregistrer"),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    final success = await _repo.renameMap(
      map['id'].toString(),
      controller.text,
    );
    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossible de renommer cette carte."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    await _loadMaps();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Carte renommee.")),
    );
  }

  Future<void> _deleteMap(Map<String, dynamic> map) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: const Color(0xFF252525),
            title: const Text(
              "Supprimer la carte ?",
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              "La carte \"${map['name']}\" sera supprimee.",
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text("Annuler"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text(
                  "Supprimer",
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    final success = await _repo.deleteMap(map['id'].toString());
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossible de supprimer cette carte."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    await _loadMaps();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Carte supprimee.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isGM) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Cartes de la campagne"),
          backgroundColor: const Color(0xFF1a1a1a),
        ),
        backgroundColor: const Color(0xFF121212),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              "L'editeur de carte est reserve au MJ. Passe par la session map pour jouer.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
    }

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
                MaterialPageRoute(
                  builder: (_) => MapEditorPage.editor(
                    campaignId: widget.campaignId,
                    mapId: "new_map",
                  ),
                ),
              ).then((_) => _loadMaps()),
              label: const Text("Nouvelle Carte"),
              icon: const Icon(Icons.add),
              backgroundColor: Colors.blueAccent,
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _maps.isEmpty
              ? const Center(
                  child: Text(
                    "Aucune carte creee.",
                    style: TextStyle(color: Colors.white54),
                  ),
                )
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
                        leading: Icon(
                          Icons.map,
                          color: isActive ? Colors.greenAccent : Colors.grey,
                        ),
                        title: Text(
                          map['name'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          "${map['width']}x${map['height']} cases",
                          style: const TextStyle(color: Colors.white54),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isActive)
                              IconButton(
                                icon: const Icon(
                                  Icons.play_circle_outline,
                                  color: Colors.green,
                                ),
                                tooltip: "Activer pour les joueurs",
                                onPressed: () =>
                                    _activateMap(map['id'].toString()),
                              ),
                            IconButton(
                              icon: const Icon(
                                Icons.drive_file_rename_outline,
                                color: Colors.amberAccent,
                              ),
                              tooltip: "Renommer",
                              onPressed: () => _renameMap(map),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.blueAccent,
                              ),
                              tooltip: "Editer",
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MapEditorPage.editor(
                                    campaignId: widget.campaignId,
                                    mapId: map['id'].toString(),
                                  ),
                                ),
                              ).then((_) => _loadMaps()),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                              tooltip: "Supprimer",
                              onPressed: () => _deleteMap(map),
                            ),
                          ],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MapEditorPage.editor(
                              campaignId: widget.campaignId,
                              mapId: map['id'].toString(),
                            ),
                          ),
                        ).then((_) => _loadMaps()),
                      ),
                    );
                  },
                ),
    );
  }
}

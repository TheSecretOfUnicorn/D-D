import 'package:flutter/material.dart';
import '../../../campaign_manager/data/models/note_model.dart';
import '../../../campaign_manager/data/repositories/notes_repository.dart';
import '../../../map_editor/presentation/pages/map_editor_page.dart';

class WikiPage extends StatefulWidget {
  final int campaignId;
  final bool isGM;

  const WikiPage({super.key, required this.campaignId, required this.isGM});

  @override
  State<WikiPage> createState() => _WikiPageState();
}

class _WikiPageState extends State<WikiPage> {
  final NotesRepository _repo = NotesRepository();
  List<NoteModel> _notes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final notes = await _repo.fetchNotes(widget.campaignId);
    if (mounted) {
      setState(() {
        _notes = notes;
        _isLoading = false;
      });
    }
  }

  // --- ACTIONS ---

  void _addNote() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    bool isPublic = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Nouvelle Note"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: "Titre", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: contentCtrl,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: "Contenu", border: OutlineInputBorder()),
                ),
                if (widget.isGM)
                  SwitchListTile(
                    title: const Text("Public ?"),
                    subtitle: const Text("Visible par les joueurs"),
                    value: isPublic,
                    onChanged: (val) => setDialogState(() => isPublic = val),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.isEmpty) return;
                await _repo.createNote(widget.campaignId, titleCtrl.text, contentCtrl.text, isPublic);
                if (!mounted) return;
                if (ctx.mounted) {Navigator.pop(ctx); } 
                _loadData();
              },
              child: const Text("Créer"),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteNote(int id) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Supprimer ?"),
        content: const Text("Cette action est irréversible."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Non")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Oui", style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await _repo.deleteNote(id);
      _loadData();
    }
  }

  void _toggleVisibility(NoteModel note) async {
    await _repo.toggleVisibility(note.id, !note.isPublic);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Journal & Indices"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          // Votre raccourci Debug vers l'éditeur de carte
          IconButton(
            icon: const Icon(Icons.map, color: Colors.orange),
            tooltip: "Debug Map",
            onPressed: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => MapEditorPage(campaignId: widget.campaignId))
              );
            },
          )
        ],
      ),
      floatingActionButton: widget.isGM
          ? FloatingActionButton(
              onPressed: _addNote,
              backgroundColor: Colors.brown,
              child: const Icon(Icons.note_add),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? const Center(child: Text("Aucune note pour le moment."))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    return Card(
                      color: const Color(0xFFFDF6E3), // Effet papier
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ExpansionTile(
                        leading: widget.isGM
                            ? IconButton(
                                icon: Icon(note.isPublic ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                                onPressed: () => _toggleVisibility(note),
                              )
                            : const Icon(Icons.article, color: Colors.brown),
                        title: Text(
                          note.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: (!note.isPublic && widget.isGM) ? TextDecoration.lineThrough : null,
                            color: Colors.brown[900]
                          ),
                        ),
                        subtitle: Text(
                          "Ajouté le ${note.createdAt.day}/${note.createdAt.month}",
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(note.content, style: const TextStyle(fontSize: 16)),
                            ),
                          ),
                          if (widget.isGM)
                            Padding(
                              padding: const EdgeInsets.only(right: 8, bottom: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(Icons.delete, color: Colors.red, size: 16),
                                    label: const Text("Supprimer", style: TextStyle(color: Colors.red)),
                                    onPressed: () => _deleteNote(note.id),
                                  ),
                                ],
                              ),
                            )
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
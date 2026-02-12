import 'package:flutter/material.dart';
import '../../data/models/note_model.dart';
import '../../data/repositories/notes_repository.dart';

class JournalPage extends StatefulWidget {
  final int campaignId;
  final bool isGM; // Pour savoir si on affiche les boutons d'admin

  const JournalPage({super.key, required this.campaignId, required this.isGM});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
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

  // --- ACTIONS (MJ UNIQUEMENT) ---

  void _addNote() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    bool isPublic = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Nouvelle Note"),
          content: Column(
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
              const SizedBox(height: 10),
              SwitchListTile(
                title: const Text("Visible par les joueurs ?"),
                value: isPublic,
                onChanged: (val) => setDialogState(() => isPublic = val),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.isEmpty) return;
                await _repo.createNote(widget.campaignId, titleCtrl.text, contentCtrl.text, isPublic);
                if (!mounted) return;
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
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

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Journal de Campagne"),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData)],
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
              ? const Center(child: Text("Le journal est vide...", style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    return Card(
                      color: const Color(0xFFFDF6E3), // Couleur "Papier"
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      child: ExpansionTile(
                        leading: widget.isGM 
                          ? IconButton(
                              icon: Icon(note.isPublic ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                              onPressed: () => _toggleVisibility(note),
                              tooltip: "Changer visibilité",
                            )
                          : const Icon(Icons.book, color: Colors.brown),
                        title: Text(
                          note.title, 
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: (!note.isPublic && widget.isGM) ? TextDecoration.lineThrough : null,
                            color: Colors.brown[900]
                          ),
                        ),
                        subtitle: Text(
                          note.createdAt.toString().split(' ')[0], 
                          style: const TextStyle(fontSize: 10, color: Colors.grey)
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Text(note.content, style: const TextStyle(fontSize: 16)),
                            ),
                          ),
                          if (widget.isGM)
                            Padding(
                              padding: const EdgeInsets.only(right: 8, bottom: 8),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 16),
                                  label: const Text("Supprimer", style: TextStyle(color: Colors.red)),
                                  onPressed: () => _deleteNote(note.id),
                                ),
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
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart'; // Pensez à l'import uuid
import '../../data/models/note_model.dart';
import '../../data/repositories/notes_repository.dart';

class WikiPage extends StatefulWidget {
  const WikiPage({super.key});

  @override
  State<WikiPage> createState() => _WikiPageState();
}

class _WikiPageState extends State<WikiPage> {
  final NotesRepository _repo = NotesRepository();
  final Uuid _uuid = const Uuid();

  List<NoteModel> _allNotes = []; // Toutes les notes en vrac
  String? _currentFolderId; // Dans quel dossier sommes-nous ? (null = racine)
  
  // Fil d'Ariane (Breadcrumbs) pour savoir où on est (ex: Monde > Ville > Taverne)
  final List<NoteModel> _breadcrumbs = [];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final notes = await _repo.loadNotes();
    setState(() {
      _allNotes = notes;
    });
  }

  // --- ACTIONS ---

  void _createItem({required bool isFolder}) {
    final TextEditingController controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isFolder ? "Nouveau Dossier" : "Nouvelle Note"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Titre..."),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                final newItem = NoteModel(
                  id: _uuid.v4(),
                  title: controller.text,
                  parentId: _currentFolderId, // On crée dans le dossier actuel
                  isFolder: isFolder,
                  lastEdited: DateTime.now(),
                );
                
                setState(() {
                  _allNotes.add(newItem);
                });
                _repo.saveNotes(_allNotes);
                Navigator.pop(ctx);
              }
            },
            child: const Text("Créer"),
          )
        ],
      ),
    );
  }

  void _deleteItem(String id) {
    // Attention : supprimer un dossier doit supprimer ses enfants (récursif)
    // Pour l'instant, on fait simple : on supprime juste l'item
    setState(() {
      _allNotes.removeWhere((n) => n.id == id);
    });
    _repo.saveNotes(_allNotes);
  }

  // Navigation dans un dossier
  void _enterFolder(NoteModel folder) {
    setState(() {
      _currentFolderId = folder.id;
      _breadcrumbs.add(folder);
    });
  }

  // Remonter d'un niveau
  void _goBack() {
    if (_breadcrumbs.isEmpty) return;
    setState(() {
      _breadcrumbs.removeLast();
      // Le nouveau dossier courant est le dernier du fil d'Ariane, ou null si vide
      _currentFolderId = _breadcrumbs.isEmpty ? null : _breadcrumbs.last.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. Filtrer les notes pour n'afficher que celles du dossier courant
    final currentItems = _allNotes.where((n) => n.parentId == _currentFolderId).toList();
    
    // On trie : Dossiers d'abord, puis Notes
    currentItems.sort((a, b) {
      if (a.isFolder && !b.isFolder) return -1;
      if (!a.isFolder && b.isFolder) return 1;
      return a.title.compareTo(b.title);
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(_breadcrumbs.isEmpty ? "Wiki Campagne" : _breadcrumbs.last.title),
        backgroundColor: Colors.brown.shade700,
        leading: _breadcrumbs.isNotEmpty 
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _goBack)
            : null,
      ),
      body: ListView.builder(
        itemCount: currentItems.length,
        itemBuilder: (context, index) {
          final item = currentItems[index];
          
          return ListTile(
            leading: Icon(
              item.isFolder ? Icons.folder : Icons.description,
              color: item.isFolder ? Colors.amber : Colors.blueGrey,
            ),
            title: Text(item.title),
            subtitle: Text("Modifié le : ${item.lastEdited.day}/${item.lastEdited.month}"),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.grey),
              onPressed: () => _deleteItem(item.id),
            ),
            onTap: () {
              if (item.isFolder) {
                _enterFolder(item);
              } else {
            
                _openEditor(item);
              }
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: "folder_btn",
            onPressed: () => _createItem(isFolder: true),
            backgroundColor: Colors.amber,
            child: const Icon(Icons.create_new_folder),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "note_btn",
            onPressed: () => _createItem(isFolder: false),
            backgroundColor: Colors.brown,
            child: const Icon(Icons.note_add),
          ),
        ],
      ),
    );
  }

  // --- ÉDITEUR SIMPLE ---
  
  void _openEditor(NoteModel note) {
    final titleController = TextEditingController(text: note.title);
    final contentController = TextEditingController(text: note.content);

    showDialog(
      context: context,
      barrierDismissible: false, // Oblige à sauver ou annuler
      builder: (ctx) => Scaffold( // On ouvre une "page" en plein écran
        appBar: AppBar(
          title: const Text("Édition"),
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: () {
                // Mise à jour de la note
                final updatedNote = NoteModel(
                  id: note.id,
                  title: titleController.text,
                  content: contentController.text,
                  parentId: note.parentId,
                  isFolder: false,
                  lastEdited: DateTime.now(),
                );
                
                // On remplace dans la liste
                setState(() {
                  final idx = _allNotes.indexWhere((n) => n.id == note.id);
                  if (idx != -1) {
                    _allNotes[idx] = updatedNote;
                  }
                });
                _repo.saveNotes(_allNotes);
                Navigator.pop(ctx);
              },
            )
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(hintText: "Titre"),
              ),
              const Divider(),
              Expanded(
                child: TextField(
                  controller: contentController,
                  maxLines: null, // Multiligne infini
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: "Écrivez votre scénario ici...",
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
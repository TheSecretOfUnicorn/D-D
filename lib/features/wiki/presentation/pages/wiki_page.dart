import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

// --- IMPORTS CORRIGÉS ---
// On remonte de 3 niveaux (pages -> presentation -> wiki -> features)
// pour aller chercher dans campaign_manager
import '../../../campaign_manager/data/models/note_model.dart';
import '../../../campaign_manager/data/repositories/notes_repository.dart';
import '../../../map_editor/presentation/pages/map_editor_page.dart';

class WikiPage extends StatefulWidget {
  const WikiPage({super.key});

  @override
  State<WikiPage> createState() => _WikiPageState();
}

class _WikiPageState extends State<WikiPage> {
  final NotesRepository _repo = NotesRepository();
  final Uuid _uuid = const Uuid();

  List<NoteModel> _allNotes = []; // Toutes les notes chargées
  String? _currentFolderId;       // ID du dossier actuel (null = racine)
  
  // Fil d'Ariane pour la navigation (ex: Monde > Ville > Taverne)
  final List<NoteModel> _breadcrumbs = [];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  /// Charge les notes depuis le stockage
  Future<void> _loadNotes() async {
    final notes = await _repo.loadNotes();
    if (mounted) {
      setState(() {
        _allNotes = notes;
      });
    }
  }

  /// Sauvegarde la liste actuelle
  Future<void> _saveAll() async {
    await _repo.saveNotes(_allNotes);
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
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
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
                _saveAll();
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Supprimer ?"),
        content: const Text("Cette action est irréversible."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              setState(() {
                _allNotes.removeWhere((n) => n.id == id);
              });
              _saveAll();
              Navigator.pop(ctx);
            }, 
            child: const Text("Supprimer")
          ),
        ],
      ),
    );
  }

  // --- NAVIGATION ---

  void _enterFolder(NoteModel folder) {
    setState(() {
      _currentFolderId = folder.id;
      _breadcrumbs.add(folder);
    });
  }

  void _goBack() {
    if (_breadcrumbs.isEmpty) return;
    setState(() {
      _breadcrumbs.removeLast();
      _currentFolderId = _breadcrumbs.isEmpty ? null : _breadcrumbs.last.id;
    });
  }

  // --- ÉDITEUR (Page complète) ---
  
  void _openEditor(NoteModel note) {
    // On crée une route MaterialPageRoute pour ouvrir l'éditeur en plein écran
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _NoteEditorPage(
          note: note, 
          onSave: (id, title, content) => _saveNoteContent(id, title, content)
        ),
      ),
    );
  }

  void _saveNoteContent(String id, String newTitle, String newContent) {
    final idx = _allNotes.indexWhere((n) => n.id == id);
    if (idx != -1) {
      final oldNote = _allNotes[idx];
      final updatedNote = NoteModel(
        id: oldNote.id,
        title: newTitle,
        content: newContent,
        parentId: oldNote.parentId,
        isFolder: false,
        lastEdited: DateTime.now(),
      );

      setState(() {
        _allNotes[idx] = updatedNote;
      });
      _saveAll();
    }
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    // Filtre et Tri
    final currentItems = _allNotes.where((n) => n.parentId == _currentFolderId).toList();
    currentItems.sort((a, b) {
      if (a.isFolder && !b.isFolder) return -1;
      if (!a.isFolder && b.isFolder) return 1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    return WillPopScope(
      onWillPop: () async {
        if (_breadcrumbs.isNotEmpty) {
          _goBack();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_breadcrumbs.isEmpty ? "Wiki Campagne" : _breadcrumbs.last.title),
          leading: _breadcrumbs.isNotEmpty 
              ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _goBack)
              : null,
        ),
        body: currentItems.isEmpty 
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.folder_open, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text("Dossier vide", style: TextStyle(color: Colors.grey)),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: currentItems.length,
                itemBuilder: (context, index) {
                  final item = currentItems[index];
                  return ListTile(
                    leading: Icon(
                      item.isFolder ? Icons.folder : Icons.description,
                      color: item.isFolder ? Colors.amber : Colors.blueGrey,
                      size: 32,
                    ),
                    title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      item.isFolder 
                        ? "Dossier" 
                        : "Modifié le ${item.lastEdited.day}/${item.lastEdited.month}",
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
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
              child: const Icon(Icons.note_add),
            ),

// ---- DEBUG : Accès rapide à l'éditeur de carte (À supprimer en prod) ---

IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.redAccent),
            tooltip: 'Ouvrir Éditeur de Carte (Debug)',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const MapEditorPage()),
              );
            },
          ),
//--------------------------------------------------------------------------------
          ],
        ),
      ),
    );
  }
}

// --- WIDGET SÉPARÉ POUR L'ÉDITEUR (Plus propre) ---

class _NoteEditorPage extends StatefulWidget {
  final NoteModel note;
  final Function(String, String, String) onSave;

  const _NoteEditorPage({required this.note, required this.onSave});

  @override
  State<_NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<_NoteEditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _hasChanged = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _contentController = TextEditingController(text: widget.note.content);
  }

  void _save() {
    widget.onSave(widget.note.id, _titleController.text, _contentController.text);
    _hasChanged = false; // Reset après sauvegarde
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sauvegardé !"), duration: Duration(milliseconds: 500)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Édition"),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _save,
          )
        ],
      ),
      // WillPopScope pour prévenir si on quitte sans sauver
      body: WillPopScope(
        onWillPop: () async {
          if (_hasChanged) {
            _save(); // Sauvegarde auto en quittant (optionnel, mais pratique)
          }
          return true;
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _titleController,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: "Titre",
                  border: InputBorder.none,
                ),
                onChanged: (_) => _hasChanged = true,
              ),
              const Divider(),
              Expanded(
                child: TextField(
                  controller: _contentController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: "Écrivez votre scénario ici...",
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => _hasChanged = true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
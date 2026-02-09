import 'package:flutter/material.dart';
import '../../data/repositories/compendium_repository.dart';

class CompendiumEditorPage extends StatefulWidget {
  const CompendiumEditorPage({super.key});

  @override
  State<CompendiumEditorPage> createState() => _CompendiumEditorPageState();
}

class _CompendiumEditorPageState extends State<CompendiumEditorPage> {
  final CompendiumRepository _repo = CompendiumRepository();
  final _formKey = GlobalKey<FormState>();

  // État du formulaire
  String _selectedType = 'item'; // 'item' ou 'spell'
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _tagsCtrl = TextEditingController(); // Tags séparés par virgules

  // Contrôleurs spécifiques OBJET
  final TextEditingController _weightCtrl = TextEditingController(text: "0");
  final TextEditingController _qtyCtrl = TextEditingController(text: "1");

  // Contrôleurs spécifiques SORT
  final TextEditingController _levelCtrl = TextEditingController(text: "0");
  final TextEditingController _schoolCtrl = TextEditingController();

  bool _isSaving = false;

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    // 1. Construction du JSON dynamique (data)
    Map<String, dynamic> data = {
      "desc": _descCtrl.text,
    };

    if (_selectedType == 'item') {
      data["weight"] = double.tryParse(_weightCtrl.text) ?? 0.0;
      data["qty"] = int.tryParse(_qtyCtrl.text) ?? 1;
    } else {
      data["level"] = int.tryParse(_levelCtrl.text) ?? 0;
      data["school"] = _schoolCtrl.text;
    }

    // 2. Traitement des tags
    List<String> tags = _tagsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    // On ajoute le type comme tag automatique pour faciliter les filtres
    tags.add(_selectedType);

    // 3. Envoi au serveur
    bool success = await _repo.addEntry(
      type: _selectedType,
      name: _nameCtrl.text,
      data: data,
      tags: tags,
      campaignId: null, // Mettre l'ID de campagne ici si on veut restreindre (null = global pour l'instant)
    );

    setState(() => _isSaving = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Création réussie !")));
      Navigator.pop(context, true); // On renvoie "true" pour dire qu'on a créé un truc
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur lors de la création.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Éditeur du MJ")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- TYPE ---
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(labelText: "Type de création", border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'item', child: Text("Objet / Équipement")),
                  DropdownMenuItem(value: 'spell', child: Text("Sort / Magie")),
                ],
                onChanged: (val) => setState(() => _selectedType = val!),
              ),
              const SizedBox(height: 16),

              // --- CHAMPS COMMUNS ---
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: "Nom", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "Requis" : null,
              ),
              const SizedBox(height: 16),

              // --- CHAMPS DYNAMIQUES ---
              if (_selectedType == 'item') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _weightCtrl,
                        decoration: const InputDecoration(labelText: "Poids (kg)", border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _qtyCtrl,
                        decoration: const InputDecoration(labelText: "Qté par défaut", border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _levelCtrl,
                        decoration: const InputDecoration(labelText: "Niveau (0-9)", border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _schoolCtrl,
                        decoration: const InputDecoration(labelText: "École (ex: Évocation)", border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: "Description", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),

              // --- TAGS (Pour filtrer par classe par exemple) ---
              TextFormField(
                controller: _tagsCtrl,
                decoration: const InputDecoration(
                  labelText: "Tags & Classes compatibles",
                  hintText: "guerrier, feu, rare (séparés par virgules)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _submit,
                  icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
                  label: Text(_isSaving ? "Envoi..." : "AJOUTER AU COMPENDIUM"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../../../rules_engine/data/models/rule_system_model.dart';
import 'stat_input_widget.dart'; // On réutilise nos champs de base !

class DynamicListWidget extends StatefulWidget {
  final StatDefinitionModel definition; // La définition de la liste (ex: Inventaire)
  final List<StatDefinitionModel> itemStructure; // La structure d'un item (Nom, Poids...)
  final List<dynamic> currentList; // La liste actuelle des objets du perso
  final Function(List<dynamic>) onChanged; // Callback pour sauvegarder

  const DynamicListWidget({
    super.key,
    required this.definition,
    required this.itemStructure,
    required this.currentList,
    required this.onChanged,
  });

  @override
  State<DynamicListWidget> createState() => _DynamicListWidgetState();
}

class _DynamicListWidgetState extends State<DynamicListWidget> {
  
  // Fonction pour ouvrir la popup de création
  void _openAddItemDialog() {
    // On prépare un objet vide
    final Map<String, dynamic> newItem = {};
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Ajouter : ${widget.definition.name}"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: widget.itemStructure.map((def) {
                // Pour chaque champ de l'item, on crée un input
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: StatInputWidget(
                    definition: def,
                    currentValue: null, // Vide au début
                    onChanged: (val) {
                      newItem[def.id] = val;
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () {
                // On ajoute le nouvel item à la liste
                final newList = List.from(widget.currentList);
                newList.add(newItem);
                widget.onChanged(newList); // Sauvegarde
                Navigator.pop(context);
              },
              child: const Text("Ajouter"),
            ),
          ],
        );
      },
    );
  }

  // Fonction pour supprimer un item
  void _removeItem(int index) {
    final newList = List.from(widget.currentList);
    newList.removeAt(index);
    widget.onChanged(newList);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En-tête avec bouton "+"
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(widget.definition.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.blue),
              onPressed: _openAddItemDialog,
            ),
          ],
        ),
        
        // La liste des items
        if (widget.currentList.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("Vide", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
          )
        else
          ListView.builder(
            shrinkWrap: true, // Important pour être dans une Column
            physics: const NeverScrollableScrollPhysics(), // On laisse la page scroller
            itemCount: widget.currentList.length,
            itemBuilder: (context, index) {
              final item = widget.currentList[index] as Map;
              // On essaye de trouver le "titre" de l'objet (souvent le champ 'name')
              final title = item['name'] ?? "Objet #${index + 1}";
              
              // On construit un sous-titre avec les autres champs
              String subtitle = "";
              item.forEach((k, v) {
                if (k != 'name') subtitle += "$k: $v | ";
              });

              return Card(
                elevation: 1,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(title.toString()),
                  subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: Colors.redAccent),
                    onPressed: () => _removeItem(index),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
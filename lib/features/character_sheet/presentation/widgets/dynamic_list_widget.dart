import 'package:flutter/material.dart';
import '../../../rules_engine/data/models/rule_system_model.dart'; 

class DynamicListWidget extends StatefulWidget {
  final StatDefinition definition;
  final List<Map<String, dynamic>> items;
  final Function(List<Map<String, dynamic>>) onChanged;
  final List<DataDefinition> dataDefs;
  final List<Map<String, dynamic>> presets; 

  const DynamicListWidget({
    super.key,
    required this.definition,
    required this.items,
    required this.onChanged,
    required this.dataDefs,
    this.presets = const [], 
  });

  @override
  State<DynamicListWidget> createState() => _DynamicListWidgetState();
}

class _DynamicListWidgetState extends State<DynamicListWidget> {
  
  void _openAddItemDialog() {
    final Map<String, TextEditingController> controllers = {};
    
    // Initialisation
    for (var field in widget.dataDefs) {
      controllers[field.id] = TextEditingController();
      if (field.id == 'qty') controllers[field.id]!.text = "1";
    }

    // On définit une largeur fixe pour le dialog pour éviter le crash
    const double dialogWidth = 350.0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Ajouter : ${widget.definition.name}"),
        // CORRECTION CRASH : On impose une largeur fixe ici
        content: SizedBox(
          width: dialogWidth,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min, 
              children: widget.dataDefs.map((fieldDef) {
                
                // --- Autocomplete sécurisé ---
                if (fieldDef.id == 'name' && widget.presets.isNotEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Autocomplete<Map<String, dynamic>>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text == '') return const Iterable.empty();
                        return widget.presets.where((option) => 
                          option['name'].toString().toLowerCase().contains(textEditingValue.text.toLowerCase())
                        );
                      },
                      displayStringForOption: (option) => option['name'],
                      
                      // Affichage de la liste déroulante
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4.0,
                            // CORRECTION : La liste fait exactement la même largeur que le dialog
                            child: SizedBox(
                              width: dialogWidth, 
                              height: 200, // Hauteur max de la liste
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: options.length,
                                itemBuilder: (context, index) {
                                  final option = options.elementAt(index);
                                  return ListTile(
                                    title: Text(option['name']),
                                    // Petit bonus : affiche le poids ou niveau si dispo
                                    trailing: option['weight'] != null ? Text("${option['weight']} kg") : null,
                                    onTap: () => onSelected(option),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                      
                      onSelected: (selection) {
                        controllers['name']?.text = selection['name'];
                        // Remplissage automatique des autres champs
                        selection.forEach((key, value) {
                          if (key != 'name' && controllers.containsKey(key)) {
                            controllers[key]?.text = value.toString();
                          }
                        });
                      },
                      
                      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                        if (textController.text.isEmpty && controllers['name']!.text.isNotEmpty) {
                           textController.text = controllers['name']!.text;
                        }
                        controllers['name'] = textController;
                        return TextField(
                          controller: textController,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: "Nom (Rechercher...)", 
                            border: const OutlineInputBorder(), 
                            suffixIcon: const Icon(Icons.search)
                          ),
                        );
                      },
                    ),
                  );
                }

                // --- Champs Texte Normaux ---
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: TextField(
                    controller: controllers[fieldDef.id],
                    decoration: InputDecoration(labelText: fieldDef.name, border: const OutlineInputBorder()),
                    keyboardType: fieldDef.type == 'integer' ? TextInputType.number : TextInputType.text,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () {
              final Map<String, dynamic> newItem = {};
              for (var f in widget.dataDefs) {
                final text = controllers[f.id]?.text ?? "";
                if (f.type == 'integer') {
                  newItem[f.id] = int.tryParse(text) ?? 0;
                } else {
                  newItem[f.id] = text;
                }
              }
              final updatedList = List<Map<String, dynamic>>.from(widget.items);
              updatedList.add(newItem);
              widget.onChanged(updatedList);
              Navigator.pop(ctx);
            },
            child: const Text("Ajouter"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(widget.definition.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            IconButton(icon: Icon(Icons.add_circle, color: Theme.of(context).colorScheme.secondary), onPressed: _openAddItemDialog),
          ],
        ),
        const SizedBox(height: 8),
        if (widget.items.isEmpty)
          const Padding(padding: EdgeInsets.all(8.0), child: Text("Vide", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.items.length,
            itemBuilder: (context, index) {
              final item = widget.items[index];
              
              // Détermination du titre
              String title = "Objet";
              if (item.containsKey('name')) {
                title = item['name'];
              } else if (widget.dataDefs.isNotEmpty) title = item[widget.dataDefs.first.id]?.toString() ?? "Objet";

              // Détermination des détails (Sous-titre)
              String details = item.entries
                  .where((e) => e.key != 'name' && e.key != widget.dataDefs.firstOrNull?.id)
                  .map((e) => "${e.key}: ${e.value}")
                  .join(", ");

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(title),
                  subtitle: details.isNotEmpty ? Text(details, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                    onPressed: () {
                      final updatedList = List<Map<String, dynamic>>.from(widget.items);
                      updatedList.removeAt(index);
                      widget.onChanged(updatedList);
                    },
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import '../../../rules_engine/data/models/rule_system_model.dart';
import '../../data/models/character_model.dart';
import '../widgets/stat_input_widget.dart';
import '../../data/repositories/character_repository_impl.dart'; // Pour la sauvegarde auto
import '../widgets/dynamic_list_widget.dart';
import 'package:image_picker/image_picker.dart';
import '..//widgets/character_avatar.dart';




class CharacterSheetPage extends StatefulWidget {
  final CharacterModel character;
  final RuleSystemModel rules;

  const CharacterSheetPage({
    super.key,
    required this.character,
    required this.rules,
  });

  @override
  State<CharacterSheetPage> createState() => _CharacterSheetPageState();
}

class _CharacterSheetPageState extends State<CharacterSheetPage> {
  final CharacterRepositoryImpl _repo = CharacterRepositoryImpl();

Future<void> _pickImage() async {
  final picker = ImagePicker();
  // On ouvre la galerie
  final XFile? image = await picker.pickImage(source: ImageSource.gallery);

  if (image != null) {
    setState(() {
      // On met à jour le modèle avec le nouveau chemin
      // Attention : on doit recréer l'objet car les champs sont 'final' (si vous n'avez pas fait de copyWith, modifiez directement le modèle ou utilisez une méthode set)

      // Option A : Si vous avez ajouté copyWith dans le modèle (recommandé)
      // widget.character = widget.character.copyWith(imagePath: image.path); 

      // Option B : Hack rapide si pas de copyWith (mais moins propre)
      // On suppose que vous allez ajouter une méthode setter ou gérer le state différemment.
      // Pour faire simple ici, on va supposer que vous avez accès aux champs ou une méthode update.

      // LE PLUS SIMPLE POUR CE MVP (Modifiez votre modèle pour avoir un setter temporaire ou utilisez le map stats si vous préférez, mais le mieux est de modifier le champ 'imagePath' dans le modèle pour qu'il ne soit pas final, OU d'utiliser une méthode dédiée).

      // Solution recommandée : Ajoutez cette méthode dans CharacterModel :
      // void setImage(String path) { this.imagePath = path; } (en enlevant le 'final')

      // OU (Mieux) recréez l'objet via une méthode update dans le parent.
      // Ici, on va tricher légèrement en modifiant le JSON interne si besoin, ou mieux :

      // UTILISONS LE REPO DIRECTEMENT :
      final newChar = CharacterModel(
         id: widget.character.id,
         name: widget.character.name,
         imagePath: image.path, // <--- Nouveau chemin
         stats: widget.character.stats // On garde les stats
         
      );

      // On sauvegarde
      _repo.saveCharacter(newChar);

      // On force le rafraîchissement de la page actuelle (attention c'est un peu brute)
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (ctx) => CharacterSheetPage(character: newChar, rules: widget.rules))
      );
    });
  }
}



  // Fonction utilitaire pour trouver la définition d'une stat via son ID
  StatDefinitionModel? _getDef(String id) {
    try {
      return widget.rules.statDefinitions.firstWhere((e) => e.id == id);
    } catch (e) {
      return null; // Si l'ID n'existe pas dans les règles
    }
  }

  // Sauvegarde automatique à chaque modif
void _onStatChanged(String id, dynamic value) {
  // 1. On met à jour la donnée en mémoire (c'est instantané)
  widget.character.setStat(id, value);
  
  // 2. On sauvegarde sans forcer le rafraîchissement de l'écran
  // Le widget StatInputWidget garde la valeur visuelle car il a son propre Controller
  _repo.saveCharacter(widget.character);
  
  // NOTE : On ne fait PAS de setState() ici. 
  // Cela empêche la page de se reconstruire à chaque lettre tapée.
}

  @override
  Widget build(BuildContext context) {
    // Si aucun layout n'est défini dans le JSON, on affiche une erreur ou une vue par défaut
    if (widget.rules.layout == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.character.name)),
        body: const Center(child: Text("Erreur: Pas de 'layout' dans le fichier JSON.")),
      );
    }

    final layout = widget.rules.layout!;

    // DefaultTabController gère la navigation entre onglets
    return DefaultTabController(
      length: layout.tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.character.name),
          actions: [ Padding( padding: const EdgeInsets.only(right: 16.0),
          child: CharacterAvatar(
            imagePath: widget.character.imagePath,
            size: 20, 
            onTap: _pickImage,
          ),
        ),
      ],
          bottom: TabBar(
            isScrollable: true, // Permet d'avoir plein d'onglets
            tabs: layout.tabs.map((t) => Tab(text: t)).toList(),
          ),
        ),
        body: TabBarView(
          children: layout.tabs.map((tabName) {
            return _buildTabContent(tabName, layout);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTabContent(String tabName, LayoutModel layout) {
    // 1. On filtre les sections qui appartiennent à cet onglet
    final sections = layout.sections.where((s) => s.tab == tabName).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: sections.map((section) {
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titre de la section
                Text(
                  section.title.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 12, 
                      fontWeight: FontWeight.bold, 
                      color: Colors.grey),
                ),
                const Divider(),
                
                // Les champs contenus dans la section
                ...section.contains.map((statId) {
                  final def = _getDef(statId);
                  if (def == null) return Text("Erreur ID: $statId");

                  if (def.type == 'list' && def.dataRef != null) {
    // On récupère la structure de l'item depuis les règles
    final itemStructure = widget.rules.dataDefinitions[def.dataRef];
    
    if (itemStructure != null) {
       // On s'assure que la valeur actuelle est bien une liste
       final currentVal = widget.character.getStat(statId);
       final List<dynamic> listValue = (currentVal is List) ? currentVal : [];

       return DynamicListWidget(
         key: ValueKey(statId), // Toujours mettre la Key !
         definition: def,
         itemStructure: itemStructure,
         currentList: listValue,
         onChanged: (newList) => _onStatChanged(statId, newList),
       );
    }
  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: StatInputWidget(
                      key: ValueKey(statId),
                      definition: def,
                      currentValue: widget.character.getStat(statId),
                      onChanged: (val) => _onStatChanged(statId, val),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
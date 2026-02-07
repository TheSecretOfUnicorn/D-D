// lib/features/rules_engine/presentation/pages/rules_debug_page.dart

import 'package:flutter/material.dart';
import '../../data/repositories/rules_repository_impl.dart';
import '../../data/models/rule_system_model.dart';
import '../../../character_sheet/domain/factories/character_factory.dart';
import '../../../character_sheet/data/models/character_model.dart';
import '../../../character_sheet/presentation/widgets/stat_input_widget.dart';
import '../../../character_sheet/data/repositories/character_repository_impl.dart';
import '../../../character_sheet/presentation/pages/character_sheet_page.dart';

class RulesDebugPage extends StatefulWidget {
  const RulesDebugPage({super.key});

  @override
  State<RulesDebugPage> createState() => _RulesDebugPageState();
}

class _RulesDebugPageState extends State<RulesDebugPage> {
  // On instancie le repository
  final RulesRepositoryImpl _repository = RulesRepositoryImpl();
  final CharacterRepositoryImpl _charRepo = CharacterRepositoryImpl();

        CharacterModel? _generatedCharacter;
  
  // On prépare une variable pour stocker le futur résultat
  late Future<RuleSystemModel> _rulesFuture;

 

@override
  void initState() {
    super.initState();
    // Au lancement de la page, on lance le chargement
    _rulesFuture = _repository.loadDefaultRules();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Debug: Moteur de Règles"),
        backgroundColor: Colors.blueGrey,
      ),
 body: FutureBuilder<RuleSystemModel>(
        future: _rulesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const CircularProgressIndicator(); // Simplifié pour l'exemple
          
          final rules = snapshot.data!;
          
          return Column(
  children: [
    // --- ZONE DE CONTRÔLE ---
    Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          // Bouton Générer (Existant)
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                final factory = CharacterFactory();
                // Note : rules est disponible ici grâce au FutureBuilder
                if (snapshot.hasData) {
                   _generatedCharacter = factory.createBlankCharacter(snapshot.data!);
                }
              });
            },
            icon: const Icon(Icons.add),
            label: const Text("Nouveau Perso (Reset)"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade100),
          ),
          
          const SizedBox(height: 8),
          
          // Nouveaux Boutons : SAUVER / CHARGER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // BOUTON SAUVER
              ElevatedButton.icon(
                onPressed: _generatedCharacter == null ? null : () async {
                  // On sauvegarde le perso actuel
                  await _charRepo.saveCharacter(_generatedCharacter!);
                  
                  // Petit feedback visuel (SnackBar)
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Personnage sauvegardé !")),
                    );
                  }
                },
                icon: const Icon(Icons.save),
                label: const Text("Sauvegarder"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade100),
              ),



              ElevatedButton.icon(
                onPressed: _generatedCharacter == null ? null : () { // NAVIGATION VERS LA VRAIE FICHE                                                                       
                     Navigator.push(
                       context,
      MaterialPageRoute(
        builder: (context) => CharacterSheetPage(
          character: _generatedCharacter!,
          rules: snapshot.data!, // Les règles chargées
        ),
      ),
    );
  },
  icon: const Icon(Icons.person),
  label: const Text("Ouvrir Fiche Complète"),
  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade100),
),

            ],
          ),
        ],
      ),
    ),
    
    const Divider(),
    // ... La suite (Row avec les 2 colonnes) reste inchangée

              // Affichage du résultat
              Expanded(
                child: Row(
                  children: [
                    // Colonne de gauche : Les Règles (Définitions)
                    Expanded(
                      child: Column(
                        children: [
                          const Text("Règles (JSON)", style: TextStyle(fontWeight: FontWeight.bold)),
                          Expanded(child: _buildRulesList(rules)),
                        ],
                      ),
                    ),
                    
                    const VerticalDivider(width: 1),

                    // Colonne de droite : Le Personnage (Instance)
                    Expanded(
                      child: Column(
                        children: [
                          const Text("Personnage (Mémoire)", style: TextStyle(fontWeight: FontWeight.bold)),
                          Expanded(
                            child: _generatedCharacter == null
                                ? const Center(child: Text("Cliquez sur le bouton"))
                                : _buildCharacterView(rules, _generatedCharacter!),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Une méthode helper pour dessiner la liste quand on a les données
  Widget _buildRulesList(RuleSystemModel rules) {
    return Column(
      children: [
        // En-tête avec les infos du système
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blueGrey.shade50,
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Système : ${rules.systemName}", 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text("Version : ${rules.version}"),
              Text("ID : ${rules.systemId}"),
            ],
          ),
        ),
        const Divider(height: 1),
        
        // Liste des statistiques définies
        Expanded(
          child: ListView.builder(
            itemCount: rules.statDefinitions.length,
            itemBuilder: (context, index) {
              final stat = rules.statDefinitions[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blueGrey.shade100,
                  child: Text(stat.id.substring(0, 1).toUpperCase()), // Affiche 1ère lettre de l'ID
                ),
                title: Text(stat.name),
                subtitle: Text("ID: ${stat.id} | Type: ${stat.type}"),
                trailing: stat.min != null && stat.max != null 
                    ? Text("[${stat.min} - ${stat.max}]") 
                    : const Text("-"),
              );
            },
          ),
        ),
      ],
    );
  }
}

Widget _buildCharacterView(RuleSystemModel rules, CharacterModel char) {
    // On utilise un ListView pour scroller si la fiche est longue
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: rules.statDefinitions.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 12), // Espace entre les champs
      itemBuilder: (context, index) {
        final def = rules.statDefinitions[index];
        final value = char.getStat(def.id);

        return StatInputWidget(
          definition: def,
          currentValue: value,
          onChanged: (newValue) {
            // C'est ici que la magie opère :
            // 1. On met à jour le modèle en mémoire
            char.setStat(def.id, newValue);
            
            // 2. On affiche un log pour confirmer (debug)
            print("Mise à jour de ${def.id} -> $newValue");
            
            // Note: Pas besoin de setState() ici car le TextField gère son propre affichage
            // Mais si on avait des calculs dérivés (Force -> Modificateur), 
            // il faudrait setState() pour tout recalculer.
          },
        );
      },
    );
  }
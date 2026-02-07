import 'package:flutter/material.dart';
import '../../data/models/combatant_model.dart';
import '../../../character_sheet/data/models/character_model.dart';// Importez votre repository pour pouvoir charger les persos existants
import '../../../character_sheet/data/repositories/character_repository_impl.dart';
import 'dart:math'; // Pour le random

class CombatPage extends StatefulWidget {
  const CombatPage({super.key});

  @override
  State<CombatPage> createState() => _CombatPageState();
}

class _CombatPageState extends State<CombatPage> {
  final CharacterRepositoryImpl _charRepo = CharacterRepositoryImpl();
  
  // La liste des gens qui se battent
  final List<CombatantModel> _combatants = [];
  
  // Index du joueur dont c'est le tour (-1 = le combat n'a pas commencé)
  int _currentTurnIndex = -1;
  int _round = 1;

  // --- LOGIQUE MÉTIER ---

  // Ajoute un personnage existant au combat
  void _addCharacter(CharacterModel char) {
    setState(() {
      _combatants.add(CombatantModel(
        id: DateTime.now().toString(), // ID temporaire unique
        name: char.name,
        initiative: 0, // À définir plus tard
        character: char,
      ));
    });
  }

  // Ajoute un monstre générique (sans fiche)
  void _addMonster() {
    setState(() {
      _combatants.add(CombatantModel(
        id: DateTime.now().toString(),
        name: "Monstre ${_combatants.length + 1}",
        initiative: 0,
      ));
    });
  }

  // Trie la liste par initiative décroissante
  void _sortInitiative() {
    setState(() {
      _combatants.sort((a, b) => b.initiative.compareTo(a.initiative));
      _currentTurnIndex = 0; // Le premier commence
      _round = 1;
    });
  }

  // Passe au suivant
  void _nextTurn() {
    if (_combatants.isEmpty) return;
    
    setState(() {
      if (_currentTurnIndex < _combatants.length - 1) {
        _currentTurnIndex++;
      } else {
        // Fin du round, on boucle
        _currentTurnIndex = 0;
        _round++;
      }
    });
  }

  // Supprime un combattant (mort)
  void _removeCombatant(int index) {
    setState(() {
      _combatants.removeAt(index);
      // Si on supprime quelqu'un avant le tour actuel, il faut décaler l'index
      if (index < _currentTurnIndex) {
        _currentTurnIndex--;
      }
    });
  }

  // --- UI ---

  // Popup pour choisir qui ajouter
  void _showAddDialog() async {
    // On charge les persos dispos
    final availableChars = await _charRepo.getAllCharacters();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.bug_report),
              title: const Text("Ajouter Monstre Générique"),
              onTap: () {
                _addMonster();
                Navigator.pop(ctx);
              },
            ),
            const Divider(),
            ...availableChars.map((char) => ListTile(
              leading: const Icon(Icons.person),
              title: Text(char.name),
              onTap: () {
                _addCharacter(char);
                Navigator.pop(ctx);
              },
            )),
          ],
        );
      },
    );
  }
// Méthode pour ouvrir le Gestionnaire d'Initiative
  void _openInitiativeManager() {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder( // Permet de mettre à jour le Dialog sans le fermer
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Gestion de l'Initiative"),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- BARRE D'OUTILS ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Bouton 1 : Lancer pour TOUT LE MONDE (Full App)
                        IconButton(
                          icon: const Icon(Icons.casino, color: Colors.blue),
                          tooltip: "Tout lancer (Virtuel)",
                          onPressed: () {
                            setDialogState(() {
                              _rollInitiativeFor((c) => true); // Filtre : Tous
                            });
                          },
                        ),
                        // Bouton 2 : Lancer pour les MONSTRES (Hybride)
                        IconButton(
                          icon: const Icon(Icons.smart_toy, color: Colors.orange),
                          tooltip: "Lancer pour PNJ/Monstres uniquement",
                          onPressed: () {
                            setDialogState(() {
                              // On lance seulement si ce n'est pas un perso lié (donc un monstre)
                              _rollInitiativeFor((c) => c.character == null);
                            });
                          },
                        ),
                        // Bouton 3 : Reset (Full Manuel)
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.grey),
                          tooltip: "Remise à zéro",
                          onPressed: () {
                            setDialogState(() {
                              for (int i = 0; i < _combatants.length; i++) {
                                _combatants[i] = _combatants[i].copyWith(initiative: 0);
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    const Divider(),
                    const Text(
                      "Saisissez les résultats physiques ou utilisez les boutons ci-dessus.",
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    
                    // --- LISTE DES COMBATTANTS ---
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _combatants.length,
                        itemBuilder: (ctx, index) {
                          final c = _combatants[index];
                          // Contrôleur pour saisir manuellement
                          final TextEditingController ctrl = TextEditingController(
                            text: c.initiative == 0 ? "" : c.initiative.toString()
                          );

                          return ListTile(
                            dense: true,
                            leading: Icon(
                              c.character != null ? Icons.person : Icons.bug_report,
                              color: c.character != null ? Colors.blue : Colors.red,
                            ),
                            title: Text(c.name),
                            trailing: SizedBox(
                              width: 60,
                              child: TextField(
                                controller: ctrl,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  hintText: "d20",
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onSubmitted: (val) {
                                  // Sauvegarde à la validation (touche Entrée)
                                  final newVal = int.tryParse(val) ?? 0;
                                  setState(() { // Met à jour la vraie liste derrière
                                    _combatants[index] = c.copyWith(initiative: newVal);
                                  });
                                },
                                onChanged: (val) {
                                  // Sauvegarde en temps réel
                                  final newVal = int.tryParse(val) ?? 0;
                                  // Attention: ici on modifie la liste principale directement
                                  // pour que si on clique sur "Trier", ce soit pris en compte
                                  _combatants[index] = c.copyWith(initiative: newVal);
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Fermer"),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.sort),
                  label: const Text("Valider & Trier"),
                  onPressed: () {
                    _sortInitiative(); // Trie la liste
                    Navigator.pop(context);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Fonction utilitaire pour lancer les dés selon un filtre
  void _rollInitiativeFor(bool Function(CombatantModel) filter) {
    final rng = Random();
    setState(() {
      for (int i = 0; i < _combatants.length; i++) {
        if (filter(_combatants[i])) {
          // Si le perso a de la DEX, on pourrait l'ajouter ici.
          // Pour l'instant : d20 simple + modif aléatoire pour éviter les égalités
          int roll = rng.nextInt(20) + 1;
          
          // Bonus : Si on a la fiche, on essaie de trouver la Dex
          int bonus = 0;
          if (_combatants[i].character != null) {
             final dex = _combatants[i].character!.getStat('dex');
             if (dex is int) {
               bonus = ((dex - 10) / 2).floor(); // Formule D&D standard
             }
          }
          
          _combatants[i] = _combatants[i].copyWith(initiative: roll + bonus);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Combat - Round $_round"),
        backgroundColor: Colors.redAccent.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt), // Icône de liste/gestion
            tooltip: "Gérer l'Initiative (Manuel/Auto)",
            onPressed: _openInitiativeManager, // Ouvre le nouveau dialog
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _showAddDialog,
          )
        ],
      ),
      body: Column(
        children: [
          // La Liste des combattants
          Expanded(
            child: ReorderableListView(
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (oldIndex < newIndex) newIndex -= 1;
                  final item = _combatants.removeAt(oldIndex);
                  _combatants.insert(newIndex, item);
                });
              },
              children: [
                for (int index = 0; index < _combatants.length; index++)
                  _buildCombatantCard(index, _combatants[index])
              ],
            ),
          ),
          
          // La barre de contrôle en bas
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade900,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _currentTurnIndex >= 0 
                      ? "Tour : ${_combatants[_currentTurnIndex].name}" 
                      : "Prêt ?",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                FloatingActionButton(
                  onPressed: _nextTurn,
                  backgroundColor: Colors.amber,
                  child: const Icon(Icons.skip_next, color: Colors.black),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCombatantCard(int index, CombatantModel c) {
    final isActive = index == _currentTurnIndex;
    
    return Card(
      key: ValueKey(c.id), // Important pour le ReorderableListView
      color: isActive ? Colors.red.shade50 : null,
      elevation: isActive ? 8 : 1,
      shape: isActive 
          ? RoundedRectangleBorder(side: const BorderSide(color: Colors.red, width: 2), borderRadius: BorderRadius.circular(4))
          : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isActive ? Colors.red : Colors.grey,
          child: Text("${c.initiative}"), // Affiche le score d'initiative
        ),
        title: Text(
          c.name, 
          style: TextStyle(
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: isActive ? 18 : 14
          )
        ),
        // Champ pour éditer l'initiative manuellement
        trailing: SizedBox(
          width: 100,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  _editInitiative(index);
                },
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => _removeCombatant(index),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Petit dialog pour changer le score d'initiative
  void _editInitiative(int index) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Score d'initiative"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              final val = int.tryParse(controller.text) ?? 0;
              setState(() {
                // On crée une copie avec la nouvelle valeur (Immutabilité)
                _combatants[index] = _combatants[index].copyWith(initiative: val);
              });
              Navigator.pop(ctx);
            }, 
            child: const Text("OK")
          )
        ],
      ),
    );
  }
}
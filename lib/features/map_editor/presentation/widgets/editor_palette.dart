import 'package:flutter/material.dart';
import '../../data/models/tile_type.dart';
import '../../data/models/world_object_model.dart'; 
import '../pages/map_editor_page.dart';
import 'compendium_tab.dart'; // <--- Import du nouveau fichier

class EditorPalette extends StatefulWidget {
  final EditorTool selectedTool;
  final TileType selectedTileType;
  final ObjectType selectedObjectType;
  final Function(EditorTool) onToolChanged;
  final Function(TileType) onTileTypeChanged;
  final Function(ObjectType) onObjectTypeChanged;
  final bool isPortrait;

  const EditorPalette({
    super.key,
    required this.selectedTool,
    required this.selectedTileType,
    required this.selectedObjectType,
    required this.onToolChanged,
    required this.onTileTypeChanged,
    required this.onObjectTypeChanged,
    required this.isPortrait,
  });

  @override
  State<EditorPalette> createState() => _EditorPaletteState();
}

class _EditorPaletteState extends State<EditorPalette> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.isPortrait ? double.infinity : 250, // Un peu plus large pour le bestiaire
      height: widget.isPortrait ? 250 : double.infinity,
      color: const Color(0xFF1E1E1E),
      child: Column(
        children: [
          // Onglets
          TabBar(
            controller: _tabController,
            indicatorColor: Colors.blueAccent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(icon: Icon(Icons.build), text: "Outils"),
              Tab(icon: Icon(Icons.menu_book), text: "Bestiaire"),
            ],
          ),
          
          // Contenu des onglets
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ONGLET 1 : OUTILS D'ÉDITION (Ton ancien code)
                _buildToolsTab(),
                
                // ONGLET 2 : BESTIAIRE (Nouveau code)
                const CompendiumTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TON ANCIEN CODE D'ÉDITEUR, DÉPLACÉ DANS UNE MÉTHODE ---
  Widget _buildToolsTab() {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        _buildSectionTitle("Actions"),
        _buildToolRow(),
        const SizedBox(height: 16),
        _buildSectionTitle("Objets Interactifs"),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ObjectOption(
              label: "Porte", icon: Icons.door_front_door, type: ObjectType.door,
              selectedType: widget.selectedObjectType, selectedTool: widget.selectedTool, onTap: (t) { widget.onObjectTypeChanged(t); widget.onToolChanged(EditorTool.object); },
            ),
            _ObjectOption(
              label: "Coffre", icon: Icons.inventory_2, type: ObjectType.chest,
              selectedType: widget.selectedObjectType, selectedTool: widget.selectedTool, onTap: (t) { widget.onObjectTypeChanged(t); widget.onToolChanged(EditorTool.object); },
            ),
            _ObjectOption(
              label: "Torche", icon: Icons.whatshot, type: ObjectType.torch,
              selectedType: widget.selectedObjectType, selectedTool: widget.selectedTool, onTap: (t) { widget.onObjectTypeChanged(t); widget.onToolChanged(EditorTool.object); },
            ),
            _ToolIconButton(Icons.touch_app, "Utiliser", EditorTool.interact, widget.selectedTool, widget.onToolChanged),
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionTitle("Terrains & Murs"),
        _buildTileGrid([
          _TileOption("Pierre", Colors.grey, TileType.stoneFloor),
          _TileOption("Bois", Colors.brown.shade400, TileType.woodFloor),
          _TileOption("Herbe", Colors.green.shade800, TileType.grass),
          _TileOption("Terre", Colors.brown.shade700, TileType.dirt),
          _TileOption("Eau", Colors.blueAccent, TileType.water),
          _TileOption("Lave", Colors.orangeAccent, TileType.lava),
          _TileOption("Mur", Colors.grey.shade800, TileType.stoneWall),
          _TileOption("Arbre", Colors.green.shade900, TileType.tree),
        ]),
      ],
    );
  }
  
  // ... (Garder les méthodes helpers _buildSectionTitle, _buildToolRow, _buildTileGrid, _TileOption, _ObjectOption, _ToolIconButton inchangées) ...
  // JE LES REMETS ICI POUR ÊTRE SÛR QUE TU NE LES PERDES PAS :

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(title.toUpperCase(), style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildToolRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ToolIconButton(Icons.pan_tool, "Vue", EditorTool.move, widget.selectedTool, widget.onToolChanged),
        _ToolIconButton(Icons.loop, "Tourner", EditorTool.rotate, widget.selectedTool, widget.onToolChanged),
        _ToolIconButton(Icons.format_color_fill, "Remplir", EditorTool.fill, widget.selectedTool, widget.onToolChanged),
        _ToolIconButton(Icons.person, "Pions", EditorTool.token, widget.selectedTool, widget.onToolChanged),
        _ToolIconButton(Icons.cleaning_services, "Gomme", EditorTool.eraser, widget.selectedTool, widget.onToolChanged),
        
        
      ],
    );
  }

  Widget _buildTileGrid(List<_TileOption> options) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = widget.selectedTool == EditorTool.brush && widget.selectedTileType == opt.type;
        return GestureDetector(
          onTap: () {
            widget.onToolChanged(EditorTool.brush);
            widget.onTileTypeChanged(opt.type);
          },
          child: Container(
            width: 80,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blueAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
              border: Border.all(color: isSelected ? Colors.blueAccent : Colors.transparent, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(color: opt.color, shape: BoxShape.circle, border: Border.all(color: Colors.white30)),
                ),
                const SizedBox(height: 4),
                Text(opt.label, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 10), textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TileOption {
  final String label;
  final Color color;
  final TileType type;
  _TileOption(this.label, this.color, this.type);
}

class _ObjectOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final ObjectType type;
  final ObjectType selectedType;
  final EditorTool selectedTool;
  final Function(ObjectType) onTap;

  const _ObjectOption({
    required this.label,
    required this.icon,
    required this.type,
    required this.selectedType,
    required this.selectedTool,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = (type == selectedType) && (selectedTool == EditorTool.object);
    return GestureDetector(
      onTap: () => onTap(type),
      child: Container(
        width: 60,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: isSelected ? Colors.purpleAccent : Colors.transparent, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.white70, size: 20),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

class _ToolIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final EditorTool tool;
  final EditorTool currentGroup;
  final Function(EditorTool) onTap;

  const _ToolIconButton(this.icon, this.label, this.tool, this.currentGroup, this.onTap);

  @override
  Widget build(BuildContext context) {
    final isSelected = tool == currentGroup;
    return Column(
      children: [
        IconButton(
          icon: Icon(icon),
          color: isSelected ? Colors.blueAccent : Colors.grey,
          style: IconButton.styleFrom(
            backgroundColor: isSelected ? Colors.blueAccent.withValues(blue: 0.1) : Colors.transparent,
          ),
          onPressed: () => onTap(tool),
        ),
        Text(label, style: TextStyle(color: isSelected ? Colors.blueAccent : Colors.grey, fontSize: 10)),
      ],
    );
  }
}
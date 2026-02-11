import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../../domain/models/map_config_model.dart';
import '../../../../core/utils/hex_utils.dart'; 
import '../painters/grid_painter.dart';
import '../painters/tile_layer_painter.dart';
import '../painters/background_pattern_painter.dart';
import '../../../../core/utils/image_loader.dart';

// Enum pour savoir quel outil est actif
enum EditorTool { brush, eraser }

class MapEditorPage extends StatefulWidget {
  const MapEditorPage({Key? key}) : super(key: key);

  @override
  State<MapEditorPage> createState() => _MapEditorPageState();
}

class _MapEditorPageState extends State<MapEditorPage> {
  final mapConfig = const MapConfig(
    widthInCells: 20,
    heightInCells: 15,
    cellSize: 64.0, 
    backgroundColor: Color(0xFFE0D8C0), 
    gridColor: Color(0x4D5C4033),       
  );

  final TransformationController _transformationController = TransformationController();
  
  ui.Image? _parchmentTexture;
  ui.Image? _floorTexture;
  bool _isLoading = true;

  // --- ÉTAT DE L'ÉDITEUR ---
  Set<String> _paintedCells = {};      // Les cases peintes
  EditorTool _selectedTool = EditorTool.brush; // L'outil sélectionné (Pinceau par défaut)

  // Maths précises
  double get _hexRadius => mapConfig.cellSize / HexUtils.sqrt3;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    try {
      final parchment = await ImageLoader.loadAsset('assets/images/ui/parchment_bg.png');
      final floor = await ImageLoader.loadAsset('assets/images/tiles/stone_floor.png');
      if (mounted) setState(() { _parchmentTexture = parchment; _floorTexture = floor; _isLoading = false; });
    } catch (e) { debugPrint("⚠️ Erreur Assets: $e"); }
  }

  // --- GESTION DU CLIC SUR LE CANVAS ---
  void _onCanvasTap(TapUpDetails details) {
    // 1. On trouve quelle case a été touchée
    final point = HexUtils.pixelToGrid(
      details.localPosition, 
      _hexRadius, 
      mapConfig.widthInCells, 
      mapConfig.heightInCells
    );

    // 2. Si le clic est valide (dans la grille)
    if (point.x >= 0 && point.y >= 0) {
      final String key = "${point.x},${point.y}";
      
      // On copie le Set pour que Flutter détecte le changement
      final newSet = Set<String>.from(_paintedCells);
      
      // 3. Action selon l'outil sélectionné
      if (_selectedTool == EditorTool.brush) {
        newSet.add(key); // Ajouter (Peindre)
      } else if (_selectedTool == EditorTool.eraser) {
        newSet.remove(key); // Enlever (Gommer)
      }

      setState(() {
        _paintedCells = newSet;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calcul de la taille du canvas
    final w = (mapConfig.widthInCells + 0.5) * HexUtils.width(_hexRadius);
    final h = (mapConfig.heightInCells * 0.75 * HexUtils.height(_hexRadius)) + HexUtils.height(_hexRadius);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Éditeur Hexagonal"), 
        backgroundColor: const Color(0xFF1a1a1a)
      ),
      backgroundColor: const Color(0xFF121212),
      
      // --- CORRECTION : ON REMET LE 'ROW' POUR AVOIR LA PALETTE A GAUCHE ---
      body: Row(
        children: [
          // 1. LA PALETTE D'OUTILS (Gauche)
          Container(
            width: 80,
            color: const Color(0xFF252525),
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Text("OUTILS", style: TextStyle(color: Colors.white54, fontSize: 10)),
                const SizedBox(height: 10),
                
                // Bouton PINCEAU
                _ToolButton(
                  icon: Icons.brush,
                  label: "Peindre",
                  isSelected: _selectedTool == EditorTool.brush,
                  onTap: () => setState(() => _selectedTool = EditorTool.brush),
                ),
                
                const SizedBox(height: 10),
                
                // Bouton GOMME
                _ToolButton(
                  icon: Icons.cleaning_services, // ou Icons.delete
                  label: "Gommer",
                  isSelected: _selectedTool == EditorTool.eraser,
                  onTap: () => setState(() => _selectedTool = EditorTool.eraser),
                ),
              ],
            ),
          ),

          // 2. LE CANVAS (Droite - Expanded)
          Expanded(
            child: Container(
              color: const Color(0xFF121212), // Fond de la zone de travail
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return InteractiveViewer(
                    transformationController: _transformationController,
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                    minScale: 0.1, maxScale: 5.0, constrained: false,
                    child: GestureDetector(
                      onTapUp: _onCanvasTap, // C'est ici que ça se passe !
                      child: MapCanvasWidget(
                        mapConfig: mapConfig,
                        floorTexture: _floorTexture,
                        parchmentTexture: _parchmentTexture,
                        paintedCells: _paintedCells,
                        hexRadius: _hexRadius,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Petit Widget helper pour les boutons de la palette
class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToolButton({Key? key, required this.icon, required this.label, required this.isSelected, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: Colors.white, width: 1) : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.white54),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// Le Widget Canvas (Identique à avant)
class MapCanvasWidget extends StatelessWidget {
  final MapConfig mapConfig;
  final ui.Image? floorTexture;
  final ui.Image? parchmentTexture;
  final Set<String> paintedCells;
  final double hexRadius;

  const MapCanvasWidget({Key? key, required this.mapConfig, this.floorTexture, this.parchmentTexture, required this.paintedCells, required this.hexRadius}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Calcul de la taille (Nécessaire pour le scroll)
    final w = (mapConfig.widthInCells + 0.5) * HexUtils.width(hexRadius);
    final h = (mapConfig.heightInCells * 0.75 * HexUtils.height(hexRadius)) + HexUtils.height(hexRadius);

    return Container(
      width: w, height: h,
      decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20)]),
      child: Stack(
        children: [
          // Layer 0 : Fond
          Positioned.fill(child: CustomPaint(painter: BackgroundPatternPainter(backgroundColor: mapConfig.backgroundColor, patternImage: parchmentTexture))),
          
          // Layer 1 : Tuiles (Avec le correctif de tri Z-Index)
          RepaintBoundary(
            child: CustomPaint(
              size: Size(w, h),
              painter: TileLayerPainter(config: mapConfig, tileImage: floorTexture, paintedCells: paintedCells, radius: hexRadius),
            ),
          ),
          
          // Layer 2 : Grille
          IgnorePointer(child: CustomPaint(size: Size(w, h), painter: GridPainter(config: mapConfig, radius: hexRadius))),
        ],
      ),
    );
  }
}
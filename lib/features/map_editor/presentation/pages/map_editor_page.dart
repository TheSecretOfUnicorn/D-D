import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../../domain/models/map_config_model.dart';
import '/core/utils/hex_utils.dart'; 
import '../painters/grid_painter.dart';
import '../painters/tile_layer_painter.dart';
import '../painters/background_pattern_painter.dart';
import '../../../../core/utils/image_loader.dart';

// 1. DÉFINITION DES OUTILS
enum EditorTool { move, brush, eraser }

class MapEditorPage extends StatefulWidget {
  const MapEditorPage({super.key});

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

  // --- ÉTAT ---
  Set<String> _paintedCells = {};      
  EditorTool _selectedTool = EditorTool.brush; // Outil par défaut

  // Maths
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

  // --- LOGIQUE DE PEINTURE (TAP & GLISSEMENT) ---
  void _handlePaintAction(Offset localPosition) {
    // Si on est en mode "Main", on ne peint pas !
    if (_selectedTool == EditorTool.move) return;

    final point = HexUtils.pixelToGrid(
      localPosition, 
      _hexRadius, 
      mapConfig.widthInCells, 
      mapConfig.heightInCells
    );

    if (point.x >= 0 && point.y >= 0) {
      final String key = "${point.x},${point.y}";
      final newSet = Set<String>.from(_paintedCells);
      
      bool changed = false;
      if (_selectedTool == EditorTool.brush) {
        if (!newSet.contains(key)) {
          newSet.add(key);
          changed = true;
        }
      } else if (_selectedTool == EditorTool.eraser) {
        if (newSet.contains(key)) {
          newSet.remove(key);
          changed = true;
        }
      }

      if (changed) {
        setState(() {
          _paintedCells = newSet;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = (mapConfig.widthInCells + 0.5) * HexUtils.width(_hexRadius);
    final h = (mapConfig.heightInCells * 0.75 * HexUtils.height(_hexRadius)) + HexUtils.height(_hexRadius);

    // 2. BOOLEEN CRITIQUE : EST-CE QU'ON PEUT BOUGER LA CARTE ?
    // Seulement si l'outil "Main" est sélectionné.
    final bool canPanMap = _selectedTool == EditorTool.move;

    return Scaffold(
      appBar: AppBar(title: const Text("Éditeur Hexagonal"), backgroundColor: const Color(0xFF1a1a1a)),
      backgroundColor: const Color(0xFF121212),
      
      body: Row(
        children: [
          // --- PALETTE D'OUTILS ---
          Container(
            width: 80,
            color: const Color(0xFF252525),
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Text("OUTILS", style: TextStyle(color: Colors.white54, fontSize: 10)),
                const SizedBox(height: 10),
                
                // Outil : MAIN (Déplacer)
                _ToolButton(
                  icon: Icons.pan_tool,
                  label: "Bouger",
                  isSelected: _selectedTool == EditorTool.move,
                  onTap: () => setState(() => _selectedTool = EditorTool.move),
                ),

                const SizedBox(height: 10),

                // Outil : PINCEAU
                _ToolButton(
                  icon: Icons.brush,
                  label: "Peindre",
                  isSelected: _selectedTool == EditorTool.brush,
                  onTap: () => setState(() => _selectedTool = EditorTool.brush),
                ),
                
                const SizedBox(height: 10),
                
                // Outil : GOMME
                _ToolButton(
                  icon: Icons.cleaning_services,
                  label: "Gommer",
                  isSelected: _selectedTool == EditorTool.eraser,
                  onTap: () => setState(() => _selectedTool = EditorTool.eraser),
                ),
              ],
            ),
          ),

          // --- ZONE DE CARTE ---
          Expanded(
            child: Container(
              color: const Color(0xFF121212),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return InteractiveViewer(
                    transformationController: _transformationController,
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                    minScale: 0.1, maxScale: 5.0, constrained: false,
                    
                    // 3. LA CLÉ DU SUCCÈS EST ICI 👇
                    // Si on peint, on désactive le Pan (déplacement) de l'InteractiveViewer
                    panEnabled: canPanMap, 
                    scaleEnabled: canPanMap, // On désactive aussi le zoom pour éviter les conflits

                    child: GestureDetector(
                      // On écoute le TAP (clic simple)
                      onTapUp: (details) => _handlePaintAction(details.localPosition),
                      
                      // On écoute aussi le GLISSEMENT (Peindre en continu !)
                      // Cela ne marche que si panEnabled est FALSE (donc en mode Pinceau)
                      onPanUpdate: (details) => _handlePaintAction(details.localPosition),

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

// Widget Bouton Outil
class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToolButton({required this.icon, required this.label, required this.isSelected, required this.onTap});

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

class MapCanvasWidget extends StatelessWidget {
  final MapConfig mapConfig;
  final ui.Image? floorTexture;
  final ui.Image? parchmentTexture;
  final Set<String> paintedCells;
  final double hexRadius;

  const MapCanvasWidget({super.key, required this.mapConfig, this.floorTexture, this.parchmentTexture, required this.paintedCells, required this.hexRadius});

  @override
  Widget build(BuildContext context) {
    final w = (mapConfig.widthInCells + 0.5) * HexUtils.width(hexRadius);
    final h = (mapConfig.heightInCells * 0.75 * HexUtils.height(hexRadius)) + HexUtils.height(hexRadius);

    return Container(
      width: w, height: h,
      decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20)]),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: BackgroundPatternPainter(backgroundColor: mapConfig.backgroundColor, patternImage: parchmentTexture))),
          RepaintBoundary(
            child: CustomPaint(
              size: Size(w, h),
              painter: TileLayerPainter(config: mapConfig, tileImage: floorTexture, paintedCells: paintedCells, radius: hexRadius),
            ),
          ),
          IgnorePointer(child: CustomPaint(size: Size(w, h), painter: GridPainter(config: mapConfig, radius: hexRadius))),
        ],
      ),
    );
  }
}
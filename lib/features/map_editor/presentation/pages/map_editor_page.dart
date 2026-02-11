import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../../domain/models/map_config_model.dart';
import '/core/utils/hex_utils.dart'; 
import '../painters/grid_painter.dart';
import '../painters/tile_layer_painter.dart';
import '../painters/background_pattern_painter.dart';
import '../../../../core/utils/image_loader.dart';

// Enum des outils
enum EditorTool { move, brush, eraser }

class MapEditorPage extends StatefulWidget {
  const MapEditorPage({super.key});

  @override
  State<MapEditorPage> createState() => _MapEditorPageState();
}

class _MapEditorPageState extends State<MapEditorPage> {
  final mapConfig = const MapConfig(
    widthInCells: 20,
    heightInCells: 16, // ✅ AJOUT : On passe de 15 à 16 lignes
    cellSize: 64.0, 
    backgroundColor: Color(0xFFE0D8C0), 
    gridColor: Color(0x4D5C4033),       
  );

  // Marge de sécurité pour le clic sur les bords
  static const double _mapMargin = 50.0;

  final TransformationController _transformationController = TransformationController();
  
  ui.Image? _parchmentTexture;
  ui.Image? _floorTexture;
  
  Set<String> _paintedCells = {};      
  EditorTool _selectedTool = EditorTool.brush;
  
  // ✅ NOUVEAU : État pour le mode Portrait/Paysage
  bool _isPortrait = false; 

  double get _hexRadius => mapConfig.cellSize / HexUtils.sqrt3;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    try {
      final parchment = await ImageLoader.loadAsset('assets/images/ui/parchment_bg.png');
      if (mounted) setState(() => _parchmentTexture = parchment);
    } catch (e) { debugPrint("⚠️ Pas de parchemin : $e"); }

    try {
      final floor = await ImageLoader.loadAsset('assets/images/tiles/stone_floor.png');
      if (mounted) setState(() => _floorTexture = floor);
    } catch (e) { debugPrint("❌ Pas de sol : $e"); }
  }

  // --- MOTEUR DE PEINTURE ---
  void _onPointerEvent(PointerEvent details) {
    if (_selectedTool == EditorTool.move) return;

    final localPositionCorrected = details.localPosition - const Offset(_mapMargin, _mapMargin);

    final point = HexUtils.pixelToGrid(
      localPositionCorrected, 
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

      if (changed) setState(() => _paintedCells = newSet);
    }
  }

  // --- CONSTRUCTION DE LA PALETTE (Responsive) ---
  Widget _buildPalette(Axis direction) {
    return Container(
      // Si vertical (Paysage) : Largeur fixe 80. Si horizontal (Portrait) : Hauteur fixe 80.
      width: direction == Axis.vertical ? 80 : double.infinity,
      height: direction == Axis.horizontal ? 80 : double.infinity,
      color: const Color(0xFF252525),
      child: Flex(
        direction: direction,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (direction == Axis.vertical) const SizedBox(height: 20),
          
          _ToolButton(
            icon: Icons.pan_tool, 
            label: "Bouger", 
            isSelected: _selectedTool == EditorTool.move, 
            onTap: () => setState(() => _selectedTool = EditorTool.move)
          ),
          
          _ToolButton(
            icon: Icons.brush, 
            label: "Peindre", 
            isSelected: _selectedTool == EditorTool.brush, 
            onTap: () => setState(() => _selectedTool = EditorTool.brush)
          ),
          
          _ToolButton(
            icon: Icons.cleaning_services, 
            label: "Gommer", 
            isSelected: _selectedTool == EditorTool.eraser, 
            onTap: () => setState(() => _selectedTool = EditorTool.eraser)
          ),

          if (direction == Axis.vertical) const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = ((mapConfig.widthInCells + 0.5) * HexUtils.width(_hexRadius)) + (_mapMargin * 2);
    final h = ((mapConfig.heightInCells * 0.75 * HexUtils.height(_hexRadius)) + HexUtils.height(_hexRadius)) + (_mapMargin * 2);

    final bool canInteractWithMap = _selectedTool == EditorTool.move;

    // Le contenu principal (Canvas) extrait pour être réutilisé
    final canvasArea = Container(
      color: const Color(0xFF121212),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return InteractiveViewer(
            transformationController: _transformationController,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            minScale: 0.1, maxScale: 5.0, constrained: false,
            panEnabled: canInteractWithMap, 
            scaleEnabled: canInteractWithMap, 
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _onPointerEvent,
              onPointerMove: _onPointerEvent,
              
              child: MapCanvasWidget(
                mapConfig: mapConfig,
                floorTexture: _floorTexture,
                parchmentTexture: _parchmentTexture,
                paintedCells: _paintedCells,
                hexRadius: _hexRadius,
                mapMargin: _mapMargin,
                totalWidth: w,
                totalHeight: h,
              ),
            ),
          );
        },
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Éditeur Hexagonal"), 
        backgroundColor: const Color(0xFF1a1a1a),
        actions: [
          // ✅ BOUTON BASCULE PORTRAIT / PAYSAGE
          IconButton(
            icon: Icon(_isPortrait ? Icons.stay_current_landscape : Icons.stay_current_portrait),
            tooltip: "Changer l'orientation",
            onPressed: () {
              setState(() {
                _isPortrait = !_isPortrait;
              });
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFF121212),
      
      // ✅ LAYOUT DYNAMIQUE
      body: _isPortrait
        ? Column( // MODE PORTRAIT (Mobile)
            children: [
              Expanded(child: canvasArea), // Canvas en haut
              _buildPalette(Axis.horizontal), // Palette en bas
            ],
          )
        : Row( // MODE PAYSAGE (Desktop)
            children: [
              _buildPalette(Axis.vertical), // Palette à gauche
              Expanded(child: canvasArea), // Canvas à droite
            ],
          ),
    );
  }
}

// Boutons
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
        margin: const EdgeInsets.all(10), 
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent : Colors.transparent, 
          borderRadius: BorderRadius.circular(8), 
          border: isSelected ? Border.all(color: Colors.white, width: 1) : null
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Important pour le Flex
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.white54), 
            const SizedBox(height: 4), 
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontSize: 10))
          ]
        ),
      ),
    );
  }
}

// Widget Canvas
class MapCanvasWidget extends StatelessWidget {
  final MapConfig mapConfig;
  final ui.Image? floorTexture;
  final ui.Image? parchmentTexture;
  final Set<String> paintedCells;
  final double hexRadius;
  final double mapMargin;
  final double totalWidth;
  final double totalHeight;

  const MapCanvasWidget({
    super.key, 
    required this.mapConfig, 
    this.floorTexture, 
    this.parchmentTexture, 
    required this.paintedCells, 
    required this.hexRadius,
    required this.mapMargin,
    required this.totalWidth,
    required this.totalHeight,
  });

  @override
  Widget build(BuildContext context) {
    final offset = Offset(mapMargin, mapMargin);

    return Container(
      width: totalWidth, height: totalHeight,
      decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20)]),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: BackgroundPatternPainter(backgroundColor: mapConfig.backgroundColor, patternImage: parchmentTexture))),
          
          RepaintBoundary(
            child: CustomPaint(
              size: Size(totalWidth, totalHeight),
              painter: TileLayerPainter(
                config: mapConfig, 
                tileImage: floorTexture, 
                paintedCells: paintedCells, 
                radius: hexRadius,
                offset: offset
              ),
            ),
          ),
          
          IgnorePointer(child: CustomPaint(
            size: Size(totalWidth, totalHeight), 
            painter: GridPainter(
              config: mapConfig, 
              radius: hexRadius,
              offset: offset
            )
          )),
        ],
      ),
    );
  }
}
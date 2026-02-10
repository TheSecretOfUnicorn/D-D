import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// --- IMPORTS ---
import '../../domain/models/map_config_model.dart';
import '../../../../core/utils/hex_utils.dart'; // Indispensable pour les maths
import '../painters/grid_painter.dart';
import '../painters/tile_layer_painter.dart';
import '../painters/background_pattern_painter.dart';
import '../../../../core/utils/image_loader.dart';

class MapEditorPage extends StatefulWidget {
  const MapEditorPage({super.key});

  @override
  State<MapEditorPage> createState() => _MapEditorPageState();
}

class _MapEditorPageState extends State<MapEditorPage> {
  // Config Hexagonale
  final mapConfig = const MapConfig(
    widthInCells: 20,
    heightInCells: 15,
    cellSize: 64.0, // Largeur "Flat-to-Flat" de l'hexagone
    backgroundColor: Color(0xFFE0D8C0), // Beige Parchemin
    gridColor: Color(0x4D5C4033),       // Encre brune
  );

  final TransformationController _transformationController = TransformationController();
  
  // Assets
  ui.Image? _parchmentTexture;
  ui.Image? _floorTexture;
  bool _isLoading = true;

  // Stockage des cases peintes : "col,row"
  final Set<String> _paintedCells = {};

  // 📐 CALCUL MATHÉMATIQUE PRÉCIS DU RAYON
  // Si cellSize (64) est la largeur (bords plats), le rayon est largeur / sqrt(3).
  // Cela garantit un pavage parfait sans trous.
  double get _hexRadius => mapConfig.cellSize / HexUtils.sqrt3;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadAssets() async {
    try {
      final parchment = await ImageLoader.loadAsset('assets/images/ui/parchment_bg.png');
      final floor = await ImageLoader.loadAsset('assets/images/tiles/stone_floor.png');
      
      if (mounted) {
        setState(() {
          _parchmentTexture = parchment;
          _floorTexture = floor;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("⚠️ Erreur chargement assets (le fond beige sera utilisé) : $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// GESTION DU CLIC HEXAGONAL
  void _onCanvasTap(TapUpDetails details) {
    // On utilise le rayon précis calculé
    final point = HexUtils.pixelToGrid(
      details.localPosition, 
      _hexRadius, 
      mapConfig.widthInCells, 
      mapConfig.heightInCells
    );

    // Si clic valide
    if (point.x >= 0 && point.y >= 0) {
      final String key = "${point.x},${point.y}";
      setState(() {
        if (_paintedCells.contains(key)) {
          _paintedCells.remove(key);
        } else {
          _paintedCells.add(key);
        }
      });
      debugPrint("🛑 Hexagone touché : $key");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Éditeur (Mode Hexagonal Civ VI)"),
        backgroundColor: const Color(0xFF1a1a1a),
      ),
      backgroundColor: const Color(0xFF121212), // Fond hors de la carte
      body: Row(
        children: [
          // --- PALETTE (Placeholder) ---
          Container(
            width: 80,
            color: const Color(0xFF252525),
            child: const Center(child: Icon(Icons.brush, color: Colors.white54)),
          ),

          // --- CANVAS ---
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return InteractiveViewer(
                  transformationController: _transformationController,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  minScale: 0.1,
                  maxScale: 5.0,
                  constrained: false, // Permet à la carte d'être plus grande que l'écran
                  child: GestureDetector(
                    onTapUp: _onCanvasTap, // Détection du clic
                    child: MapCanvasWidget(
                      mapConfig: mapConfig,
                      floorTexture: _floorTexture,
                      parchmentTexture: _parchmentTexture,
                      paintedCells: _paintedCells,
                      hexRadius: _hexRadius, // ✅ On passe le rayon précis
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// WIDGET D'AFFICHAGE DE LA CARTE
class MapCanvasWidget extends StatelessWidget {
  final MapConfig mapConfig;
  final ui.Image? floorTexture;
  final ui.Image? parchmentTexture;
  final Set<String> paintedCells;
  final double hexRadius; // ✅ Requis pour les calculs internes

  const MapCanvasWidget({
    super.key,
    required this.mapConfig,
    this.floorTexture,
    this.parchmentTexture,
    required this.paintedCells,
    required this.hexRadius, 
  });

  @override
  Widget build(BuildContext context) {
    // 📐 CALCUL DE LA TAILLE TOTALE DU CANVAS
    // Largeur : (Nbre colonnes + 0.5) * Largeur Hex
    final w = (mapConfig.widthInCells + 0.5) * HexUtils.width(hexRadius);
    
    // Hauteur : (Nbre lignes * 0.75) * Hauteur Hex + un petit rab (0.25) pour la fin
    final h = (mapConfig.heightInCells * 0.75 * HexUtils.height(hexRadius)) + (HexUtils.height(hexRadius) * 0.25);

    return Container(
      width: w,
      height: h,
      // Ombre portée pour l'effet "Posé sur la table"
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 5)
        ],
      ),
      child: Stack(
        children: [
          // LAYER 0 : FOND PARCHEMIN (Pattern répété)
          Positioned.fill(
            child: CustomPaint(
              painter: BackgroundPatternPainter(
                backgroundColor: mapConfig.backgroundColor,
                patternImage: parchmentTexture,
              ),
            ),
          ),

          // LAYER 1 : TUILES (Hexagones peints)
          RepaintBoundary(
            child: CustomPaint(
              size: Size(w, h),
              painter: TileLayerPainter(
                config: mapConfig,
                tileImage: floorTexture,
                paintedCells: paintedCells,
                radius: hexRadius, // ✅ Passe le rayon exact
              ),
            ),
          ),

          // LAYER 2 : GRILLE (Nid d'abeille)
          IgnorePointer(
            child: CustomPaint(
              size: Size(w, h),
              painter: GridPainter(
                config: mapConfig,
                radius: hexRadius, // ✅ Passe le rayon exact
              ),
            ),
          ),
        ],
      ),
    );
  }
}
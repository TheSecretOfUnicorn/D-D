// Fichier : lib/features/map_editor/presentation/pages/map_editor_page.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../domain/models/map_config_model.dart';
import '../../../../core/utils/hex_utils.dart'; 
import '../painters/grid_painter.dart';
import '../painters/tile_layer_painter.dart';
import '../painters/background_pattern_painter.dart';
import '../../../../core/utils/image_loader.dart';



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

  // CORRECTION 1 : On utilise un Set qu'on remplacera à chaque fois
  Set<String> _paintedCells = {};

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

  void _onCanvasTap(TapUpDetails details) {
    final point = HexUtils.pixelToGrid(
      details.localPosition, 
      _hexRadius, 
      mapConfig.widthInCells, 
      mapConfig.heightInCells
    );

    if (point.x >= 0 && point.y >= 0) {
      final String key = "${point.x},${point.y}";
      
      // CORRECTION 2 : On crée une NOUVELLE copie du Set pour forcer le repaint
      final newSet = Set<String>.from(_paintedCells);
      if (newSet.contains(key)) {
        newSet.remove(key);
      } else {
        newSet.add(key);
      }

      setState(() {
        _paintedCells = newSet; // On remplace la référence, le Painter va se réveiller !
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Éditeur Hexagonal"), backgroundColor: const Color(0xFF1a1a1a)),
      backgroundColor: const Color(0xFF121212),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return InteractiveViewer(
            transformationController: _transformationController,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            minScale: 0.1, maxScale: 5.0, constrained: false,
            child: GestureDetector(
              onTapUp: _onCanvasTap,
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
    );
  }
}

class MapCanvasWidget extends StatelessWidget {
  final MapConfig mapConfig;
  final ui.Image? floorTexture;
  final ui.Image? parchmentTexture;
  final Set<String> paintedCells;
  final double hexRadius;

  const MapCanvasWidget({Key? key, required this.mapConfig, this.floorTexture, this.parchmentTexture, required this.paintedCells, required this.hexRadius}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final w = (mapConfig.widthInCells + 0.5) * HexUtils.width(hexRadius);
    final h = (mapConfig.heightInCells * 0.75 * HexUtils.height(hexRadius)) + HexUtils.height(hexRadius);

    return Container(
      width: w, height: h,
      decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20)]),
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
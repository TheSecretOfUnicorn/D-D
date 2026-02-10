// ignore_for_file: unused_field

import 'package:flutter/material.dart';
import '../painters/grid_painter.dart';
import '../../domain/models/map_config_model.dart';
import 'dart:ui' as ui; // Nécessaire pour le type ui.Image
import '../../../../core/utils/image_loader.dart';
import '../painters/tile_layer_painter.dart';

class MapEditorPage extends StatefulWidget {
  const MapEditorPage({super.key});

  @override
  State<MapEditorPage> createState() => _MapEditorPageState();
}

class _MapEditorPageState extends State<MapEditorPage> {
  // Config de démo : une carte de 20x15 cases de 64px
  final mapConfig = const MapConfig(
    widthInCells: 20,
    heightInCells: 15,
    cellSize: 64.0,
    backgroundColor: Color(0xFF202020), // Un gris très sombre pour le sol par défaut
    gridColor: Color(0x26FFFFFF),       // Blanc très subtil (~15%)
  );

  // TransformationController permet de manipuler le zoom/pan par code si besoin
  final TransformationController _transformationController =
        TransformationController();

      ui.Image? _floorTexture;
      bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    // --- DEBUT CODE DEBUG ---
    try {
      // On demande à Flutter la liste de TOUS les assets qu'il connait
      final manifestContent = await DefaultAssetBundle.of(context).loadString('AssetManifest.json');
      debugPrint("🔍 RECHERCHE DE 'stone' DANS LES ASSETS...");
      debugPrint(manifestContent.split(',').where((line) => line.contains('stone')).join('\n'));
    } catch(e) {
      debugPrint("⚠️ Impossible de lire le manifeste : $e");
    }

    try {
      // Charge la texture depuis les assets
      final image = await ImageLoader.loadAsset('assets/images/tiles/stone_floor.png');
      setState(() {
        _floorTexture = image;
        _isLoading = false;
        
      });
    } catch (e) {
      debugPrint("Erreur chargement asset: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Éditeur de Carte (Architecture Engine)"),
        backgroundColor: const Color(0xFF1a1a1a),
      ),
      body: Row(
        children: [
          // --- ZONE 1 : PALETTE D'OUTILS (Placeholder) ---
          Container(
            width: 100,
            color: const Color(0xFF303030),
            child: const Center(
              child: RotatedBox(
                quarterTurns: 3,
                child: Text("OUTILS & PALETTE", style: TextStyle(color: Colors.white54)),
              ),
            ),
          ),

            // --- ZONE 2 : CANVAS PRINCIPAL ---
        Expanded(
          child: Container(
            color: const Color(0xFF121212),
            child: Stack(  // <--- On transforme le LayoutBuilder en Stack ou Column pour tester
              children: [
                 // AJOUTE CECI TEMPORAIREMENT :
                 Positioned(
                   top: 20, 
                   left: 20, 
                   child: Image.asset(
                     'assets/images/tiles/stone_floor.png', 
                     width: 100, 
                     height: 100,
                     errorBuilder: (c, o, s) => Container(
                       width: 100, height: 100, color: Colors.red, 
                       child: const Center(child: Text("ERREUR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
                     ),
                   )
                 ),
              
                LayoutBuilder(
                  builder: (context, constraints) {
                    return InteractiveViewer(
                      transformationController: _transformationController,
                      // boundaryMargin: Marge autour de la carte pour scroller "au delà"
                      boundaryMargin: const EdgeInsets.all(double.infinity),
                      minScale: 0.1, // Zoom out max
                      maxScale: 5.0, // Zoom in max
                      // constrained: false est CRUCIAL.
                      // Cela dit : "Mon enfant peut être plus grand que moi".
                      constrained: false,
                      child: MapCanvasWidget(mapConfig: mapConfig),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
          ],
        )
      );
  }
}

/// WIDGET CŒUR DU MOTEUR : Le Canvas qui empile les calques
class MapCanvasWidget extends StatelessWidget {
  final MapConfig mapConfig;


  const MapCanvasWidget({super.key, required this.mapConfig});
  
  ui.Image? get _floorTexture => null;

  @override
  Widget build(BuildContext context) {
    // Ce Container définit la taille physique RÉELLE de la carte en pixels.
    return Container(
      width: mapConfig.totalWidth,
      height: mapConfig.totalHeight,
      // Debug border pour voir les limites de la carte
      decoration: BoxDecoration(
        border: Border.all(color: Colors.redAccent.withOpacity(0.5), width: 2),
      ),
      child: Stack(
        children: [
          // =========== LAYER 0 : BACKGROUND ===========
          Positioned.fill(
            child: Container(color: mapConfig.backgroundColor),
          ),

          // =========== LAYER 1 : TUILES (SOL) ===========
          RepaintBoundary(
            child: CustomPaint(
              size: Size(mapConfig.totalWidth, mapConfig.totalHeight),
              // ON PASSE L'IMAGE AU PAINTER
              painter: TileLayerPainter(
                config: mapConfig, 
                tileImage: _floorTexture // Peut être null au début, le painter gère ça
              ),
            ),
          ),

          // =========== LAYER 2 : GRILLE TECHNIQUE ===========
          IgnorePointer(
            child: CustomPaint(
              size: Size(mapConfig.totalWidth, mapConfig.totalHeight),
              // ON UTILISE MAINTENANT LE VRAI PAINTER :
              painter: GridPainter(config: mapConfig),
            ),
          ),

          // =========== LAYER 3 : OBJETS & TOKENS (INTERACTIFS) ===========
          // Ici on utilisera des widgets classiques pour pouvoir les drag & drop
          const PlaceholderObjectLayerStub(),
        ],
      ),
    );
  }
}

// ================= PAINTERS STUBS (A REMPLIR PLUS TARD) =================

class TileLayerPainterStub extends CustomPainter {
  final MapConfig config;
  TileLayerPainterStub({required this.config});

  @override
  void paint(Canvas canvas, Size size) {
    // TODO: C'est ici que la magie opérera pour dessiner des milliers de tuiles à 60fps
    // Pour l'instant, on dessine juste un grand rectangle vert pour dire "le sol est là"
    final paint = Paint()..color = Colors.green.withOpacity(0.2);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant TileLayerPainterStub oldDelegate) {
    // Retourner true si les données du calque changent (ex: ajout d'une tuile)
    return config != oldDelegate.config;
  }
}

class GridPainterStub extends CustomPainter {
  final MapConfig config;
  GridPainterStub({required this.config});

  @override
  void paint(Canvas canvas, Size size) {
    // TODO: Implémenter le dessin de la grille
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Dessin d'une croix juste pour le debug
    canvas.drawLine(const Offset(0,0), Offset(size.width, size.height), paint);
     canvas.drawLine(Offset(size.width,0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant GridPainterStub oldDelegate) {
    return false;
  }
}

class PlaceholderObjectLayerStub extends StatelessWidget {
  const PlaceholderObjectLayerStub({super.key});

  @override
  Widget build(BuildContext context) {
    // Exemple d'objet positionné (une table ronde rouge)
    return Stack(
      children: [
        Positioned(
            left: 150,
            top: 200,
            child: Container(
              width: 50, height: 50,
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              child: const Center(child: Text("Token", style: TextStyle(fontSize: 10))),
            )
        )
      ],
    );
  }
}
import 'package:flutter/material.dart';

// ================= DEFINITIONS TEMPORAIRES =================
// Ces modèles seront plus tard déplacés dans le dossier 'domain'
// et probablement générés avec freezed/json_serializable.
class MapConfig {
  final int widthInCells;
  final int heightInCells;
  final double cellSize;
  final Color backgroundColor;

  const MapConfig({
    required this.widthInCells,
    required this.heightInCells,
    required this.cellSize,
    required this.backgroundColor,
  });

  // Taille totale en pixels
  double get totalWidth => widthInCells * cellSize;
  double get totalHeight => heightInCells * cellSize;
}
// ============================================================


class MapEditorPage extends StatefulWidget {
  const MapEditorPage({Key? key}) : super(key: key);

  @override
  State<MapEditorPage> createState() => _MapEditorPageState();
}

class _MapEditorPageState extends State<MapEditorPage> {
  // Config de démo : une carte de 20x15 cases de 64px
  final mapConfig = const MapConfig(
    widthInCells: 20,
    heightInCells: 15,
    cellSize: 64.0,
    backgroundColor: Color(0xFF212121), // Gris foncé
  );

  // TransformationController permet de manipuler le zoom/pan par code si besoin
  final TransformationController _transformationController =
      TransformationController();

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
              color: const Color(0xFF121212), // Fond hors de la carte
              // LayoutBuilder pour connaître la taille de la zone disponible
              child: LayoutBuilder(
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
            ),
          ),
        ],
      ),
    );
  }
}

/// WIDGET CŒUR DU MOTEUR : Le Canvas qui empile les calques
class MapCanvasWidget extends StatelessWidget {
  final MapConfig mapConfig;

  const MapCanvasWidget({Key? key, required this.mapConfig}) : super(key: key);

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
          // RepaintBoundary est vital pour la performance :
          // Il met en cache le dessin de ce calque tant qu'il ne change pas.
          RepaintBoundary(
            child: CustomPaint(
              size: Size(mapConfig.totalWidth, mapConfig.totalHeight),
              painter: TileLayerPainterStub(config: mapConfig),
            ),
          ),

          // =========== LAYER 2 : GRILLE TECHNIQUE ===========
          // IgnorePointer car la grille est visuelle, on doit pouvoir cliquer "à travers"
          IgnorePointer(
            child: CustomPaint(
              size: Size(mapConfig.totalWidth, mapConfig.totalHeight),
              painter: GridPainterStub(config: mapConfig),
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
  const PlaceholderObjectLayerStub({Key? key}) : super(key: key);

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
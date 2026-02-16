import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:collection';

// --- IMPORTS MODÈLES ---
import '../../data/models/map_config_model.dart';
import '../../data/models/tile_type.dart';
import '../../data/models/world_object_model.dart';

// --- IMPORTS UTILS ---
import '/core/utils/hex_utils.dart'; 
import '../../../../core/utils/image_loader.dart';

// --- IMPORTS SERVICES ---
import '../../core/services/fog_of_war_service.dart';
import '../../core/services/pathfinding_service.dart';
import '../../../campaign_manager/data/repositories/campaign_repository.dart';

// --- IMPORTS PAINTERS ---
import '../painters/grid_painter.dart';
import '../painters/tile_layer_painter.dart';
import '../painters/background_pattern_painter.dart';
import '../painters/token_painter.dart';
import '../painters/fog_painter.dart';
import '../painters/movement_painter.dart';
import '../painters/object_painter.dart'; 
import '../painters/lighting_painter.dart';

// --- IMPORT WIDGETS ---
import '../widgets/editor_palette.dart'; 

enum EditorTool { move, brush, eraser, token, object, interact, rotate, fill }



class MapRepository {
  Future<bool> saveMapData(dynamic data) async {
    await Future.delayed(const Duration(seconds: 1)); 
    return true; 
  }
}
class MapDataModel {
  final String? id; final String name; final MapConfig config; 
  final Map<String, TileType> gridData; // On sauvegarde la Map complète
  MapDataModel({this.id, required this.name, required this.config, required this.gridData, required Object objects, required Map<String, int> tileRotations});
}


class MapEditorPage extends StatefulWidget {
  final int campaignId;
  final String mapId;

  const MapEditorPage({
    super.key, 
    this.campaignId = 0, 
    this.mapId = "new_map"
  });

  @override
  State<MapEditorPage> createState() => _MapEditorPageState();
}

class _MapEditorPageState extends State<MapEditorPage> with SingleTickerProviderStateMixin {
  final CampaignRepository _campRepo = CampaignRepository();
  final MapRepository _mapRepo = MapRepository();
  late final AnimationController _animController;

  MapConfig _mapConfig = const MapConfig(
    widthInCells: 20,
    heightInCells: 16,
    cellSize: 64.0, 
    backgroundColor: Color(0xFFE0D8C0), 
    gridColor: Color(0x4D5C4033),       
  );

  static const double _mapMargin = 100.0;
  final TransformationController _transformationController = TransformationController();
  
  final Map<String, ui.Image> _assets = {};
  
  // Données
  final Map<String, TileType> _gridData = {};        
  final Map<String, Point<int>> _tokenPositions = {}; 
  final Map<String, WorldObject> _objects = {}; 
  
  // États
  Set<String> _visibleCells = {};
  final Set<String> _exploredCells = {};
  Set<String> _reachableCells = {}; 
  final Map<String, int> _tileRotations = {};
  bool _fogEnabled = true;

  // --- NOUVEAUX PARAMÈTRES DE JEU ---
  int _visionRange = 8;   // Distance de vue par défaut
  int _movementRange = 6; // Distance de déplacement par défaut

  // UI
  List<Map<String, dynamic>> _members = []; 
  String? _selectedCharId; 
  
  EditorTool _selectedTool = EditorTool.brush;
  TileType _selectedTileType = TileType.stoneFloor;
  ObjectType _selectedObjectType = ObjectType.door; 
  
  final bool _isPortrait = false; 
  double get _hexRadius => _mapConfig.cellSize / HexUtils.sqrt3;

  @override
  void initState() {
    _animController = AnimationController(
      vsync: this, 
      duration: const Duration(seconds: 2)
    )..repeat(reverse: true);
    super.initState();
    _loadAllAssets();
    _loadMembers();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculateFog());
  }

  @override
  void dispose() {
    _animController.dispose(); // Important pour éviter les fuites de mémoire
    super.dispose();
  }

  Future<void> _loadAllAssets() async {
    final files = {
      'parchment': 'assets/images/ui/parchment_bg.png',
      'stone_floor': 'assets/images/tiles/stone_floor.png',
      'wood_floor': 'assets/images/tiles/wood_floor.png',
      'grass': 'assets/images/tiles/grass_1.png',
      'dirt': 'assets/images/tiles/_dirt_footprint_floor.png',
      'stone_wall': 'assets/images/tiles/stone_wall.png',
      'tree': 'assets/images/tiles/tree_1.png',
      'water': 'assets/images/tiles/water_1.png',
      'lava': 'assets/images/tiles/lava_1.png',
      'door_closed': 'assets/images/objects/door_closed.png',
      'door_open': 'assets/images/objects/door_open.png',
      'chest_closed': 'assets/images/objects/chest_closed.png',
      'chest_open': 'assets/images/objects/chest_open.png',
      'torch': 'assets/images/objects/torch.png',
    };

    for (var entry in files.entries) {
      try {
        final img = await ImageLoader.loadAsset(entry.value);
        if (mounted) setState(() => _assets[entry.key] = img);
      } catch (e) {}
    }
  }

  Future<void> _loadMembers() async {
    List<Map<String, dynamic>> loadedMembers = [];
    if (widget.campaignId != 0) {
      try {
        final members = await _campRepo.getMembers(widget.campaignId);
        loadedMembers = members.where((m) => m['char_id'] != null).toList();
      } catch (e) { debugPrint("Erreur DB: $e"); }
    }
    if (loadedMembers.isEmpty) {
      loadedMembers = [
        {'char_id': '101', 'char_name': 'Guerrier'},
        {'char_id': '102', 'char_name': 'Mage'},
        {'char_id': '103', 'char_name': 'Voleur'},
      ];
    }
    if (mounted) setState(() => _members = loadedMembers);
  }

  // --- LOGIQUE METIER ---

  void _recalculateFog() {
    if (!_fogEnabled) {
      setState(() => _visibleCells = {});
      return;
    }

    // 1. Murs (inchangé)
    final walls = _gridData.entries
      .where((e) => e.value == TileType.stoneWall || e.value == TileType.tree)
      .map((e) => e.key).toSet();
    final closedDoors = _objects.values
      .where((obj) => obj.type == ObjectType.door && obj.state == false)
      .map((obj) => "${obj.position.x},${obj.position.y}");
    final allBlockers = walls.union(closedDoors.toSet());

    // 2. Sources de vision (Pions + Lumières)
    List<VisionSource> sources = [];

    // A. Les Pions (Vision définie par les paramètres globaux)
    for (var pos in _tokenPositions.values) {
      sources.add(VisionSource(pos, _visionRange));
    }

    // B. Les Objets Lumineux (Torches, Feux...)
    for (var obj in _objects.values) {
      if (obj.lightRadius > 0) {
        sources.add(VisionSource(obj.position, obj.lightRadius.toInt()));
      }
    }

    final visible = FogOfWarService.calculateVisibility(
      sources: sources, // <--- On passe la liste combinée
      walls: allBlockers, 
      maxCols: _mapConfig.widthInCells, 
      maxRows: _mapConfig.heightInCells
    );
    setState(() { _visibleCells = visible; _exploredCells.addAll(visible); });
  }

  void _calculateMovementRange() {
    if (_selectedCharId == null || !_tokenPositions.containsKey(_selectedCharId)) {
      setState(() => _reachableCells = {}); return;
    }
    final startPos = _tokenPositions[_selectedCharId]!;
    
    final staticObstacles = _gridData.entries
        .where((e) => e.value == TileType.stoneWall || e.value == TileType.tree || e.value == TileType.water || e.value == TileType.lava)
        .map((e) => e.key).toSet();

    final objectObstacles = _objects.values
        .where((obj) => (obj.type == ObjectType.door && !obj.state) || obj.type == ObjectType.chest)
        .map((obj) => "${obj.position.x},${obj.position.y}");

    final allObstacles = staticObstacles.union(objectObstacles.toSet());

    final reachable = PathfindingService.getReachableCells(
      start: startPos, 
      movement: _movementRange, // <--- UTILISATION DU PARAMÈTRE
      walls: allObstacles,
      maxCols: _mapConfig.widthInCells, maxRows: _mapConfig.heightInCells,
    );
    setState(() => _reachableCells = reachable);
  }

  void _onPointerEvent(PointerEvent details) {
    if (_selectedTool == EditorTool.move) return;
    final pos = details.localPosition - const Offset(_mapMargin, _mapMargin);
    final point = HexUtils.pixelToGrid(pos, _hexRadius, _mapConfig.widthInCells, _mapConfig.heightInCells);

    if (point.x >= 0 && point.y >= 0) {
      final key = "${point.x},${point.y}";
      bool changed = false;

      if (_selectedTool == EditorTool.brush) {
        if (_gridData[key] != _selectedTileType) {
          _gridData[key] = _selectedTileType; 
          if (_objects.containsKey(key)) _objects.remove(key);
          changed = true;
        }
      } 
      else if (_selectedTool == EditorTool.eraser) {
        if (_gridData.containsKey(key)) { _gridData.remove(key); changed = true; }
        if (_tokenPositions.containsValue(point)) { 
           final id = _tokenPositions.entries.firstWhere((e) => e.value == point).key;
           _tokenPositions.remove(id); changed = true; 
        }
        if (_objects.containsKey(key)) { _objects.remove(key); changed = true; }
      } 
      else if (_selectedTool == EditorTool.token && details is PointerDownEvent) {
        if (_selectedCharId != null) {
           // On permet de déplacer si c'est nouveau OU si c'est dans la zone accessible
           if (!_tokenPositions.containsKey(_selectedCharId) || _reachableCells.contains(key)) {
             _tokenPositions[_selectedCharId!] = point; changed = true;
           } else {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Trop loin ou bloqué !"), duration: Duration(milliseconds: 500)));
           }
        }
      }
      else if (_selectedTool == EditorTool.object && details is PointerDownEvent) {
        if (!_objects.containsKey(key) && _gridData[key] != TileType.stoneWall) {

          double lightRad = 0;
          int lightCol = 0xFFFFA726; // Orange
          
          if (_selectedObjectType == ObjectType.torch) {
            lightRad = 3.0; // Torche éclaire à 3 cases
          }
          _objects[key] = WorldObject(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            position: point,
            type: _selectedObjectType,
            state: false,
            lightRadius: lightRad, // <---
            lightColor: lightCol,
          );
          changed = true;
        }
      }
      else if (_selectedTool == EditorTool.interact && details is PointerDownEvent) {
        if (_objects.containsKey(key)) {
          final obj = _objects[key]!;
          _objects[key] = obj.copyWith(state: !obj.state, rotation: obj.rotation);
          changed = true;
        }
      }

      else if (_selectedTool == EditorTool.rotate && details is PointerDownEvent) {
        bool changedHere = false; // Renommé pour éviter conflit
        
        if (_objects.containsKey(key)) {
          final obj = _objects[key]!;
          // MODULO 8 pour 8 directions (0 à 7)
          final newRot = (obj.rotation + 1) % 8; 
          _objects[key] = obj.copyWith(rotation: newRot);
          changedHere = true;
        }
        else if (_gridData.containsKey(key)) {
          final currentRot = _tileRotations[key] ?? 0;
          // Gardons les MURS sur 6 directions car l'hexagone a 6 cotés
          final newRot = (currentRot + 1) % 6; 
          _tileRotations[key] = newRot;
          changedHere = true;
        }

        if (changedHere) {
          changed = true;
          setState(() {});
        }
      }

      else if (_selectedTool == EditorTool.fill && details is PointerDownEvent) {
         _floodFill(point, _selectedTileType);
         changed = true;
      }
      
      if (changed) { 
        setState(() {}); 
        _recalculateFog(); 
        _calculateMovementRange(); 
      }
    }
  }

  // --- BOÎTE DE DIALOGUE PARAMÈTRES AMÉLIORÉE ---
  void _openMapSettings() {
    final widthController = TextEditingController(text: _mapConfig.widthInCells.toString());
    final heightController = TextEditingController(text: _mapConfig.heightInCells.toString());
    final visionController = TextEditingController(text: _visionRange.toString());
    final movementController = TextEditingController(text: _movementRange.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Paramètres de la Carte"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Dimensions", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: widthController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Largeur"))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: heightController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Hauteur"))),
                ],
              ),
              const SizedBox(height: 20),
              const Text("Règles de Jeu", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent)),
              const SizedBox(height: 8),
              TextField(
                controller: visionController, 
                keyboardType: TextInputType.number, 
                decoration: const InputDecoration(
                  labelText: "Distance de Vue (cases)",
                  prefixIcon: Icon(Icons.visibility),
                  helperText: "Rayon du Brouillard de Guerre"
                )
              ),
              const SizedBox(height: 8),
              TextField(
                controller: movementController, 
                keyboardType: TextInputType.number, 
                decoration: const InputDecoration(
                  labelText: "Distance de Déplacement",
                  prefixIcon: Icon(Icons.directions_run),
                  helperText: "Rayon de la zone verte"
                )
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () {
              final w = int.tryParse(widthController.text) ?? 20;
              final h = int.tryParse(heightController.text) ?? 16;
              final v = int.tryParse(visionController.text) ?? 8;
              final m = int.tryParse(movementController.text) ?? 6;

              setState(() {
                // Mise à jour Config
                _mapConfig = MapConfig(
                  widthInCells: w, 
                  heightInCells: h, 
                  cellSize: _mapConfig.cellSize,
                  backgroundColor: _mapConfig.backgroundColor,
                  gridColor: _mapConfig.gridColor
                );
                // Mise à jour Règles
                _visionRange = v;
                _movementRange = m;
              });
              
              _recalculateFog();
              _calculateMovementRange();
              
              Navigator.pop(ctx);
            },
            child: const Text("Appliquer"),
          ),
        ],
      ),
    );
  }

  void _floodFill(Point<int> startPoint, TileType newType) {
    final startKey = "${startPoint.x},${startPoint.y}";
    final targetType = _gridData[startKey]; // Le type qu'on veut remplacer (peut être null)

    // Si on clique sur une case qui a déjà la bonne couleur, on ne fait rien
    if (targetType == newType) return;

    final Queue<Point<int>> queue = Queue();
    queue.add(startPoint);
    
    // Pour éviter les boucles infinies
    final Set<String> visited = {startKey};

    while (queue.isNotEmpty) {
      final p = queue.removeFirst();
      final key = "${p.x},${p.y}";
      
      // On peint
      _gridData[key] = newType;
      // Si on peint un mur sur un objet, on vire l'objet
      if (newType == TileType.stoneWall && _objects.containsKey(key)) {
        _objects.remove(key);
      }

      // Voisins
      for (var neighbor in HexUtils.getNeighbors(p)) {
        // Vérification des limites de la carte
        if (neighbor.x < 0 || neighbor.x >= _mapConfig.widthInCells || 
            neighbor.y < 0 || neighbor.y >= _mapConfig.heightInCells) {
          continue;
        }

        final nKey = "${neighbor.x},${neighbor.y}";
        final nType = _gridData[nKey];

        // Si le voisin est du même type que la case de départ (ou vide si départ vide)
        if (!visited.contains(nKey) && nType == targetType) {
          visited.add(nKey);
          queue.add(neighbor);
        }
      }
    }
    setState(() {}); // Rafraîchir
    _recalculateFog(); // Mettre à jour les murs potentiels
  }

  @override
  Widget build(BuildContext context) {
    final w = ((_mapConfig.widthInCells + 0.5) * HexUtils.width(_hexRadius)) + (_mapMargin * 2);
    final h = ((_mapConfig.heightInCells * 0.75 * HexUtils.height(_hexRadius)) + HexUtils.height(_hexRadius)) + (_mapMargin * 2);
    final canInteract = _selectedTool == EditorTool.move;

    final tokenDetails = { for (var m in _members) m['char_id'].toString() : {'name': m['char_name'], 'color': Colors.primaries[m['char_id'].toString().hashCode % Colors.primaries.length]} };

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dungeon Studio"), backgroundColor: const Color(0xFF1a1a1a),
        actions: [
          IconButton(icon: Icon(_fogEnabled ? Icons.visibility_off : Icons.visibility), onPressed: () { setState(() => _fogEnabled = !_fogEnabled); _recalculateFog(); }),
          IconButton(icon: const Icon(Icons.settings), onPressed: _openMapSettings), // Bouton Réglages
          IconButton(icon: const Icon(Icons.save, color: Colors.blueAccent), onPressed: _save), 
        ],
      ),
      backgroundColor: const Color(0xFF121212),
      body: Row(
        children: [
          EditorPalette(
            selectedTool: _selectedTool,
            selectedTileType: _selectedTileType,
            selectedObjectType: _selectedObjectType,
            onToolChanged: (t) {
              setState(() => _selectedTool = t);
              if (t != EditorTool.token) setState(() => _reachableCells = {});
            },
            onTileTypeChanged: (t) => setState(() => _selectedTileType = t),
            onObjectTypeChanged: (o) => setState(() => _selectedObjectType = o),
            isPortrait: false,
          ),
          
          // CANVAS AVEC DRAG & DROP
          Expanded(
            child: Container(
              color: Colors.black,
              child: LayoutBuilder(builder: (context, constraints) {
                // DRAG TARGET : C'est la zone d'atterrissage
                return DragTarget<Map<String, dynamic>>(
                  // Appelé quand on lâche le monstre
                  onAcceptWithDetails: (details) {
                    final renderBox = context.findRenderObject() as RenderBox;
                    final localPos = renderBox.globalToLocal(details.offset);
                    
                    // On doit convertir la position écran (global) en position grille locale
                    // Attention: il faut compenser le décalage du TransformationController (Zoom/Pan)
                    final matrix = _transformationController.value;
                    final inverseMatrix = Matrix4.inverted(matrix);
                    final transformedPos = MatrixUtils.transformPoint(inverseMatrix, localPos);
                    
                    final mapPos = transformedPos - const Offset(_mapMargin, _mapMargin);
                    final point = HexUtils.pixelToGrid(mapPos, _hexRadius, _mapConfig.widthInCells, _mapConfig.heightInCells);

                    if (point.x >= 0 && point.y >= 0) {
                      final monsterData = details.data;
                      
                      // Création d'un ID unique pour cette instance de monstre
                      final uniqueId = "${monsterData['id']}_${DateTime.now().millisecondsSinceEpoch}";
                      
                      setState(() {
                        // 1. On ajoute le token sur la carte
                        _tokenPositions[uniqueId] = point;
                        
                        // 2. On l'ajoute à la liste des "membres" (même si c'est un monstre)
                        // Pour l'instant on les mélange, on séparera plus tard pour le combat
                        _members.add({
                          'char_id': uniqueId,
                          'char_name': monsterData['name'],
                          'hp': monsterData['hp'],
                          'ac': monsterData['ac'],
                          'is_monster': true, // Marqueur pour plus tard
                        });
                      });
                      
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text("${monsterData['name']} ajouté ! 🐉"),
                        backgroundColor: Colors.redAccent,
                        duration: const Duration(milliseconds: 800),
                      ));
                    }
                  },
                  
                  builder: (context, candidateData, rejectedData) {
                    return InteractiveViewer(
                      transformationController: _transformationController,
                      boundaryMargin: const EdgeInsets.all(double.infinity),
                      minScale: 0.1, maxScale: 5.0, constrained: false,
                      panEnabled: canInteract, scaleEnabled: canInteract,
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: _onPointerEvent, onPointerMove: _onPointerEvent,
                        child: MapCanvasWidget(
                          // ... (Garde tous tes paramètres existants ici) ...
                          mapConfig: _mapConfig,
                          assets: _assets,
                          gridData: _gridData,
                          tokenPositions: _tokenPositions, 
                          tokenDetails: tokenDetails,
                          objects: _objects, 
                          visibleCells: _visibleCells, 
                          exploredCells: _exploredCells, 
                          reachableCells: _reachableCells,
                          fogEnabled: _fogEnabled, 
                          hexRadius: _hexRadius, 
                          mapMargin: _mapMargin,
                          totalWidth: w, totalHeight: h,
                          tileRotations: _tileRotations,
                          animation: _animController, // <--- NOUVEAU
                          
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
          
          if (_selectedTool == EditorTool.token)
            Container(
              width: 60, color: const Color(0xFF1a1a1a),
              child: ListView.builder(
                itemCount: _members.length,
                itemBuilder: (ctx, i) {
                  final m = _members[i];
                  final id = m['char_id'].toString();
                  return GestureDetector(
                    onTap: () => setState(() { _selectedCharId = id; _calculateMovementRange(); }),
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(shape: BoxShape.circle, border: _selectedCharId == id ? Border.all(color: Colors.greenAccent, width: 2) : null),
                      child: CircleAvatar(child: Text(m['char_name'][0])),
                    ),
                  );
                },
              ),
            )
        ],
      ),
    );
  }
  // --- SAUVEGARDE ---
  void _save() async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sauvegarde... ⏳")));
    
    final mapToSave = MapDataModel(
      id: widget.mapId,
      name: "Ma Carte",
      config: _mapConfig,
      gridData: _gridData, 
      objects: _objects,
      tileRotations: _tileRotations,
    );

    bool success = await _mapRepo.saveMapData(mapToSave);
    
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success ? "Sauvegardé ! 💾" : "Erreur ❌"),
      backgroundColor: success ? Colors.green : Colors.red,
    ));
  }


}

class MapCanvasWidget extends StatelessWidget {
  final MapConfig mapConfig;
  final Map<String, ui.Image> assets;
  final Map<String, TileType> gridData;
  final Map<String, Point<int>> tokenPositions;
  final Map<String, WorldObject> objects; 
  final Map<String, dynamic> tokenDetails;
  final Map<String, int> tileRotations;
  final Set<String> visibleCells;
  final Set<String> exploredCells;
  final Set<String> reachableCells;
  final bool fogEnabled;
  final double hexRadius;
  final double mapMargin;
  final double totalWidth;
  final double totalHeight;
  final Animation<double> animation;

  const MapCanvasWidget({
    super.key, 
    required this.mapConfig, required this.assets,
    required this.gridData, required this.tokenPositions, required this.objects, 
    required this.tokenDetails, required this.visibleCells, required this.exploredCells, 
    required this.reachableCells, required this.fogEnabled, required this.tileRotations,
    required this.hexRadius, required this.mapMargin, required this.totalWidth, required this.totalHeight, required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final offset = Offset(mapMargin, mapMargin);
    return Container(
      width: totalWidth, height: totalHeight,
      decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20)]),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: BackgroundPatternPainter(backgroundColor: mapConfig.backgroundColor, patternImage: assets['parchment']))),
          
          RepaintBoundary(child: CustomPaint(size: Size(totalWidth, totalHeight), painter: TileLayerPainter(
            config: mapConfig, assets: assets, gridData: gridData, radius: hexRadius, offset: offset, tileRotations: tileRotations, animationValue: animation.value
          ))),
          
          RepaintBoundary(child: CustomPaint(size: Size(totalWidth, totalHeight), painter: ObjectPainter(
            config: mapConfig, objects: objects, assets: assets, radius: hexRadius, offset: offset
          ))),
          
          IgnorePointer(child: CustomPaint(size: Size(totalWidth, totalHeight), painter: GridPainter(config: mapConfig, radius: hexRadius, offset: offset))),
          
          RepaintBoundary(child: CustomPaint(size: Size(totalWidth, totalHeight), painter: MovementPainter(
            config: mapConfig, reachableCells: fogEnabled ? reachableCells.intersection(visibleCells) : reachableCells, radius: hexRadius, offset: offset
          ))),
          
          RepaintBoundary(child: CustomPaint(size: Size(totalWidth, totalHeight), painter: TokenPainter(
            config: mapConfig, tokenPositions: tokenPositions, tokenDetails: tokenDetails, radius: hexRadius, offset: offset
          ))),

          if (fogEnabled)
          IgnorePointer(child: CustomPaint(size: Size(totalWidth, totalHeight), painter: FogPainter(
              config: mapConfig, visibleCells: visibleCells, exploredCells: exploredCells, radius: hexRadius, offset: offset
            ))),
          RepaintBoundary(child: CustomPaint(size: Size(totalWidth, totalHeight), painter: LightingPainter(
            objects: objects, radius: hexRadius, offset: offset
          ))),

          AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return CustomPaint(
                size: Size(totalWidth, totalHeight), 
                painter: TileLayerPainter(
                  config: mapConfig, 
                  assets: assets, 
                  gridData: gridData, 
                  tileRotations: tileRotations,
                  radius: hexRadius, 
                  offset: offset,
                  animationValue: animation.value, // <--- On passe la valeur (0.0 à 1.0)
                )
              );
              }
          ),

        ],
      ),
    );
  }
}
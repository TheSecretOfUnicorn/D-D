import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:collection';

// --- IMPORTS MODÈLES ---
import '../../data/models/map_config_model.dart';
import '../../data/models/tile_type.dart';
import '../../data/models/world_object_model.dart';
import '../../data/models/map_data_model.dart'; // Utilise le vrai modèle

// --- IMPORTS UTILS ---
import '/core/utils/hex_utils.dart'; 
import '../../../../core/utils/image_loader.dart';
import '/core/utils/logger_service.dart';

// --- IMPORTS SERVICES ---
import '../../core/services/fog_of_war_service.dart';
import '../../core/services/pathfinding_service.dart';
import '../../../campaign_manager/data/repositories/campaign_repository.dart';
import '../../data/repositories/map_repository.dart'; // Utilise le vrai repo

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

  // --- PARAMÈTRES DE JEU ---
  int _visionRange = 8;   
  int _movementRange = 6; 

  // UI
  List<Map<String, dynamic>> _members = []; 
  String? _selectedCharId; 
  
  EditorTool _selectedTool = EditorTool.brush;
  TileType _selectedTileType = TileType.stoneFloor;
  ObjectType _selectedObjectType = ObjectType.door; 
  
  // final bool _isPortrait = false; // (Inutilisé pour l'instant dans ce code, mais gardé si besoin)
  double get _hexRadius => _mapConfig.cellSize / HexUtils.sqrt3;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this, 
      duration: const Duration(seconds: 2)
    )..repeat(reverse: true);
    
    _loadAllAssets();
    _loadMembers();
    if (widget.mapId != "new_map") {
      _loadMapData();
      
      } else {
      Log.error("🆕 Nouvelle carte détectée, pas de chargement.");
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculateFog());
  }

  @override
  void dispose() {
    _animController.dispose(); 
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
      } catch (e) {
        debugPrint("Asset manquant : ${entry.key}");
      }
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

    final walls = _gridData.entries
      .where((e) => e.value == TileType.stoneWall || e.value == TileType.tree)
      .map((e) => e.key).toSet();
    final closedDoors = _objects.values
      .where((obj) => obj.type == ObjectType.door && obj.state == false)
      .map((obj) => "${obj.position.x},${obj.position.y}");
    final allBlockers = walls.union(closedDoors.toSet());

    List<VisionSource> sources = [];

    // Pions
    for (var pos in _tokenPositions.values) {
      sources.add(VisionSource(pos, _visionRange));
    }

    // Lumières
    for (var obj in _objects.values) {
      if (obj.lightRadius > 0) {
        sources.add(VisionSource(obj.position, obj.lightRadius.toInt()));
      }
    }

    final visible = FogOfWarService.calculateVisibility(
      sources: sources,
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
      movement: _movementRange,
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
            lightRadius: lightRad,
            lightColor: lightCol,
          );
          changed = true;
        }
      }
      else if (_selectedTool == EditorTool.interact && details is PointerDownEvent) {
        if (_objects.containsKey(key)) {
          final obj = _objects[key]!;
          _objects[key] = obj.copyWith(state: !obj.state);
          changed = true;
        }
      }

      else if (_selectedTool == EditorTool.rotate && details is PointerDownEvent) {
        bool changedHere = false;
        
        if (_objects.containsKey(key)) {
          final obj = _objects[key]!;
          final newRot = (obj.rotation + 1) % 8; // 8 directions
          _objects[key] = obj.copyWith(rotation: newRot);
          changedHere = true;
        }
        else if (_gridData.containsKey(key)) {
          final currentRot = _tileRotations[key] ?? 0;
          final newRot = (currentRot + 1) % 6; // 6 directions
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

  // --- PARAMÈTRES ---
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
                  labelText: "Distance de Vue",
                  prefixIcon: Icon(Icons.visibility),
                )
              ),
              const SizedBox(height: 8),
              TextField(
                controller: movementController, 
                keyboardType: TextInputType.number, 
                decoration: const InputDecoration(
                  labelText: "Distance de Déplacement",
                  prefixIcon: Icon(Icons.directions_run),
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
                _mapConfig = MapConfig(
                  widthInCells: w, 
                  heightInCells: h, 
                  cellSize: _mapConfig.cellSize,
                  backgroundColor: _mapConfig.backgroundColor,
                  gridColor: _mapConfig.gridColor
                );
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
    final targetType = _gridData[startKey];

    if (targetType == newType) return;

    final Queue<Point<int>> queue = Queue();
    queue.add(startPoint);
    final Set<String> visited = {startKey};

    while (queue.isNotEmpty) {
      final p = queue.removeFirst();
      final key = "${p.x},${p.y}";
      
      _gridData[key] = newType;
      if (newType == TileType.stoneWall && _objects.containsKey(key)) {
        _objects.remove(key);
      }

      for (var neighbor in HexUtils.getNeighbors(p)) {
        if (neighbor.x < 0 || neighbor.x >= _mapConfig.widthInCells || 
            neighbor.y < 0 || neighbor.y >= _mapConfig.heightInCells) {
          continue;
        }

        final nKey = "${neighbor.x},${neighbor.y}";
        final nType = _gridData[nKey];

        if (!visited.contains(nKey) && nType == targetType) {
          visited.add(nKey);
          queue.add(neighbor);
        }
      }
    }
    setState(() {});
    _recalculateFog();
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
          IconButton(icon: const Icon(Icons.settings), onPressed: _openMapSettings),
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
          
          Expanded(
            child: Container(
              color: Colors.black,
              child: LayoutBuilder(builder: (context, constraints) {
                return DragTarget<Map<String, dynamic>>(
                  onAcceptWithDetails: (details) {
                    final renderBox = context.findRenderObject() as RenderBox;
                    final localPos = renderBox.globalToLocal(details.offset);
                    final matrix = _transformationController.value;
                    final inverseMatrix = Matrix4.inverted(matrix);
                    final transformedPos = MatrixUtils.transformPoint(inverseMatrix, localPos);
                    final mapPos = transformedPos - const Offset(_mapMargin, _mapMargin);
                    final point = HexUtils.pixelToGrid(mapPos, _hexRadius, _mapConfig.widthInCells, _mapConfig.heightInCells);

                    if (point.x >= 0 && point.y >= 0) {
                      final monsterData = details.data;
                      final uniqueId = "${monsterData['id']}_${DateTime.now().millisecondsSinceEpoch}";
                      
                      setState(() {
                        _tokenPositions[uniqueId] = point;
                        _members.add({
                          'char_id': uniqueId,
                          'char_name': monsterData['name'],
                          'hp': monsterData['hp'],
                          'ac': monsterData['ac'],
                          'is_monster': true,
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
                          animation: _animController,
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
Future<void> _loadMapData() async {
    // Petit délai pour laisser l'UI s'afficher
    await Future.delayed(const Duration(milliseconds: 100)); 

    final mapData = await _mapRepo.getMapData(widget.mapId);
    
    if (mapData != null && mounted) {
      setState(() {
        // 1. On applique la config (taille, couleurs)
        _mapConfig = mapData.config;
        
        // 2. On vide et remplit la grille
        _gridData.clear();
        _gridData.addAll(mapData.gridData);
        
        // 3. On vide et remplit les objets
        _objects.clear();
         _objects.addAll(mapData.objects!);
            });
      
      // 4. On recalcule le brouillard avec les nouveaux murs
      _recalculateFog();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Carte chargée ! (${_gridData.length} éléments)"), backgroundColor: Colors.green)
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible de charger la carte ❌"), backgroundColor: Colors.red)
      );
    }
  }
  // --- SAUVEGARDE ---
  void _save() async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sauvegarde... ⏳"), duration: Duration(seconds: 1)));

    // 1. GESTION DE L'ID
    String? currentMapId = widget.mapId;
    
    // Si l'ID est null ou "new_map", c'est une CRÉATION
    if (currentMapId == "new_map") {
      // On crée d'abord la carte vide pour avoir un ID
      final newId = await _mapRepo.createMap(
        widget.campaignId, 
        "Nouvelle Carte", // Vous pourrez mettre un champ texte pour le nom plus tard
        MapConfig(
          cellSize: _mapConfig.cellSize,
          backgroundColor: _mapConfig.backgroundColor,
          gridColor: _mapConfig.gridColor,
          widthInCells: _mapConfig.widthInCells, 
          heightInCells: _mapConfig.heightInCells,)
      );

      if (newId != null) {
        currentMapId = newId.toString();
        // Optionnel : Mettre à jour l'état pour que les prochaines sauvegardes soient des updates
        // setState(() { widget.mapId = currentMapId; }); // Attention widget.mapId est final, idéalement on recharge la page ou on utilise une variable d'état locale
      } else {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur lors de la création de la carte ❌"), backgroundColor: Colors.red));
         return;
      }
    }

    // 2. SAUVEGARDE DES DONNÉES (Maintenant qu'on a un vrai ID)
    final mapToSave = MapDataModel(
      id: currentMapId, // On utilise l'ID corrigé (ex: "42")
      name: "Ma Carte Hex",
      config: _mapConfig,
      gridData: _gridData,
      objects: _objects
    );

    bool success = await _mapRepo.saveMapData(mapToSave);
    
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Carte sauvegardée ! 💾"), backgroundColor: Colors.green));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur de sauvegarde ❌"), backgroundColor: Colors.red));
    }
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
          // 1. Fond
          Positioned.fill(child: CustomPaint(painter: BackgroundPatternPainter(backgroundColor: mapConfig.backgroundColor, patternImage: assets['parchment']))),
          
          // 2. Tuiles ANIMÉES (On remplace la version statique par celle-ci)
          // Utilisation d'AnimatedBuilder pour ne redessiner que ce layer
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
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
                      animationValue: animation.value, // <--- Valeur animée
                    )
                  );
                }
              ),
            ),
          ),
          
          // 3. Objets
          RepaintBoundary(child: CustomPaint(size: Size(totalWidth, totalHeight), painter: ObjectPainter(
            config: mapConfig, objects: objects, assets: assets, radius: hexRadius, offset: offset
          ))),
          
          // 4. Grille
          IgnorePointer(child: CustomPaint(size: Size(totalWidth, totalHeight), painter: GridPainter(config: mapConfig, radius: hexRadius, offset: offset))),
          
          // 5. Zone de mouvement
          RepaintBoundary(child: CustomPaint(size: Size(totalWidth, totalHeight), painter: MovementPainter(
            config: mapConfig, reachableCells: fogEnabled ? reachableCells.intersection(visibleCells) : reachableCells, radius: hexRadius, offset: offset
          ))),
          
          // 6. Tokens
          RepaintBoundary(child: CustomPaint(size: Size(totalWidth, totalHeight), painter: TokenPainter(
            config: mapConfig, tokenPositions: tokenPositions, tokenDetails: tokenDetails, radius: hexRadius, offset: offset
          ))),

          // 7. Brouillard
          if (fogEnabled)
            IgnorePointer(child: CustomPaint(size: Size(totalWidth, totalHeight), painter: FogPainter(
              config: mapConfig, visibleCells: visibleCells, exploredCells: exploredCells, radius: hexRadius, offset: offset
            ))),
            
          // 8. Lumières Dynamiques (Par dessus le brouillard pour l'effet Glow)
          RepaintBoundary(child: CustomPaint(size: Size(totalWidth, totalHeight), painter: LightingPainter(
            objects: objects, radius: hexRadius, offset: offset
          ))),
        ],
      ),
    );
  }
}
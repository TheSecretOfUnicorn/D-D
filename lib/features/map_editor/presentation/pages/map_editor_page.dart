import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// --- IMPORTS DU PROJET ---
import '../../data/models/map_config_model.dart';
import '../../data/models/tile_type.dart'; // Assure-toi d'avoir créé ce fichier (Etape précédente)
import '/core/utils/hex_utils.dart'; 
import '../../../../core/utils/image_loader.dart';

// --- SERVICES & REPOS ---
import '../../core/services/fog_of_war_service.dart';
import '../../../campaign_manager/data/repositories/campaign_repository.dart';

// --- PAINTERS ---
import '../painters/grid_painter.dart';
import '../painters/tile_layer_painter.dart';
import '../painters/background_pattern_painter.dart';
import '../painters/token_painter.dart';
import '../painters/fog_painter.dart';

// --- MOCKS (A SUPPRIMER une fois tes vrais fichiers créés) ---
class MapRepository {
  Future<bool> saveMapData(dynamic data) async {
    await Future.delayed(const Duration(seconds: 1)); 
    return true; 
  }
}
class MapDataModel {
  final String? id; final String name; final MapConfig config; 
  final Map<String, TileType> gridData; // On sauvegarde la Map complète
  MapDataModel({this.id, required this.name, required this.config, required this.gridData});
}
// -------------------------------------------------------------

enum EditorTool { move, brush, eraser, token }

class MapEditorPage extends StatefulWidget {
  final int campaignId;
  final String mapId;

  const MapEditorPage({
    super.key, 
    this.campaignId = 0, // Valeur par défaut pour le debug
    this.mapId = "new_map"
  });

  @override
  State<MapEditorPage> createState() => _MapEditorPageState();
}

class _MapEditorPageState extends State<MapEditorPage> {
  // Repositories
  final CampaignRepository _campRepo = CampaignRepository();
  final MapRepository _mapRepo = MapRepository();

  // Config Carte (20x16 cases)
  final mapConfig = const MapConfig(
    widthInCells: 20,
    heightInCells: 16,
    cellSize: 64.0, 
    backgroundColor: Color(0xFFE0D8C0), 
    gridColor: Color(0x4D5C4033),       
  );

  static const double _mapMargin = 50.0;
  final TransformationController _transformationController = TransformationController();
  
  // Textures
  ui.Image? _parchmentTexture;
  ui.Image? _floorTexture;
  ui.Image? _wallTexture;
  
  // DONNÉES DE LA CARTE
  final Map<String, TileType> _gridData = {};        // Sols et Murs
  final Map<String, Point<int>> _tokenPositions = {}; // Positions des personnages
  
  // BROUILLARD DE GUERRE
  Set<String> _visibleCells = {};
  final Set<String> _exploredCells = {};
  bool _fogEnabled = true;

  // DONNÉES CAMPAGNE
  List<Map<String, dynamic>> _members = []; 
  String? _selectedCharId; 
  
  // ÉTAT UI
  EditorTool _selectedTool = EditorTool.brush;
  TileType _selectedTileType = TileType.floor;
  bool _isPortrait = false; 

  double get _hexRadius => mapConfig.cellSize / HexUtils.sqrt3;

  @override
  void initState() {
    super.initState();
    _loadAssets();
    _loadMembers();
    // Calcul initial du brouillard au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculateFog());
  }

  Future<void> _loadAssets() async {
    try {
      final parchment = await ImageLoader.loadAsset('assets/images/ui/parchment_bg.png');
      if (mounted) setState(() => _parchmentTexture = parchment);
    } catch (e) { debugPrint("⚠️ Parchemin: $e"); }

    try {
      final floor = await ImageLoader.loadAsset('assets/images/tiles/stone_floor.png');
      if (mounted) setState(() => _floorTexture = floor);
    } catch (e) { debugPrint("⚠️ Sol: $e"); }

    try {
      final wall = await ImageLoader.loadAsset('assets/images/tiles/stone_wall.png');
      if (mounted) setState(() => _wallTexture = wall);
    } catch (e) { debugPrint("⚠️ Mur: $e"); }
  }

  Future<void> _loadMembers() async {
    // Si campaignId est 0 (debug), on met des faux membres
    if (widget.campaignId == 0) {
      if (mounted) {
        setState(() {
          _members = [
            {'char_id': '1', 'char_name': 'Héros'},
            {'char_id': '2', 'char_name': 'Monstre'},
          ];
        });
      }
      return;
    }

    try {
      final members = await _campRepo.getMembers(widget.campaignId);
      if (mounted) {
        setState(() {
          _members = members.where((m) => m['char_id'] != null).toList();
        });
      }
    } catch (e) {
      debugPrint("Erreur chargement membres: $e");
    }
  }

  // --- LOGIQUE BROUILLARD ---
  void _recalculateFog() {
    if (!_fogEnabled) {
      setState(() => _visibleCells = {});
      return;
    }

    // 1. Identifier les murs
    final walls = _gridData.entries
      .where((e) => e.value == TileType.wall)
      .map((e) => e.key)
      .toSet();

    // 2. Positions des tokens
    final tokenList = _tokenPositions.values.toList();

    // 3. Calculer via le Service
    final visible = FogOfWarService.calculateVisibility(
      tokens: tokenList,
      walls: walls,
      maxCols: mapConfig.widthInCells,
      maxRows: mapConfig.heightInCells,
      visionRange: 6, // Rayon de vue
    );

    setState(() {
      _visibleCells = visible;
      _exploredCells.addAll(visible);
    });
  }

  // --- INTERACTION ---
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
      bool changed = false;

      // 1. PINCEAU (SOL / MUR)
      if (_selectedTool == EditorTool.brush) {
        if (_gridData[key] != _selectedTileType) {
          setState(() => _gridData[key] = _selectedTileType);
          changed = true;
        }
      } 
      // 2. GOMME
      else if (_selectedTool == EditorTool.eraser) {
        if (_gridData.containsKey(key)) {
          setState(() => _gridData.remove(key));
          changed = true;
        }
        // On enlève aussi le token s'il y en a un
        if (_tokenPositions.containsValue(point)) {
           final idToRemove = _tokenPositions.entries.firstWhere((e) => e.value == point).key;
           setState(() => _tokenPositions.remove(idToRemove));
           changed = true;
        }
      }
      // 3. TOKEN
      else if (_selectedTool == EditorTool.token && details is PointerDownEvent) {
        if (_selectedCharId == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sélectionnez un personnage !")));
        } else {
          setState(() => _tokenPositions[_selectedCharId!] = point);
          changed = true;
        }
      }

      // Si quelque chose a changé, on recalcule le brouillard
      if (changed) {
        _recalculateFog();
      }
    }
  }

  void _save() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sauvegarde... ⏳")));
    final mapToSave = MapDataModel(
      id: widget.mapId,
      name: "Ma Carte",
      config: mapConfig,
      gridData: _gridData, 
    );
    bool success = await _mapRepo.saveMapData(mapToSave);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success ? "Sauvegardé ! 💾" : "Erreur ❌"),
      backgroundColor: success ? Colors.green : Colors.red,
    ));
  }

  // --- CONSTRUCTION UI ---
  @override
  Widget build(BuildContext context) {
    final w = ((mapConfig.widthInCells + 0.5) * HexUtils.width(_hexRadius)) + (_mapMargin * 2);
    final h = ((mapConfig.heightInCells * 0.75 * HexUtils.height(_hexRadius)) + HexUtils.height(_hexRadius)) + (_mapMargin * 2);
    final canInteractWithMap = _selectedTool == EditorTool.move;

    // Prépare les couleurs pour les tokens
    final Map<String, dynamic> tokenDetails = {};
    for (var m in _members) {
      final cid = m['char_id'].toString();
      tokenDetails[cid] = {
        'name': m['char_name'],
        'color': Colors.primaries[cid.hashCode % Colors.primaries.length]
      };
    }

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
                wallTexture: _wallTexture,
                parchmentTexture: _parchmentTexture,
                gridData: _gridData,
                tokenPositions: _tokenPositions,
                tokenDetails: tokenDetails,
                visibleCells: _visibleCells,
                exploredCells: _exploredCells,
                fogEnabled: _fogEnabled,
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
        title: const Text("Table Virtuelle"), backgroundColor: const Color(0xFF1a1a1a),
        actions: [
          // Bouton Brouillard ON/OFF
          IconButton(
            icon: Icon(_fogEnabled ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
            tooltip: "Activer/Désactiver Brouillard",
            onPressed: () {
              setState(() => _fogEnabled = !_fogEnabled);
              _recalculateFog();
            },
          ),
          IconButton(icon: const Icon(Icons.save, color: Colors.blueAccent), onPressed: _save),
          IconButton(
            icon: Icon(_isPortrait ? Icons.stay_current_landscape : Icons.stay_current_portrait),
            onPressed: () => setState(() => _isPortrait = !_isPortrait),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF121212),
      body: _isPortrait
        ? Column(children: [Expanded(child: canvasArea), SizedBox(height: 140, child: _buildPalette(Axis.horizontal))])
        : Row(children: [SizedBox(width: 90, child: _buildPalette(Axis.vertical)), Expanded(child: canvasArea)]),
    );
  }

  Widget _buildPalette(Axis direction) {
    return Container(
      color: const Color(0xFF252525),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: direction,
              child: Flex(
                direction: direction,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const SizedBox(width: 5, height: 5),
                  _ToolButton(icon: Icons.pan_tool, label: "Vue", isSelected: _selectedTool == EditorTool.move, onTap: () => setState(() => _selectedTool = EditorTool.move)),
                  const SizedBox(width: 5, height: 5),
                  _ToolButton(icon: Icons.cleaning_services, label: "Gomme", isSelected: _selectedTool == EditorTool.eraser, onTap: () => setState(() => _selectedTool = EditorTool.eraser)),
                  const Divider(color: Colors.white24, indent: 5, endIndent: 5),
                  
                  // TYPES DE TERRAIN
                  _TileTypeButton(label: "Sol", color: Colors.grey, isSelected: _selectedTool == EditorTool.brush && _selectedTileType == TileType.floor, onTap: () => setState(() { _selectedTool = EditorTool.brush; _selectedTileType = TileType.floor; })),
                  const SizedBox(width: 5, height: 5),
                  _TileTypeButton(label: "Mur", color: Colors.brown, isSelected: _selectedTool == EditorTool.brush && _selectedTileType == TileType.wall, onTap: () => setState(() { _selectedTool = EditorTool.brush; _selectedTileType = TileType.wall; })),
                  
                  const Divider(color: Colors.white24, indent: 5, endIndent: 5),
                  // TOKEN
                  _ToolButton(icon: Icons.person, label: "Pions", isSelected: _selectedTool == EditorTool.token, onTap: () => setState(() => _selectedTool = EditorTool.token)),
                ],
              ),
            ),
          ),
          
          // LISTE DES PERSONNAGES (Si outil Token actif)
          if (_selectedTool == EditorTool.token)
             Container(
               height: direction == Axis.vertical ? 200 : 50,
               width: direction == Axis.horizontal ? double.infinity : null,
               color: Colors.black26,
               child: ListView.builder(
                 scrollDirection: direction,
                 itemCount: _members.length,
                 itemBuilder: (ctx, i) {
                   final m = _members[i];
                   final charId = m['char_id'].toString();
                   return GestureDetector(
                     onTap: () => setState(() => _selectedCharId = charId),
                     child: Container(
                       margin: const EdgeInsets.all(4),
                       padding: const EdgeInsets.all(2),
                       decoration: BoxDecoration(
                         border: _selectedCharId == charId ? Border.all(color: Colors.greenAccent, width: 2) : null,
                         shape: BoxShape.circle,
                       ),
                       child: CircleAvatar(
                         radius: 16,
                         backgroundColor: Colors.primaries[charId.hashCode % Colors.primaries.length],
                         child: Text(m['char_name'][0], style: const TextStyle(color: Colors.white, fontSize: 12)),
                       ),
                     ),
                   );
                 },
               ),
             )
        ],
      ),
    );
  }
}

// --- WIDGETS UI ---
class _ToolButton extends StatelessWidget {
  final IconData icon; final String label; final bool isSelected; final VoidCallback onTap;
  const _ToolButton({required this.icon, required this.label, required this.isSelected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: Container(margin: const EdgeInsets.all(4), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isSelected ? Colors.blueAccent : Colors.transparent, borderRadius: BorderRadius.circular(8), border: isSelected ? Border.all(color: Colors.white) : Border.all(color: Colors.white24)), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: Colors.white, size: 20), Text(label, style: const TextStyle(color: Colors.white, fontSize: 10))])));
  }
}
class _TileTypeButton extends StatelessWidget {
  final String label; final Color color; final bool isSelected; final VoidCallback onTap;
  const _TileTypeButton({required this.label, required this.color, required this.isSelected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: Container(margin: const EdgeInsets.all(4), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isSelected ? Colors.green.withValues(alpha: 0.5) : Colors.transparent, borderRadius: BorderRadius.circular(8), border: isSelected ? Border.all(color: Colors.greenAccent, width: 2) : Border.all(color: Colors.white24)), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 20, height: 20, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white54))), const SizedBox(height: 4), Text(label, style: const TextStyle(color: Colors.white, fontSize: 10))])));
  }
}

// --- CANVAS WIDGET ---
class MapCanvasWidget extends StatelessWidget {
  final MapConfig mapConfig;
  final ui.Image? floorTexture;
  final ui.Image? wallTexture;
  final ui.Image? parchmentTexture;
  final Map<String, TileType> gridData;
  final Map<String, Point<int>> tokenPositions;
  final Map<String, dynamic> tokenDetails;
  final Set<String> visibleCells;
  final Set<String> exploredCells;
  final bool fogEnabled;
  final double hexRadius;
  final double mapMargin;
  final double totalWidth;
  final double totalHeight;

  const MapCanvasWidget({
    super.key, required this.mapConfig, this.floorTexture, this.wallTexture, this.parchmentTexture,
    required this.gridData, required this.tokenPositions, required this.tokenDetails,
    required this.visibleCells, required this.exploredCells, required this.fogEnabled,
    required this.hexRadius, required this.mapMargin, required this.totalWidth, required this.totalHeight,
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
          Positioned.fill(child: CustomPaint(painter: BackgroundPatternPainter(backgroundColor: mapConfig.backgroundColor, patternImage: parchmentTexture))),
          
          // 2. Tuiles (Sols & Murs)
          RepaintBoundary(child: CustomPaint(size: Size(totalWidth, totalHeight), painter: TileLayerPainter(
            config: mapConfig, floorImage: floorTexture, wallImage: wallTexture, gridData: gridData, radius: hexRadius, offset: offset
          ))),
          
          // 3. Grille (Peut être au dessus ou en dessous)
          IgnorePointer(child: CustomPaint(size: Size(totalWidth, totalHeight), painter: GridPainter(
            config: mapConfig, radius: hexRadius, offset: offset
          ))),

          // 4. Tokens
          RepaintBoundary(child: CustomPaint(size: Size(totalWidth, totalHeight), painter: TokenPainter(
            config: mapConfig, tokenPositions: tokenPositions, tokenDetails: tokenDetails, radius: hexRadius, offset: offset
          ))),

          // 5. Brouillard de Guerre (Tout en haut)
          if (fogEnabled)
            IgnorePointer(child: CustomPaint(size: Size(totalWidth, totalHeight), painter: FogPainter(
              config: mapConfig, visibleCells: visibleCells, exploredCells: exploredCells, radius: hexRadius, offset: offset
            ))),
        ],
      ),
    );
  }
}
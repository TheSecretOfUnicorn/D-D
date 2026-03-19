import 'dart:async';
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
import '/core/services/socket_service.dart';
import '../../../../core/services/session_service.dart';
// --- IMPORTS SERVICES ---
import '../../core/services/fog_of_war_service.dart';
import '../../core/services/pathfinding_service.dart';
import '../../../campaign_manager/data/repositories/campaign_repository.dart';
import '../../../bug_report/presentation/widgets/bug_report_action.dart';
import '../../../character_sheet/data/models/character_model.dart';
import '../../../character_sheet/data/repositories/character_repository_impl.dart';
import '../../../character_sheet/presentation/pages/character_sheet_page.dart';
import '../../../combat/data/models/combatant_model.dart';
import '../../../rules_engine/data/repositories/rules_repository_impl.dart';
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

enum TurnResource { action, bonus, reaction, movement }

enum MapPageMode { editor, session }

const List<String> kTacticalConditions = [
  'Aveugle',
  'Entrave',
  'Empoisonne',
  'Effraye',
  'Invisible',
  'A terre',
  'Concentre',
  'Brule',
  'Etourdi',
];

class MapEditorPage extends StatefulWidget {
  final int campaignId;
  final String mapId;
  final bool isGM;
  final MapPageMode mode;

  const MapEditorPage({
    super.key,
    this.campaignId = 0,
    this.mapId = "new_map",
    this.isGM = true,
    this.mode = MapPageMode.editor,
  });

  const MapEditorPage.editor({
    super.key,
    required this.campaignId,
    this.mapId = "new_map",
  })  : isGM = true,
        mode = MapPageMode.editor;

  const MapEditorPage.session({
    super.key,
    required this.campaignId,
    required this.mapId,
    required this.isGM,
  }) : mode = MapPageMode.session;

  @override
  State<MapEditorPage> createState() => _MapEditorPageState();
}

class _MapEditorPageState extends State<MapEditorPage>
    with SingleTickerProviderStateMixin {
  final CampaignRepository _campRepo = CampaignRepository();
  final MapRepository _mapRepo = MapRepository();
  final CharacterRepositoryImpl _charRepo = CharacterRepositoryImpl();
  final RulesRepositoryImpl _rulesRepo = RulesRepositoryImpl();
  final SessionService _sessionService = SessionService();
  late final AnimationController _animController;
  final SocketService _socket = SocketService();

  MapConfig _mapConfig = const MapConfig(
    widthInCells: 20,
    heightInCells: 16,
    cellSize: 64.0,
    backgroundColor: Color(0xFFE0D8C0),
    gridColor: Color(0x4D5C4033),
  );

  static const double _mapMargin = 100.0;
  final TransformationController _transformationController =
      TransformationController();

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
  String? _currentUserId;
  String? _selectedCharId;
  String? _targetCharId;
  bool _isPickingTarget = false;
  final Map<String, Set<String>> _conditionsByToken = {};
  String? _turnResourceTokenId;
  int _turnResourceRound = 0;
  bool _actionUsed = false;
  bool _bonusUsed = false;
  bool _reactionUsed = false;
  bool _movementUsed = false;
  int _movementSpent = 0;
  Timer? _sessionTimer;
  List<CombatantModel> _combatParticipants = [];
  List<Map<String, dynamic>> _sessionLogs = [];
  bool _combatActive = false;
  bool _allowDice = true;
  bool _isSessionLoading = true;
  int _combatRound = 0;
  int _combatTurnIndex = 0;

  EditorTool _selectedTool = EditorTool.brush;
  TileType _selectedTileType = TileType.stoneFloor;
  ObjectType _selectedObjectType = ObjectType.door;

  // final bool _isPortrait = false; // (Inutilisé pour l'instant dans ce code, mais gardé si besoin)
  double get _hexRadius => _mapConfig.cellSize / HexUtils.sqrt3;
  bool get _isEditorMode => widget.mode == MapPageMode.editor;
  bool get _isSessionMode => widget.mode == MapPageMode.session;
  bool get _canEditMap => _isEditorMode && widget.isGM;
  bool get _canUseSessionFlow => _isSessionMode && widget.campaignId != 0;
  bool get _canManageSessionCombat => _canUseSessionFlow && widget.isGM;

  @override
  void initState() {
    super.initState();
    if (!_canEditMap) {
      _selectedTool = EditorTool.token;
    }
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _loadAllAssets();
    _loadCurrentUser();
    _loadMembers();
    if (_canUseSessionFlow) {
      _loadCampaignMeta();
      _refreshSessionState(showLoader: true);
      _sessionTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => _refreshSessionState(showLoader: false),
      );
    }
    if (widget.mapId != "new_map") {
      _loadMapData();
    } else {
      Log.error("🆕 Nouvelle carte détectée, pas de chargement.");
    }

    // 1. Connexion au serveur
    if (_canUseSessionFlow) {
      _setupSocket();
    }

    // 2. Écoute des mouvements (Quand un autre joueur bouge)
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculateFog());
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _socket.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _setupSocket() async {
    await _socket.init(widget.campaignId);
    if (!mounted) return;

    _socket.onTokenMoved((data) {
      if (!mounted) return;
      if (data['mapId']?.toString() != widget.mapId) return;
      setState(() {
        final point = Point<int>(data['x'], data['y']);
        _tokenPositions[data['charId']] = point;
      });
      _recalculateFog();
      _calculateMovementRange();
    });

    _socket.onMapTokensUpdated((data) {
      if (!mounted) return;
      if (data['mapId']?.toString() != widget.mapId) return;
      final rawTokens = data['tokens'];
      if (rawTokens is! Map) return;

      final nextTokens = <String, Point<int>>{};
      Map<Object?, Object?>.from(rawTokens).forEach((key, value) {
        if (value is Map) {
          final x = value['x'];
          final y = value['y'];
          if (x is int && y is int) {
            nextTokens[key.toString()] = Point<int>(x, y);
          }
        }
      });

      setState(() {
        _tokenPositions
          ..clear()
          ..addAll(nextTokens);
      });
      _recalculateFog();
      _calculateMovementRange();
    });

    _socket.onSessionLog((_) {
      if (!mounted) return;
      _loadSessionLogs(showLoader: false);
    });
  }

  Future<void> _loadAllAssets() async {
    final files = {
      'stone_floor': 'assets/images/tiles/stone_floor.png',
      'wood_floor': 'assets/images/tiles/wood_floor.png',
      'grass': 'assets/images/tiles/grass_1.png',
      'dirt': 'assets/images/tiles/_dirt_footprint_floor.png',
      'stone_wall': 'assets/images/tiles/stone_wall.png',
      // 'tree': 'assets/images/tiles/tree_1.png',
      'water': 'assets/images/tiles/water_1.png',
      'lava': 'assets/images/tiles/lava_1.png',
      //'door_closed': 'assets/images/objects/door_closed.png',
      // 'door_open': 'assets/images/objects/door_open.png',
      //'chest_closed': 'assets/images/objects/chest_closed.png',
      //'chest_open': 'assets/images/objects/chest_open.png',
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
      } catch (e) {
        debugPrint("Erreur DB: $e");
      }
    }
    if (mounted) setState(() => _members = loadedMembers);
  }

  Future<void> _loadCurrentUser() async {
    final userId = await _sessionService.getUserId();
    if (!mounted) return;
    setState(() => _currentUserId = userId);
  }

  Future<void> _loadCampaignMeta() async {
    if (!_canUseSessionFlow) return;
    final campaign = await _campRepo.getCampaign(widget.campaignId);
    if (!mounted || campaign == null) return;
    setState(() => _allowDice = campaign.allowDice);
  }

  Future<void> _refreshSessionState({bool showLoader = false}) async {
    if (!_canUseSessionFlow) return;
    if (showLoader && mounted) {
      setState(() => _isSessionLoading = true);
    }

    await Future.wait([
      _loadCombatState(showLoader: showLoader),
      _loadSessionLogs(showLoader: showLoader),
    ]);

    if (!mounted) return;
    setState(() => _isSessionLoading = false);
  }

  Future<void> _loadCombatState({bool showLoader = false}) async {
    if (!_canUseSessionFlow) return;

    final data = await _campRepo.getCombatDetails(widget.campaignId);
    if (!mounted) return;

    final active = data['active'] == true;
    final participants = active && data['participants'] is List
        ? (data['participants'] as List)
            .map((json) =>
                CombatantModel.fromJson(Map<String, dynamic>.from(json)))
            .toList()
        : <CombatantModel>[];
    final encounter = data['encounter'] as Map<String, dynamic>?;
    final round = encounter?['round'] ?? 0;
    final turnIndex = encounter?['current_turn_index'] ?? 0;

    setState(() {
      _combatActive = active;
      _combatParticipants = participants;
      _combatRound = round;
      _combatTurnIndex = turnIndex;
      _syncTurnResources(
        active: active,
        participants: participants,
        round: round,
        turnIndex: turnIndex,
      );
    });
  }

  Future<void> _loadSessionLogs({bool showLoader = false}) async {
    if (!_canUseSessionFlow) return;

    if (showLoader && mounted) {
      setState(() => _isSessionLoading = true);
    }

    final logs = await _campRepo.getLogs(widget.campaignId);
    if (!mounted) return;

    setState(() {
      _sessionLogs = logs.take(8).toList();
    });
  }

  Future<void> _startCombatFromMap() async {
    if (!_canManageSessionCombat) return;
    final success = await _campRepo.startCombat(widget.campaignId);
    if (!mounted) return;
    await _refreshSessionState(showLoader: false);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (_combatParticipants.isEmpty
                  ? "Combat lance, mais aucun participant n'a ete injecte."
                  : "Combat lance depuis la carte.")
              : "Impossible de lancer le combat.",
        ),
        backgroundColor: success ? const Color(0xFF8D6E63) : Colors.redAccent,
      ),
    );
  }

  Future<void> _nextTurnFromMap() async {
    if (!_canUseSessionFlow) return;
    final success = await _campRepo.nextTurn(widget.campaignId);
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossible de passer au tour suivant."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    await _refreshSessionState(showLoader: false);
  }

  Future<void> _stopCombatFromMap() async {
    if (!_canManageSessionCombat) return;
    final success = await _campRepo.stopCombat(widget.campaignId);
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossible de fermer le combat."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    await _refreshSessionState(showLoader: false);
  }

  Future<void> _applyHpDeltaFromMap(
      CombatantModel participant, int delta) async {
    if (!_canManageSessionCombat) return;
    final nextHp = (participant.hpCurrent + delta).clamp(0, participant.hpMax);
    final success = await _campRepo.updateParticipant(
      widget.campaignId,
      participant.id,
      {"hp_current": nextHp},
    );
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Impossible de mettre a jour ${participant.name}."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    await _refreshSessionState(showLoader: false);
  }

  CombatantModel? get _activeCombatParticipant {
    if (!_combatActive || _combatParticipants.isEmpty) return null;
    if (_combatTurnIndex < 0 ||
        _combatTurnIndex >= _combatParticipants.length) {
      return null;
    }
    return _combatParticipants[_combatTurnIndex];
  }

  String? _tokenIdForCombatant(CombatantModel participant) {
    if (participant.characterId != null) {
      final targetId = participant.characterId.toString();
      for (final member in _members) {
        if (member['char_id']?.toString() == targetId) {
          return targetId;
        }
      }
    }

    for (final member in _members) {
      if (member['char_name']?.toString() == participant.name) {
        return member['char_id']?.toString();
      }
    }

    return null;
  }

  void _focusCombatant(CombatantModel participant) {
    final tokenId = _tokenIdForCombatant(participant);
    if (tokenId == null || !_tokenPositions.containsKey(tokenId)) return;

    setState(() {
      _selectedCharId = tokenId;
      _selectedTool = EditorTool.token;
    });
    _calculateMovementRange();
  }

  CombatantModel? _combatantForTokenId(String? tokenId) {
    if (tokenId == null) return null;
    for (final participant in _combatParticipants) {
      if (_tokenIdForCombatant(participant) == tokenId) {
        return participant;
      }
    }
    return null;
  }

  Map<String, dynamic>? _memberForTokenId(String? tokenId) {
    if (tokenId == null) return null;
    for (final member in _members) {
      if (member['char_id']?.toString() == tokenId) {
        return member;
      }
    }
    return null;
  }

  bool _isCurrentUsersToken(String? tokenId) {
    final member = _memberForTokenId(tokenId);
    return member?['user_id']?.toString() == _currentUserId;
  }

  bool _canControlToken(String? tokenId) {
    if (tokenId == null) return false;
    if (!_canUseSessionFlow) return true;
    if (_canManageSessionCombat) return true;
    return _isCurrentUsersToken(tokenId);
  }

  bool _canInspectTokenDetails(String? tokenId) {
    if (tokenId == null) return false;
    if (!_canUseSessionFlow) return true;
    if (_canManageSessionCombat) return true;
    return _isCurrentUsersToken(tokenId);
  }

  void _selectTokenForControl(String tokenId) {
    if (!_canControlToken(tokenId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Tu peux cibler ce personnage, mais pas le controler.",
          ),
          duration: Duration(milliseconds: 900),
        ),
      );
      return;
    }

    setState(() {
      _selectedCharId = tokenId;
      _targetCharId = null;
      _isPickingTarget = false;
      _selectedTool = EditorTool.token;
    });
    _calculateMovementRange();
  }

  void _selectTokenAsTarget(String tokenId) {
    if (_selectedCharId == null || tokenId == _selectedCharId) return;
    setState(() {
      _targetCharId = tokenId;
      _isPickingTarget = false;
    });
  }

  List<Map<String, dynamic>> _sessionRosterMembers() {
    if (!_canUseSessionFlow) return _members;
    if (widget.isGM) return _members;
    return _members
        .where((member) => member['user_id']?.toString() == _currentUserId)
        .toList(growable: false);
  }

  Future<void> _deployMissingPartyTokens() async {
    if (!_canManageSessionCombat) return;

    final occupied =
        _tokenPositions.values.map((point) => "${point.x},${point.y}").toSet();
    final missingMembers = _members
        .where((member) =>
            !_tokenPositions.containsKey(member['char_id'].toString()))
        .toList(growable: false);

    if (missingMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tous les personnages sont deja poses.")),
      );
      return;
    }

    for (final member in missingMembers) {
      Point<int>? slot;
      for (var row = 0; row < _mapConfig.heightInCells; row++) {
        for (var col = 0; col < _mapConfig.widthInCells; col++) {
          final key = "$col,$row";
          final blocked = occupied.contains(key) ||
              _gridData[key] == TileType.stoneWall ||
              _gridData[key] == TileType.tree ||
              _gridData[key] == TileType.water ||
              _gridData[key] == TileType.lava;
          if (!blocked) {
            slot = Point<int>(col, row);
            occupied.add(key);
            break;
          }
        }
        if (slot != null) break;
      }

      if (slot == null) break;
      _tokenPositions[member['char_id'].toString()] = slot;
    }

    setState(() {});
    await _persistTokenPositions();
    if (!mounted) return;
    _recalculateFog();
    _calculateMovementRange();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Le groupe a ete deploye sur la carte.")),
    );
  }

  bool _canOpenSheetForMember(Map<String, dynamic>? member) {
    if (!_canUseSessionFlow || member == null || member['is_monster'] == true) {
      return false;
    }
    if (_canManageSessionCombat) return true;
    return member['user_id']?.toString() == _currentUserId;
  }

  String _displayNameForToken(String? tokenId) {
    if (tokenId == null) {
      return "Un aventurier";
    }

    final member = _memberForTokenId(tokenId);
    final memberName = member?['char_name']?.toString();
    if (memberName != null && memberName.trim().isNotEmpty) {
      return memberName;
    }

    final combatant = _combatantForTokenId(tokenId);
    final combatName = combatant?.name;
    if (combatName != null && combatName.trim().isNotEmpty) {
      return combatName;
    }

    return tokenId;
  }

  void _toggleTargetSelection() {
    if (!_canUseSessionFlow || _selectedCharId == null) return;
    setState(() {
      _isPickingTarget = !_isPickingTarget;
      if (_isPickingTarget) {
        _targetCharId = null;
      }
    });
  }

  void _clearTargetSelection() {
    setState(() {
      _targetCharId = null;
      _isPickingTarget = false;
    });
  }

  void _syncTurnResources({
    required bool active,
    required List<CombatantModel> participants,
    required int round,
    required int turnIndex,
  }) {
    final activeTokenId =
        active && turnIndex >= 0 && turnIndex < participants.length
            ? _tokenIdForCombatant(participants[turnIndex])
            : null;

    final turnChanged = !active ||
        activeTokenId == null ||
        activeTokenId != _turnResourceTokenId ||
        round != _turnResourceRound;

    if (!turnChanged) return;

    _turnResourceTokenId = activeTokenId;
    _turnResourceRound = round;
    _actionUsed = false;
    _bonusUsed = false;
    _reactionUsed = false;
    _movementUsed = false;
    _movementSpent = 0;
  }

  bool _isTurnResourceUsed(TurnResource resource) {
    switch (resource) {
      case TurnResource.action:
        return _actionUsed;
      case TurnResource.bonus:
        return _bonusUsed;
      case TurnResource.reaction:
        return _reactionUsed;
      case TurnResource.movement:
        return _movementSpent >= _movementRange;
    }
  }

  void _consumeTurnResource(TurnResource resource, {int amount = 1}) {
    setState(() {
      switch (resource) {
        case TurnResource.action:
          _actionUsed = true;
          break;
        case TurnResource.bonus:
          _bonusUsed = true;
          break;
        case TurnResource.reaction:
          _reactionUsed = true;
          break;
        case TurnResource.movement:
          _movementSpent = (_movementSpent + amount).clamp(0, _movementRange);
          _movementUsed = _movementSpent > 0;
          break;
      }
    });
  }

  String _turnResourceLabel(TurnResource resource) {
    final used = _isTurnResourceUsed(resource);
    switch (resource) {
      case TurnResource.action:
        return used ? 'Action consommee' : 'Action disponible';
      case TurnResource.bonus:
        return used ? 'Bonus consomme' : 'Bonus disponible';
      case TurnResource.reaction:
        return used ? 'Reaction consommee' : 'Reaction disponible';
      case TurnResource.movement:
        final remaining =
            (_movementRange - _movementSpent).clamp(0, _movementRange);
        return used
            ? "$remaining cases de mouvement restantes"
            : "$remaining cases de mouvement disponibles";
    }
  }

  List<String> _conditionsForToken(String? tokenId) {
    if (tokenId == null) return const [];
    return (_conditionsByToken[tokenId] ?? const <String>{}).toList()..sort();
  }

  Future<void> _editConditionsForSelectedToken() async {
    if (!_canManageSessionCombat || _selectedCharId == null) return;

    final initial = Set<String>.from(
        _conditionsByToken[_selectedCharId] ?? const <String>{});
    final working = Set<String>.from(initial);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFF252525),
          title: Text(
            "Statuts de ${_displayNameForToken(_selectedCharId)}",
            style: const TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kTacticalConditions.map((condition) {
                final selected = working.contains(condition);
                return FilterChip(
                  label: Text(condition),
                  selected: selected,
                  onSelected: (_) {
                    setModalState(() {
                      if (selected) {
                        working.remove(condition);
                      } else {
                        working.add(condition);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!ctx.mounted) return;
                Navigator.pop(ctx);

                setState(() {
                  if (working.isEmpty) {
                    _conditionsByToken.remove(_selectedCharId);
                  } else {
                    _conditionsByToken[_selectedCharId!] =
                        Set<String>.from(working);
                  }
                });

                if (Set<String>.from(initial).toString() ==
                    working.toString()) {
                  return;
                }

                final actor = _displayNameForToken(_selectedCharId);
                final summary = working.isEmpty
                    ? "n'a plus de statut actif"
                    : "est maintenant ${working.join(', ')}";
                await _campRepo.sendLog(
                  widget.campaignId,
                  "$actor $summary",
                  type: 'SYSTEM',
                );
                if (!mounted) return;
                await _loadSessionLogs(showLoader: false);
              },
              child: const Text("Appliquer"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logTacticalAction(
    String action, {
    bool needsTarget = false,
    bool endTurn = false,
    TurnResource? resource,
  }) async {
    if (!_canUseSessionFlow || _selectedCharId == null) return;
    if (!_canControlToken(_selectedCharId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Action refusee sur un token non controle."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (needsTarget &&
        (_targetCharId == null || _targetCharId == _selectedCharId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Choisis une cible sur la carte avant cette action."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final activeTokenId = _activeCombatParticipant == null
        ? null
        : _tokenIdForCombatant(_activeCombatParticipant!);
    if (_combatActive &&
        activeTokenId != null &&
        _selectedCharId != activeTokenId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Cette action est reservee au token actif."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_combatActive && resource != null && _isTurnResourceUsed(resource)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_turnResourceLabel(resource)),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final actor = _displayNameForToken(_selectedCharId);
    final target = _displayNameForToken(_targetCharId);
    final position =
        _selectedCharId == null ? null : _tokenPositions[_selectedCharId!];
    final where = position == null ? "" : " [${position.x},${position.y}]";
    final content =
        needsTarget ? "$actor $action $target$where" : "$actor $action$where";

    final success = await _campRepo.sendLog(
      widget.campaignId,
      content,
      type: 'SYSTEM',
    );

    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossible d'enregistrer cette action tactique."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    await _loadSessionLogs(showLoader: false);
    if (!mounted) return;

    if (_combatActive && resource != null) {
      _consumeTurnResource(resource);
    }

    if (endTurn && _combatActive) {
      await _nextTurnFromMap();
      if (!mounted) return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Action enregistree : $content"),
        backgroundColor: const Color(0xFF8D6E63),
      ),
    );
  }

  String _sessionActorName() {
    final selectedMember = _memberForTokenId(_selectedCharId);
    final selectedName = selectedMember?['char_name']?.toString();
    if (selectedName != null && selectedName.trim().isNotEmpty) {
      return selectedName;
    }

    final activeName = _activeCombatParticipant?.name;
    if (activeName != null && activeName.trim().isNotEmpty) {
      return activeName;
    }

    return _canManageSessionCombat ? "Le MJ" : "Un aventurier";
  }

  Future<void> _showMapDiceDialog() async {
    if (!_canUseSessionFlow) return;
    if (!_allowDice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Les jets de des sont desactives sur cette campagne."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final reasonController = TextEditingController();
    final resultController = TextEditingController();
    var faces = 20;
    var useInAppRoll = !_canManageSessionCombat;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF252525),
          title: Text(
            _canManageSessionCombat ? "Demander un jet" : "Repondre a un jet",
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reasonController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Action ou raison",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: faces,
                decoration: const InputDecoration(
                  labelText: "De",
                  border: OutlineInputBorder(),
                ),
                items: const [4, 6, 8, 10, 12, 20, 100]
                    .map(
                      (item) => DropdownMenuItem<int>(
                        value: item,
                        child: Text("d$item"),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() => faces = value);
                },
              ),
              if (!_canManageSessionCombat) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Lancer le de dans l'app"),
                  value: useInAppRoll,
                  onChanged: (value) =>
                      setDialogState(() => useInAppRoll = value),
                ),
                if (!useInAppRoll)
                  TextField(
                    controller: resultController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Resultat manuel",
                      border: OutlineInputBorder(),
                    ),
                  ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                if (_canManageSessionCombat) {
                  final actor = _sessionActorName();
                  final reason = reasonController.text.trim().isEmpty
                      ? "une action"
                      : reasonController.text.trim();
                  final success = await _campRepo.sendLog(
                    widget.campaignId,
                    "Demande de jet: $actor demande 1d$faces pour $reason.",
                    type: 'SYSTEM',
                  );
                  if (!mounted || !success) return;
                  await _loadSessionLogs(showLoader: false);
                  return;
                }

                await _rollDiceFromMap(
                  faces,
                  reason: reasonController.text.trim(),
                  manualResult: int.tryParse(resultController.text),
                  useInAppRoll: useInAppRoll,
                );
              },
              child: const Text("Envoyer"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSelectedCharacterSheet() async {
    if (!_canUseSessionFlow) return;
    final member = _memberForTokenId(_selectedCharId);
    final charId = member?['char_id']?.toString();
    if (charId == null || charId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ce token n'est lie a aucune fiche personnage."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSessionLoading = true);
    final results = await Future.wait([
      _charRepo.getCharacter(charId),
      _rulesRepo.loadDefaultRules(),
    ]);
    if (!mounted) return;
    setState(() => _isSessionLoading = false);

    CharacterModel? character = results[0] as dynamic;
    final rules = results[1] as dynamic;

    if (character == null && member?['char_data'] is Map) {
      final payload = Map<String, dynamic>.from(member!['char_data']);
      payload['id'] = charId;
      payload['name'] =
          member['char_name']?.toString() ?? payload['name'] ?? 'Personnage';
      character = CharacterModel.fromMap(payload);
    }

    if (character == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossible de charger la fiche de ce personnage."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CharacterSheetPage(
          character: character!,
          rules: rules,
          campaignId: widget.campaignId == 0 ? null : widget.campaignId,
        ),
      ),
    );

    await _refreshSessionState(showLoader: false);
  }

  Future<void> _rollDiceFromMap(
    int faces, {
    String? reason,
    int? manualResult,
    bool useInAppRoll = true,
  }) async {
    if (!_canUseSessionFlow) return;
    final result = useInAppRoll ? Random().nextInt(faces) + 1 : manualResult;
    if (result == null || result <= 0) return;
    final actor = _sessionActorName();
    final resultLabel = "1d$faces : $result";
    final reasonLabel = reason == null || reason.trim().isEmpty
        ? "la demande en cours"
        : reason.trim();

    final success = await _campRepo.sendLog(
      widget.campaignId,
      "$actor repond a $reasonLabel avec $resultLabel",
      type: 'DICE',
      resultValue: result,
    );

    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossible d'envoyer le jet a la campagne."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    await _loadSessionLogs(showLoader: false);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Jet enregistre : d$faces = $result"),
        backgroundColor: const Color(0xFF2E7D32),
      ),
    );
  }

  Future<void> _showSessionNoteDialog({String? actor}) async {
    if (!_canUseSessionFlow) return;
    final controller = TextEditingController();
    final title = actor == null ? "Ajouter a la chronique" : "Action de $actor";
    final hint = actor == null
        ? "Ex: La porte runique vient de ceder."
        : "Ex: attaque le garde, se replie, fouille l'autel...";

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () async {
              final content = controller.text.trim();
              if (content.isEmpty) {
                Navigator.pop(ctx);
                return;
              }

              final success = await _campRepo.sendLog(
                widget.campaignId,
                actor == null ? content : "$actor : $content",
                type: 'MSG',
              );

              if (!ctx.mounted) return;
              Navigator.pop(ctx);

              if (!mounted) return;
              if (!success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text("Impossible d'ajouter cette note a la chronique."),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }

              await _loadSessionLogs(showLoader: false);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Chronique mise a jour."),
                  backgroundColor: Color(0xFF8D6E63),
                ),
              );
            },
            child: const Text("Ajouter"),
          ),
        ],
      ),
    );
  }

  String _formatLogTitle(Map<String, dynamic> log) {
    final type = (log['type'] ?? 'MSG').toString().toUpperCase();
    final content = (log['content'] ?? '').toString();

    if (content.isNotEmpty) {
      return content;
    }

    switch (type) {
      case 'DICE':
        return "Jet de des";
      case 'SYSTEM':
        return "Evenement systeme";
      default:
        return "Entree de campagne";
    }
  }

  String _formatLogMeta(Map<String, dynamic> log) {
    final author = [
      log['username'],
      log['user_name'],
      log['author'],
      log['author_name'],
    ]
        .firstWhere(
          (value) => value != null && value.toString().trim().isNotEmpty,
          orElse: () => '',
        )
        .toString();

    final createdAtRaw = log['created_at']?.toString();
    if (createdAtRaw == null || createdAtRaw.isEmpty) {
      return author;
    }

    final createdAt = DateTime.tryParse(createdAtRaw)?.toLocal();
    if (createdAt == null) {
      return author;
    }

    final time =
        "${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}";

    if (author.isEmpty) {
      return time;
    }

    return "$author • $time";
  }

  Color _logAccent(Map<String, dynamic> log) {
    final type = (log['type'] ?? 'MSG').toString().toUpperCase();
    final resultValue = log['result_value'];

    if (type == 'DICE' && resultValue is num) {
      if (resultValue == 1) return Colors.redAccent;
      if (resultValue >= 20) return Colors.greenAccent;
      return const Color(0xFFFFD700);
    }

    if (type == 'SYSTEM') {
      return Colors.blueGrey;
    }

    return const Color(0xFF8B0000);
  }

  // --- LOGIQUE METIER ---

  void _recalculateFog() {
    if (!_fogEnabled) {
      setState(() => _visibleCells = {});
      return;
    }

    final walls = _gridData.entries
        .where((e) => e.value == TileType.stoneWall || e.value == TileType.tree)
        .map((e) => e.key)
        .toSet();
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
        maxRows: _mapConfig.heightInCells);
    setState(() {
      _visibleCells = visible;
      _exploredCells.addAll(visible);
    });
  }

  void _calculateMovementRange() {
    if (_selectedCharId == null ||
        !_tokenPositions.containsKey(_selectedCharId) ||
        !_canControlToken(_selectedCharId)) {
      setState(() => _reachableCells = {});
      return;
    }
    final startPos = _tokenPositions[_selectedCharId]!;

    final staticObstacles = _gridData.entries
        .where((e) =>
            e.value == TileType.stoneWall ||
            e.value == TileType.tree ||
            e.value == TileType.water ||
            e.value == TileType.lava)
        .map((e) => e.key)
        .toSet();

    final objectObstacles = _objects.values
        .where((obj) =>
            (obj.type == ObjectType.door && !obj.state) ||
            obj.type == ObjectType.chest)
        .map((obj) => "${obj.position.x},${obj.position.y}");

    final allObstacles = staticObstacles.union(objectObstacles.toSet());
    final availableMovement =
        _combatActive && _selectedCharId == _turnResourceTokenId
            ? (_movementRange - _movementSpent).clamp(0, _movementRange)
            : _movementRange;

    final reachable = PathfindingService.getReachableCells(
      start: startPos,
      movement: availableMovement,
      walls: allObstacles,
      maxCols: _mapConfig.widthInCells,
      maxRows: _mapConfig.heightInCells,
    );
    setState(() => _reachableCells = reachable);
  }

  Future<void> _persistTokenPositions() async {
    if (widget.mapId == "new_map") return;
    await _mapRepo.saveTokenPositions(
      widget.mapId,
      Map<String, Point<int>>.from(_tokenPositions),
    );
  }

  void _onPointerEvent(PointerEvent details) {
    if (!_canEditMap && !_canUseSessionFlow) return;
    if (_selectedTool == EditorTool.move) return;
    if (!_canEditMap &&
        _selectedTool != EditorTool.token &&
        _selectedTool != EditorTool.interact) {
      return;
    }
    final pos = details.localPosition - const Offset(_mapMargin, _mapMargin);
    final point = HexUtils.pixelToGrid(
        pos, _hexRadius, _mapConfig.widthInCells, _mapConfig.heightInCells);

    if (point.x >= 0 && point.y >= 0) {
      final key = "${point.x},${point.y}";
      bool changed = false;

      if (_selectedTool == EditorTool.brush && _canEditMap) {
        if (_gridData[key] != _selectedTileType) {
          _gridData[key] = _selectedTileType;
          if (_objects.containsKey(key)) _objects.remove(key);
          changed = true;
        }
      } else if (_selectedTool == EditorTool.eraser && _canEditMap) {
        if (_gridData.containsKey(key)) {
          _gridData.remove(key);
          changed = true;
        }
        if (_tokenPositions.containsValue(point)) {
          final id =
              _tokenPositions.entries.firstWhere((e) => e.value == point).key;
          _tokenPositions.remove(id);
          changed = true;
        }
        if (_objects.containsKey(key)) {
          _objects.remove(key);
          changed = true;
        }
      } else if (_selectedTool == EditorTool.token &&
          details is PointerDownEvent) {
        final tokenAtCell = _tokenPositions.entries
            .cast<MapEntry<String, Point<int>>?>()
            .firstWhere(
              (entry) => entry!.value == point,
              orElse: () => null,
            );

        if (tokenAtCell != null && tokenAtCell.key != _selectedCharId) {
          if (_isPickingTarget && _selectedCharId != null) {
            _selectTokenAsTarget(tokenAtCell.key);
            return;
          }

          if (_canControlToken(tokenAtCell.key)) {
            _selectTokenForControl(tokenAtCell.key);
            return;
          }

          if (_selectedCharId != null && _canControlToken(_selectedCharId)) {
            _selectTokenAsTarget(tokenAtCell.key);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    "Cible verrouillee. Controle conserve sur ton personnage."),
                duration: Duration(milliseconds: 900),
              ),
            );
            return;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text("Selection verrouillee sur les autres personnages."),
              duration: Duration(milliseconds: 900),
            ),
          );
          return;
        }

        if (_selectedCharId != null) {
          if (!_canControlToken(_selectedCharId)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Tu ne peux pas deplacer ce personnage."),
                duration: Duration(milliseconds: 800),
              ),
            );
            return;
          }
          final activeTokenId = _activeCombatParticipant != null
              ? _tokenIdForCombatant(_activeCombatParticipant!)
              : null;
          if (_combatActive &&
              activeTokenId != null &&
              _selectedCharId != activeTokenId) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Ce n'est pas le tour de ce token."),
                duration: Duration(milliseconds: 700),
              ),
            );
            return;
          }
          if (!_tokenPositions.containsKey(_selectedCharId) ||
              _reachableCells.contains(key)) {
            final previousPoint = _tokenPositions[_selectedCharId!];
            final movementCost = previousPoint == null
                ? 0
                : HexUtils.distance(previousPoint, point);
            _tokenPositions[_selectedCharId!] = point;
            changed = true;

            setState(() {
              _tokenPositions[_selectedCharId!] = point;
            });

            // 2. Envoi au serveur (pour les autres)
            _socket.sendMove(
              widget.campaignId,
              widget.mapId,
              _selectedCharId!,
              point.x,
              point.y,
            );
            if (_combatActive &&
                activeTokenId != null &&
                _selectedCharId == activeTokenId &&
                movementCost > 0) {
              _consumeTurnResource(
                TurnResource.movement,
                amount: movementCost,
              );
            }
            _persistTokenPositions();

            // 3. Sauvegarde auto (optionnel, pour persistance)
            // _save();

            changed = true;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("Trop loin ou bloqué !"),
                duration: Duration(milliseconds: 500)));
          }
        }
      } else if (_selectedTool == EditorTool.object &&
          _canEditMap &&
          details is PointerDownEvent) {
        if (!_objects.containsKey(key) &&
            _gridData[key] != TileType.stoneWall) {
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
      } else if (_selectedTool == EditorTool.interact &&
          details is PointerDownEvent) {
        if (_objects.containsKey(key)) {
          final obj = _objects[key]!;
          _objects[key] = obj.copyWith(state: !obj.state);
          changed = true;
        }
      } else if (_selectedTool == EditorTool.rotate &&
          _canEditMap &&
          details is PointerDownEvent) {
        bool changedHere = false;

        if (_objects.containsKey(key)) {
          final obj = _objects[key]!;
          final newRot = (obj.rotation + 1) % 8; // 8 directions
          _objects[key] = obj.copyWith(rotation: newRot);
          changedHere = true;
        } else if (_gridData.containsKey(key)) {
          final currentRot = _tileRotations[key] ?? 0;
          final newRot = (currentRot + 1) % 6; // 6 directions
          _tileRotations[key] = newRot;
          changedHere = true;
        }

        if (changedHere) {
          changed = true;
          setState(() {});
        }
      } else if (_selectedTool == EditorTool.fill &&
          _canEditMap &&
          details is PointerDownEvent) {
        _floodFill(point, _selectedTileType);
        changed = true;
      }

      if (changed) {
        setState(() {});
        _recalculateFog();
        _calculateMovementRange();
        if (_selectedTool == EditorTool.token ||
            _selectedTool == EditorTool.eraser) {
          _persistTokenPositions();
        }
      }
    }
  }

  // --- PARAMÈTRES ---
  void _openMapSettings() {
    if (!_canEditMap) return;
    final widthController =
        TextEditingController(text: _mapConfig.widthInCells.toString());
    final heightController =
        TextEditingController(text: _mapConfig.heightInCells.toString());
    final visionController =
        TextEditingController(text: _visionRange.toString());
    final movementController =
        TextEditingController(text: _movementRange.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Paramètres de la Carte"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Dimensions",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.blueAccent)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: widthController,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: "Largeur"))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextField(
                          controller: heightController,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: "Hauteur"))),
                ],
              ),
              const SizedBox(height: 20),
              const Text("Règles de Jeu",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.greenAccent)),
              const SizedBox(height: 8),
              TextField(
                  controller: visionController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Distance de Vue",
                    prefixIcon: Icon(Icons.visibility),
                  )),
              const SizedBox(height: 8),
              TextField(
                  controller: movementController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Distance de Déplacement",
                    prefixIcon: Icon(Icons.directions_run),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Annuler")),
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
                    gridColor: _mapConfig.gridColor);
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
    if (!_canEditMap) return;
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
        if (neighbor.x < 0 ||
            neighbor.x >= _mapConfig.widthInCells ||
            neighbor.y < 0 ||
            neighbor.y >= _mapConfig.heightInCells) {
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

  IconData _toolIcon(EditorTool tool) {
    switch (tool) {
      case EditorTool.move:
        return Icons.open_with;
      case EditorTool.token:
        return Icons.place;
      case EditorTool.interact:
        return Icons.touch_app;
      case EditorTool.brush:
        return Icons.brush;
      case EditorTool.eraser:
        return Icons.auto_fix_off;
      case EditorTool.object:
        return Icons.category;
      case EditorTool.rotate:
        return Icons.rotate_right;
      case EditorTool.fill:
        return Icons.format_color_fill;
    }
  }

  String _toolLabel(EditorTool tool) {
    switch (tool) {
      case EditorTool.move:
        return "Navigation";
      case EditorTool.token:
        return "Tokens";
      case EditorTool.interact:
        return "Interaction";
      case EditorTool.brush:
        return "Peindre";
      case EditorTool.eraser:
        return "Effacer";
      case EditorTool.object:
        return "Objets";
      case EditorTool.rotate:
        return "Rotation";
      case EditorTool.fill:
        return "Remplissage";
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditorMode && !widget.isGM) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Editeur de carte"),
          backgroundColor: const Color(0xFF1a1a1a),
        ),
        backgroundColor: const Color(0xFF121212),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              "Acces refuse. L'editeur de carte est reserve au MJ.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
    }

    final w = ((_mapConfig.widthInCells + 0.5) * HexUtils.width(_hexRadius)) +
        (_mapMargin * 2);
    final h = ((_mapConfig.heightInCells * 0.75 * HexUtils.height(_hexRadius)) +
            HexUtils.height(_hexRadius)) +
        (_mapMargin * 2);
    final canInteract = _selectedTool == EditorTool.move;
    final activeCombatant = _activeCombatParticipant;
    final activeTokenId =
        activeCombatant != null ? _tokenIdForCombatant(activeCombatant) : null;
    final selectedMember = _memberForTokenId(_selectedCharId);
    final selectedCombatant = _combatantForTokenId(_selectedCharId);
    final selectedCanControl = _canControlToken(_selectedCharId);
    final selectedCanInspect = _canInspectTokenDetails(_selectedCharId);
    final selectedPoint =
        _selectedCharId == null ? null : _tokenPositions[_selectedCharId!];
    final selectedCellKey =
        selectedPoint == null ? null : "${selectedPoint.x},${selectedPoint.y}";
    final selectedVisibility = selectedCellKey == null
        ? "Position inconnue"
        : _visibleCells.contains(selectedCellKey)
            ? "Visible par le groupe"
            : _exploredCells.contains(selectedCellKey)
                ? "Dans une zone exploree"
                : "Hors de vue";
    final selectedReachability = _selectedCharId == null
        ? "Aucun deplacement calcule"
        : !selectedCanControl
            ? "Controle reserve au proprietaire"
            : _combatActive && _selectedCharId != activeTokenId
                ? "Deplacement verrouille hors de son tour"
                : "${_reachableCells.length} cases atteignables";
    final selectedOwner = [
      selectedMember?['username']?.toString(),
      selectedMember?['role']?.toString(),
      if (selectedMember?['is_monster'] == true) "Monstre",
      if (selectedMember == null && selectedCombatant?.isNpc == true)
        "Entite MJ",
    ].where((value) => value != null && value.trim().isNotEmpty).join(" • ");
    final selectedHpRatio = !selectedCanInspect ||
            selectedCombatant == null ||
            selectedCombatant.hpMax <= 0
        ? null
        : selectedCombatant.hpCurrent / selectedCombatant.hpMax;
    final selectedHealthState = selectedHpRatio == null
        ? "Etat inconnu"
        : selectedHpRatio <= 0
            ? "Hors de combat"
            : selectedHpRatio <= 0.25
                ? "Critique"
                : selectedHpRatio <= 0.6
                    ? "Sous pression"
                    : "Stable";
    final selectedTempo = !_combatActive
        ? "Exploration libre"
        : !selectedCanControl
            ? "Observation / ciblage uniquement"
            : _selectedCharId == activeTokenId
                ? "Peut agir maintenant"
                : "En attente de son tour";
    final selectedConditions = selectedCanInspect
        ? _conditionsForToken(_selectedCharId)
        : const <String>[];
    final isSelectedActiveTurn = _combatActive &&
        _selectedCharId != null &&
        _selectedCharId == activeTokenId;
    final actionStateLabel = !_combatActive
        ? "Action libre"
        : isSelectedActiveTurn
            ? _turnResourceLabel(TurnResource.action)
            : "Action hors tour";
    final bonusStateLabel = !_combatActive
        ? "Bonus libre"
        : isSelectedActiveTurn
            ? _turnResourceLabel(TurnResource.bonus)
            : "Bonus hors tour";
    final reactionStateLabel = !_combatActive
        ? "Reaction libre"
        : isSelectedActiveTurn
            ? _turnResourceLabel(TurnResource.reaction)
            : "Reaction hors tour";
    final movementStateLabel = !_combatActive
        ? "Mouvement libre"
        : isSelectedActiveTurn
            ? _turnResourceLabel(TurnResource.movement)
            : "Mouvement hors tour";
    final targetLabel = _targetCharId == null
        ? (_isPickingTarget ? "Choisis une cible sur la carte" : "Aucune cible")
        : _displayNameForToken(_targetCharId);
    final highlightedTokenIds = <String>{
      if (_selectedCharId != null) _selectedCharId!,
      if (activeTokenId != null) activeTokenId,
      if (_targetCharId != null) _targetCharId!,
    };

    final tokenDetails = {
      for (var m in _members)
        m['char_id'].toString(): {
          'name': m['char_name'],
          'color': Colors.primaries[
              m['char_id'].toString().hashCode % Colors.primaries.length]
        }
    };
    final sessionRosterMembers = _sessionRosterMembers();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditorMode ? "Editeur de carte" : "Session map"),
        backgroundColor: const Color(0xFF1a1a1a),
        actions: [
          BugReportActionButton(
            sourcePage: _isEditorMode ? "map_editor" : "session_runtime",
            campaignId: widget.campaignId == 0 ? null : widget.campaignId,
            mapId: widget.mapId,
            characterId: _selectedCharId,
            extraContext: {
              'mode': _isEditorMode ? 'editor' : 'session',
              'combat_active': _combatActive,
              'selected_tool': _selectedTool.name,
            },
          ),
          if (_isSessionMode)
            PopupMenuButton<EditorTool>(
              tooltip: "Outil de session: ${_toolLabel(_selectedTool)}",
              initialValue: _selectedTool,
              onSelected: (tool) {
                setState(() {
                  _selectedTool = tool;
                  if (tool != EditorTool.token) {
                    _reachableCells = {};
                    _isPickingTarget = false;
                  } else {
                    _calculateMovementRange();
                  }
                });
              },
              itemBuilder: (context) => [
                EditorTool.move,
                EditorTool.token,
                EditorTool.interact,
              ]
                  .map(
                    (tool) => PopupMenuItem<EditorTool>(
                      value: tool,
                      child: Row(
                        children: [
                          Icon(_toolIcon(tool), size: 18),
                          const SizedBox(width: 8),
                          Text(_toolLabel(tool)),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
              icon: Icon(_toolIcon(_selectedTool)),
            ),
          if (!_canUseSessionFlow || widget.isGM)
            IconButton(
              tooltip: _fogEnabled
                  ? "Masquer le brouillard"
                  : "Afficher le brouillard",
              icon: Icon(_fogEnabled ? Icons.visibility_off : Icons.visibility),
              onPressed: () {
                setState(() => _fogEnabled = !_fogEnabled);
                _recalculateFog();
              },
            ),
          if (_canEditMap)
            IconButton(
              tooltip: "Parametres de la carte",
              icon: const Icon(Icons.settings),
              onPressed: _openMapSettings,
            ),
          if (_canEditMap)
            IconButton(
              tooltip: "Sauvegarder la carte",
              icon: const Icon(Icons.save, color: Colors.blueAccent),
              onPressed: _save,
            ),
        ],
      ),
      backgroundColor: const Color(0xFF121212),
      body: Row(
        children: [
          if (_canEditMap)
            EditorPalette(
              selectedTool: _selectedTool,
              selectedTileType: _selectedTileType,
              selectedObjectType: _selectedObjectType,
              onToolChanged: (t) {
                setState(() => _selectedTool = t);
                if (t != EditorTool.token) setState(() => _reachableCells = {});
              },
              onTileTypeChanged: (t) => setState(() => _selectedTileType = t),
              onObjectTypeChanged: (o) =>
                  setState(() => _selectedObjectType = o),
              isPortrait: false,
            ),
          Expanded(
            child: Container(
              color: Colors.black,
              child: LayoutBuilder(builder: (context, constraints) {
                return Stack(
                  children: [
                    DragTarget<Map<String, dynamic>>(
                      onAcceptWithDetails: (details) {
                        final renderBox =
                            context.findRenderObject() as RenderBox;
                        final localPos =
                            renderBox.globalToLocal(details.offset);
                        final matrix = _transformationController.value;
                        final inverseMatrix = Matrix4.inverted(matrix);
                        final transformedPos =
                            MatrixUtils.transformPoint(inverseMatrix, localPos);
                        final mapPos = transformedPos -
                            const Offset(_mapMargin, _mapMargin);
                        final point = HexUtils.pixelToGrid(mapPos, _hexRadius,
                            _mapConfig.widthInCells, _mapConfig.heightInCells);

                        if (point.x >= 0 && point.y >= 0) {
                          final monsterData = details.data;
                          final uniqueId =
                              "${monsterData['id']}_${DateTime.now().millisecondsSinceEpoch}";

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
                          _persistTokenPositions();
                        }
                      },
                      builder: (context, candidateData, rejectedData) {
                        return InteractiveViewer(
                          transformationController: _transformationController,
                          boundaryMargin: const EdgeInsets.all(double.infinity),
                          minScale: 0.1,
                          maxScale: 5.0,
                          constrained: false,
                          panEnabled: canInteract,
                          scaleEnabled: canInteract,
                          child: Listener(
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: _onPointerEvent,
                            onPointerMove: _onPointerEvent,
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
                              totalWidth: w,
                              totalHeight: h,
                              tileRotations: _tileRotations,
                              animation: _animController,
                              activeTokenId: activeTokenId,
                              targetTokenId: _targetCharId,
                              highlightedTokenIds: highlightedTokenIds,
                            ),
                          ),
                        );
                      },
                    ),
                    if (_canUseSessionFlow)
                      Positioned(
                        top: 16,
                        right: 16,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth < 500
                                ? constraints.maxWidth - 32
                                : 340,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _MapSessionPanel(
                                isGM: _canManageSessionCombat,
                                combatActive: _combatActive,
                                combatRound: _combatRound,
                                membersCount: _members.length,
                                combatParticipants: _combatParticipants,
                                activeCombatant: activeCombatant,
                                onStartCombat: _startCombatFromMap,
                                onNextTurn: _nextTurnFromMap,
                                onStopCombat: _stopCombatFromMap,
                                onFocusCombatant: _focusCombatant,
                                onDamageCombatant: (participant) =>
                                    _applyHpDeltaFromMap(participant, -1),
                                onHealCombatant: (participant) =>
                                    _applyHpDeltaFromMap(participant, 1),
                                onDeployParty: _deployMissingPartyTokens,
                              ),
                              const SizedBox(height: 12),
                              _MapChroniclePanel(
                                logs: _sessionLogs,
                                isLoading: _isSessionLoading,
                                allowDice: _allowDice,
                                onRollDice: _showMapDiceDialog,
                                onAddNote: _showSessionNoteDialog,
                                onRefresh: () =>
                                    _refreshSessionState(showLoader: false),
                                formatTitle: _formatLogTitle,
                                formatMeta: _formatLogMeta,
                                accentFor: _logAccent,
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_canUseSessionFlow && _selectedCharId != null)
                      Positioned(
                        left: 16,
                        bottom: 16,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth < 500
                                ? constraints.maxWidth - 32
                                : 320,
                          ),
                          child: _SelectedTokenPanel(
                            tokenId: _selectedCharId!,
                            member: selectedMember,
                            combatant: selectedCombatant,
                            isActiveTurn: _selectedCharId == activeTokenId,
                            position: selectedPoint,
                            visibilityLabel: selectedVisibility,
                            reachabilityLabel: selectedReachability,
                            ownerLabel: selectedOwner,
                            healthStateLabel: selectedHealthState,
                            tempoLabel: selectedTempo,
                            conditionLabels: selectedConditions,
                            actionStateLabel: actionStateLabel,
                            bonusStateLabel: bonusStateLabel,
                            reactionStateLabel: reactionStateLabel,
                            movementStateLabel: movementStateLabel,
                            actionUsed: isSelectedActiveTurn && _actionUsed,
                            bonusUsed: isSelectedActiveTurn && _bonusUsed,
                            reactionUsed: isSelectedActiveTurn && _reactionUsed,
                            movementUsed: isSelectedActiveTurn && _movementUsed,
                            targetLabel: targetLabel,
                            targetIsLocked: _targetCharId != null,
                            isPickingTarget: _isPickingTarget,
                            isGM: _canManageSessionCombat,
                            onAnnounce: selectedCanControl
                                ? () => _showSessionNoteDialog(
                                      actor: selectedMember?['char_name']
                                              ?.toString() ??
                                          selectedCombatant?.name,
                                    )
                                : null,
                            onRollDice: selectedCanControl
                                ? () => _rollDiceFromMap(20)
                                : null,
                            onOpenSheet: _canOpenSheetForMember(selectedMember)
                                ? _openSelectedCharacterSheet
                                : null,
                            onPickTarget: selectedCanControl
                                ? _toggleTargetSelection
                                : null,
                            onClearTarget: _targetCharId == null
                                ? null
                                : _clearTargetSelection,
                            onEditConditions: _canManageSessionCombat
                                ? _editConditionsForSelectedToken
                                : null,
                            onAttack: selectedCanControl
                                ? () => _logTacticalAction(
                                      "attaque",
                                      needsTarget: true,
                                      resource: TurnResource.action,
                                    )
                                : null,
                            onSpell: selectedCanControl
                                ? () => _logTacticalAction(
                                      "lance un sort sur",
                                      needsTarget: true,
                                      resource: TurnResource.action,
                                    )
                                : null,
                            onHelp: selectedCanControl
                                ? () => _logTacticalAction(
                                      "aide",
                                      needsTarget: true,
                                      resource: TurnResource.action,
                                    )
                                : null,
                            onDodge: selectedCanControl
                                ? () => _logTacticalAction(
                                      "se met en defense",
                                      resource: TurnResource.action,
                                    )
                                : null,
                            onMoveAction: selectedCanControl
                                ? () => _logTacticalAction(
                                      "se repositionne",
                                      resource: TurnResource.movement,
                                    )
                                : null,
                            onBonusAction: selectedCanControl
                                ? () => _logTacticalAction(
                                      "utilise son action bonus",
                                      resource: TurnResource.bonus,
                                    )
                                : null,
                            onReaction: selectedCanControl
                                ? () => _logTacticalAction(
                                      "declenche sa reaction",
                                      resource: TurnResource.reaction,
                                    )
                                : null,
                            onEndTurn: !selectedCanControl ||
                                    !_combatActive ||
                                    _selectedCharId != activeTokenId
                                ? null
                                : () => _logTacticalAction("termine son tour",
                                    endTurn: true),
                            onDamage: selectedCombatant == null
                                ? null
                                : () =>
                                    _applyHpDeltaFromMap(selectedCombatant, -1),
                            onHeal: selectedCombatant == null
                                ? null
                                : () =>
                                    _applyHpDeltaFromMap(selectedCombatant, 1),
                          ),
                        ),
                      ),
                  ],
                );
              }),
            ),
          ),
          if ((_canEditMap || _canUseSessionFlow) &&
              _selectedTool == EditorTool.token)
            Container(
              width: 60,
              color: const Color(0xFF1a1a1a),
              child: ListView.builder(
                itemCount:
                    (_canUseSessionFlow ? sessionRosterMembers : _members)
                        .length,
                itemBuilder: (ctx, i) {
                  final m = _canUseSessionFlow
                      ? sessionRosterMembers[i]
                      : _members[i];
                  final id = m['char_id'].toString();
                  return GestureDetector(
                    onTap: () {
                      if (_canUseSessionFlow) {
                        _selectTokenForControl(id);
                        return;
                      }
                      setState(() {
                        _selectedCharId = id;
                        _targetCharId = null;
                        _isPickingTarget = false;
                        _calculateMovementRange();
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: _selectedCharId == id
                              ? Border.all(color: Colors.greenAccent, width: 2)
                              : null),
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
    if (!mounted) return;

    if (mapData != null) {
      setState(() {
        // 1. On applique la config (taille, couleurs)
        _mapConfig = mapData.config;

        // 2. On vide et remplit la grille
        _gridData.clear();
        _gridData.addAll(mapData.gridData);

        // 3. On vide et remplit les objets
        _objects.clear();
        _objects.addAll(mapData.objects);

        _tokenPositions
          ..clear()
          ..addAll(mapData.tokenPositions);
      });

      // 4. On recalcule le brouillard avec les nouveaux murs
      _recalculateFog();

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Carte chargée ! (${_gridData.length} éléments)"),
          backgroundColor: Colors.green));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Impossible de charger la carte ❌"),
          backgroundColor: Colors.red));
    }
  }

  // --- SAUVEGARDE ---
  void _save() async {
    if (!_canEditMap) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Sauvegarde... ⏳"), duration: Duration(seconds: 1)));

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
            heightInCells: _mapConfig.heightInCells,
          ));

      if (!mounted) return;
      if (newId != null) {
        currentMapId = newId.toString();
        // Optionnel : Mettre à jour l'état pour que les prochaines sauvegardes soient des updates
        // setState(() { widget.mapId = currentMapId; }); // Attention widget.mapId est final, idéalement on recharge la page ou on utilise une variable d'état locale
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Erreur lors de la création de la carte ❌"),
            backgroundColor: Colors.red));
        return;
      }
    }

    // 2. SAUVEGARDE DES DONNÉES (Maintenant qu'on a un vrai ID)
    final mapToSave = MapDataModel(
        id: currentMapId, // On utilise l'ID corrigé (ex: "42")
        name: "Ma Carte Hex",
        config: _mapConfig,
        gridData: _gridData,
        objects: _objects);

    bool success = await _mapRepo.saveMapData(mapToSave);

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Carte sauvegardée ! 💾"),
          backgroundColor: Colors.green));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Erreur de sauvegarde ❌"),
          backgroundColor: Colors.red));
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
  final Set<String> highlightedTokenIds;
  final bool fogEnabled;
  final double hexRadius;
  final double mapMargin;
  final double totalWidth;
  final double totalHeight;
  final Animation<double> animation;
  final String? activeTokenId;
  final String? targetTokenId;

  const MapCanvasWidget({
    super.key,
    required this.mapConfig,
    required this.assets,
    required this.gridData,
    required this.tokenPositions,
    required this.objects,
    required this.tokenDetails,
    required this.visibleCells,
    required this.exploredCells,
    required this.reachableCells,
    required this.fogEnabled,
    required this.tileRotations,
    required this.highlightedTokenIds,
    required this.activeTokenId,
    required this.targetTokenId,
    required this.hexRadius,
    required this.mapMargin,
    required this.totalWidth,
    required this.totalHeight,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final offset = Offset(mapMargin, mapMargin);
    return Container(
      width: totalWidth,
      height: totalHeight,
      decoration: const BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20)]),
      child: Stack(
        children: [
          // 1. Fond
          Positioned.fill(
              child: CustomPaint(
                  painter: BackgroundPatternPainter(
                      backgroundColor: mapConfig.backgroundColor,
                      patternImage: assets['parchment']))),

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
                        ));
                  }),
            ),
          ),

          // 3. Objets
          RepaintBoundary(
              child: CustomPaint(
                  size: Size(totalWidth, totalHeight),
                  painter: ObjectPainter(
                      config: mapConfig,
                      objects: objects,
                      assets: assets,
                      radius: hexRadius,
                      offset: offset))),

          // 4. Grille
          IgnorePointer(
              child: CustomPaint(
                  size: Size(totalWidth, totalHeight),
                  painter: GridPainter(
                      config: mapConfig, radius: hexRadius, offset: offset))),

          // 5. Zone de mouvement
          RepaintBoundary(
              child: CustomPaint(
                  size: Size(totalWidth, totalHeight),
                  painter: MovementPainter(
                      config: mapConfig,
                      reachableCells: fogEnabled
                          ? reachableCells.intersection(visibleCells)
                          : reachableCells,
                      radius: hexRadius,
                      offset: offset))),

          // 6. Tokens
          RepaintBoundary(
              child: CustomPaint(
                  size: Size(totalWidth, totalHeight),
                  painter: TokenPainter(
                    config: mapConfig,
                    tokenPositions: tokenPositions,
                    tokenDetails: tokenDetails,
                    radius: hexRadius,
                    offset: offset,
                    highlightedTokenIds: highlightedTokenIds,
                    activeTokenId: activeTokenId,
                    targetTokenId: targetTokenId,
                  ))),

          // 7. Brouillard
          if (fogEnabled)
            IgnorePointer(
                child: CustomPaint(
                    size: Size(totalWidth, totalHeight),
                    painter: FogPainter(
                        config: mapConfig,
                        visibleCells: visibleCells,
                        exploredCells: exploredCells,
                        radius: hexRadius,
                        offset: offset))),

          // 8. Lumières Dynamiques (Par dessus le brouillard pour l'effet Glow)
          RepaintBoundary(
              child: CustomPaint(
                  size: Size(totalWidth, totalHeight),
                  painter: LightingPainter(
                      objects: objects, radius: hexRadius, offset: offset))),
        ],
      ),
    );
  }
}

class _MapSessionPanel extends StatelessWidget {
  final bool isGM;
  final bool combatActive;
  final int combatRound;
  final int membersCount;
  final List<CombatantModel> combatParticipants;
  final CombatantModel? activeCombatant;
  final VoidCallback onStartCombat;
  final VoidCallback onNextTurn;
  final VoidCallback onStopCombat;
  final ValueChanged<CombatantModel> onFocusCombatant;
  final ValueChanged<CombatantModel> onDamageCombatant;
  final ValueChanged<CombatantModel> onHealCombatant;
  final VoidCallback onDeployParty;

  const _MapSessionPanel({
    required this.isGM,
    required this.combatActive,
    required this.combatRound,
    required this.membersCount,
    required this.combatParticipants,
    required this.activeCombatant,
    required this.onStartCombat,
    required this.onNextTurn,
    required this.onStopCombat,
    required this.onFocusCombatant,
    required this.onDamageCombatant,
    required this.onHealCombatant,
    required this.onDeployParty,
  });

  @override
  Widget build(BuildContext context) {
    final title = combatActive
        ? (combatParticipants.isEmpty ? "Combat vide" : "Round $combatRound")
        : "Exploration";

    return Card(
      color: const Color(0xE61B1B1B),
      elevation: 12,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  combatActive ? Icons.sports_kabaddi : Icons.explore,
                  color: combatActive
                      ? const Color(0xFFFFD700)
                      : const Color(0xFF6D9DC5),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              combatActive
                  ? (combatParticipants.isEmpty
                      ? "Le combat est actif, mais aucun participant n'est visible."
                      : "${combatParticipants.length} participants sur la carte de session.")
                  : "$membersCount membres relies a cette campagne.",
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            if (!combatActive && isGM)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: onStartCombat,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text("Lancer l'initiative"),
                  ),
                  OutlinedButton.icon(
                    onPressed: onDeployParty,
                    icon: const Icon(Icons.group_add),
                    label: const Text("Poser le groupe"),
                  ),
                ],
              ),
            if (combatActive && activeCombatant != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF252525),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x30FFD700)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Tour actif",
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activeCombatant!.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "PV ${activeCombatant!.hpCurrent}/${activeCombatant!.hpMax} • Init ${activeCombatant!.initiative}",
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => onFocusCombatant(activeCombatant!),
                          child: const Text("Centrer"),
                        ),
                        if (isGM)
                          OutlinedButton(
                            onPressed: () =>
                                onDamageCombatant(activeCombatant!),
                            child: const Text("-1 PV"),
                          ),
                        if (isGM)
                          OutlinedButton(
                            onPressed: () => onHealCombatant(activeCombatant!),
                            child: const Text("+1 PV"),
                          ),
                        if (isGM)
                          ElevatedButton(
                            onPressed: onNextTurn,
                            child: const Text("Tour suivant"),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (combatParticipants.isNotEmpty) ...[
              const Text(
                "Ordre d'initiative",
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: combatParticipants.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white10, height: 8),
                  itemBuilder: (context, index) {
                    final participant = combatParticipants[index];
                    final isActiveTurn =
                        identical(participant, activeCombatant);
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: participant.isNpc
                            ? Colors.red[800]
                            : const Color(0xFF6D9DC5),
                        child: Text(
                          participant.initiative.toString(),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ),
                      title: Text(
                        participant.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight:
                              isActiveTurn ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        "PV ${participant.hpCurrent}/${participant.hpMax}",
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                      ),
                      trailing: IconButton(
                        tooltip: "Centrer sur ${participant.name}",
                        icon: Icon(
                          Icons.my_location,
                          color: isActiveTurn
                              ? const Color(0xFFFFD700)
                              : Colors.white38,
                        ),
                        onPressed: () => onFocusCombatant(participant),
                      ),
                    );
                  },
                ),
              ),
            ],
            if (combatActive && isGM) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onStopCombat,
                  icon: const Icon(Icons.stop_circle_outlined,
                      color: Colors.redAccent),
                  label: const Text(
                    "Clore le combat",
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MapChroniclePanel extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  final bool isLoading;
  final bool allowDice;
  final VoidCallback onRollDice;
  final VoidCallback onAddNote;
  final VoidCallback onRefresh;
  final String Function(Map<String, dynamic>) formatTitle;
  final String Function(Map<String, dynamic>) formatMeta;
  final Color Function(Map<String, dynamic>) accentFor;

  const _MapChroniclePanel({
    required this.logs,
    required this.isLoading,
    required this.allowDice,
    required this.onRollDice,
    required this.onAddNote,
    required this.onRefresh,
    required this.formatTitle,
    required this.formatMeta,
    required this.accentFor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xE61B1B1B),
      elevation: 12,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_stories, color: Color(0xFFFFD700)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Chronique live",
                    style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: "Rafraichir",
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              "Des et evenements partages de la session, sans quitter la carte.",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: allowDice ? onRollDice : null,
                  icon: const Icon(Icons.casino),
                  label: Text(allowDice ? "Lancer un de" : "Des verrouilles"),
                ),
                OutlinedButton.icon(
                  onPressed: onAddNote,
                  icon: const Icon(Icons.edit_note),
                  label: const Text("Ajouter une note"),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260, minHeight: 140),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF151515),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : logs.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              "Aucun evenement partage pour le moment.",
                              style: TextStyle(color: Colors.white54),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            shrinkWrap: true,
                            itemCount: logs.length,
                            separatorBuilder: (_, __) => const Divider(
                                color: Colors.white10, height: 12),
                            itemBuilder: (context, index) {
                              final log = logs[index];
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    margin: const EdgeInsets.only(top: 6),
                                    decoration: BoxDecoration(
                                      color: accentFor(log),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          formatTitle(log),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          formatMeta(log),
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedTokenPanel extends StatelessWidget {
  final String tokenId;
  final Map<String, dynamic>? member;
  final CombatantModel? combatant;
  final bool isActiveTurn;
  final Point<int>? position;
  final String visibilityLabel;
  final String reachabilityLabel;
  final String ownerLabel;
  final String healthStateLabel;
  final String tempoLabel;
  final List<String> conditionLabels;
  final String actionStateLabel;
  final String bonusStateLabel;
  final String reactionStateLabel;
  final String movementStateLabel;
  final bool actionUsed;
  final bool bonusUsed;
  final bool reactionUsed;
  final bool movementUsed;
  final String targetLabel;
  final bool targetIsLocked;
  final bool isPickingTarget;
  final bool isGM;
  final VoidCallback? onAnnounce;
  final VoidCallback? onRollDice;
  final VoidCallback? onOpenSheet;
  final VoidCallback? onPickTarget;
  final VoidCallback? onClearTarget;
  final VoidCallback? onEditConditions;
  final VoidCallback? onAttack;
  final VoidCallback? onSpell;
  final VoidCallback? onHelp;
  final VoidCallback? onDodge;
  final VoidCallback? onMoveAction;
  final VoidCallback? onBonusAction;
  final VoidCallback? onReaction;
  final VoidCallback? onEndTurn;
  final VoidCallback? onDamage;
  final VoidCallback? onHeal;

  const _SelectedTokenPanel({
    required this.tokenId,
    required this.member,
    required this.combatant,
    required this.isActiveTurn,
    required this.position,
    required this.visibilityLabel,
    required this.reachabilityLabel,
    required this.ownerLabel,
    required this.healthStateLabel,
    required this.tempoLabel,
    required this.conditionLabels,
    required this.actionStateLabel,
    required this.bonusStateLabel,
    required this.reactionStateLabel,
    required this.movementStateLabel,
    required this.actionUsed,
    required this.bonusUsed,
    required this.reactionUsed,
    required this.movementUsed,
    required this.targetLabel,
    required this.targetIsLocked,
    required this.isPickingTarget,
    required this.isGM,
    required this.onAnnounce,
    required this.onRollDice,
    required this.onOpenSheet,
    required this.onPickTarget,
    required this.onClearTarget,
    required this.onEditConditions,
    required this.onAttack,
    required this.onSpell,
    required this.onHelp,
    required this.onDodge,
    required this.onMoveAction,
    required this.onBonusAction,
    required this.onReaction,
    required this.onEndTurn,
    required this.onDamage,
    required this.onHeal,
  });

  @override
  Widget build(BuildContext context) {
    final displayName =
        member?['char_name']?.toString() ?? combatant?.name ?? tokenId;
    final subtitle = combatant != null
        ? "PV ${combatant!.hpCurrent}/${combatant!.hpMax} • CA ${combatant!.ac} • Init ${combatant!.initiative}"
        : "Token selectionne sur la carte";
    final positionLabel = position == null
        ? "Position inconnue"
        : "Hex ${position!.x}, ${position!.y}";

    return Card(
      color: const Color(0xE61B1B1B),
      elevation: 12,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: isActiveTurn
                      ? const Color(0xFFFFD700)
                      : const Color(0xFF6D9DC5),
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : "?",
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Token selectionne",
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      Text(
                        displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActiveTurn)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Text(
                      "Tour actif",
                      style: TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF151515),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoLine(
                    icon: Icons.place_outlined,
                    label: positionLabel,
                  ),
                  const SizedBox(height: 6),
                  _InfoLine(
                    icon: Icons.visibility_outlined,
                    label: visibilityLabel,
                  ),
                  const SizedBox(height: 6),
                  _InfoLine(
                    icon: Icons.directions_run,
                    label: reachabilityLabel,
                  ),
                  const SizedBox(height: 6),
                  _InfoLine(
                    icon: Icons.favorite_outline,
                    label: healthStateLabel,
                  ),
                  const SizedBox(height: 6),
                  _InfoLine(
                    icon: Icons.schedule,
                    label: tempoLabel,
                  ),
                  const SizedBox(height: 6),
                  _InfoLine(
                    icon:
                        isPickingTarget ? Icons.gps_fixed : Icons.track_changes,
                    label: targetLabel,
                  ),
                  if (ownerLabel.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _InfoLine(
                      icon: Icons.badge_outlined,
                      label: ownerLabel,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text(
                  "Statuts tactiques",
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onEditConditions,
                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                  label: const Text("Editer"),
                ),
              ],
            ),
            if (conditionLabels.isEmpty)
              const Text(
                "Aucun statut actif.",
                style: TextStyle(color: Colors.white54),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: conditionLabels
                    .map(
                      (condition) => Chip(
                        label: Text(condition),
                        backgroundColor: const Color(0xFF3A2619),
                        side: BorderSide.none,
                        labelStyle: const TextStyle(color: Color(0xFFFFD700)),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 10),
            const Text(
              "Ressources du tour",
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ResourceChip(label: actionStateLabel, used: actionUsed),
                _ResourceChip(label: bonusStateLabel, used: bonusUsed),
                _ResourceChip(label: reactionStateLabel, used: reactionUsed),
                _ResourceChip(label: movementStateLabel, used: movementUsed),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onOpenSheet != null)
                  ElevatedButton.icon(
                    onPressed: onOpenSheet,
                    icon: const Icon(Icons.badge_outlined),
                    label: const Text("Fiche"),
                  ),
                ElevatedButton.icon(
                  onPressed: onRollDice,
                  icon: const Icon(Icons.casino),
                  label: const Text("d20"),
                ),
                OutlinedButton.icon(
                  onPressed: onAnnounce,
                  icon: const Icon(Icons.record_voice_over_outlined),
                  label: const Text("Annoncer"),
                ),
                OutlinedButton.icon(
                  onPressed: onPickTarget,
                  icon: Icon(isPickingTarget
                      ? Icons.cancel_outlined
                      : Icons.track_changes),
                  label: Text(isPickingTarget ? "Annuler cible" : "Cibler"),
                ),
                if (targetIsLocked)
                  OutlinedButton.icon(
                    onPressed: onClearTarget,
                    icon: const Icon(Icons.layers_clear_outlined),
                    label: const Text("Retirer cible"),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: onAttack,
                  child: const Text("Attaque"),
                ),
                ElevatedButton(
                  onPressed: onSpell,
                  child: const Text("Sort"),
                ),
                OutlinedButton(
                  onPressed: onHelp,
                  child: const Text("Aide"),
                ),
                OutlinedButton(
                  onPressed: onDodge,
                  child: const Text("Esquive"),
                ),
                OutlinedButton(
                  onPressed: onMoveAction,
                  child: const Text("Deplacement"),
                ),
                OutlinedButton(
                  onPressed: onBonusAction,
                  child: const Text("Bonus"),
                ),
                OutlinedButton(
                  onPressed: onReaction,
                  child: const Text("Reaction"),
                ),
                if (onEndTurn != null)
                  TextButton(
                    onPressed: onEndTurn,
                    child: const Text("Fin du tour"),
                  ),
              ],
            ),
            if (combatant != null && isGM) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: onDamage,
                    child: const Text("-1 PV"),
                  ),
                  OutlinedButton(
                    onPressed: onHeal,
                    child: const Text("+1 PV"),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoLine({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFFFFD700)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _ResourceChip extends StatelessWidget {
  final String label;
  final bool used;

  const _ResourceChip({
    required this.label,
    required this.used,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: used ? const Color(0xFF3A1F22) : const Color(0xFF1F3A2A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: used
              ? Colors.redAccent.withValues(alpha: 0.35)
              : Colors.greenAccent.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: used ? Colors.redAccent.shade100 : Colors.greenAccent.shade100,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

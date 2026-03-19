import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/api_config.dart';
import 'session_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  final SessionService _sessionService = SessionService();

  io.Socket? _socket;
  bool _isInit = false;
  int? _campaignId;
  String? _socketUrl;

  Future<void> init(int campaignId) async {
    _campaignId = campaignId;
    final nextSocketUrl = ApiConfig.socketUrl;

    if (_isInit && _socket != null) {
      if (_socketUrl != nextSocketUrl) {
        _resetSocket(clearCampaign: false);
      } else if (_socket!.disconnected) {
        _resetSocket(clearCampaign: false);
      }
    }

    if (_isInit && _socket != null) {
      if (_socket!.connected) {
        _socket!.emit('join_campaign', campaignId);
      } else {
        _socket!.connect();
      }
      return;
    }

    final extraHeaders = await _sessionService.authHeaders(requireUser: false);
    final transports = kIsWeb ? ['polling'] : ['websocket', 'polling'];

    _socket = io.io(
      nextSocketUrl,
      io.OptionBuilder()
          .setPath('/socket.io')
          .setTransports(transports)
          .disableAutoConnect()
          .setReconnectionAttempts(double.infinity)
          .setExtraHeaders(extraHeaders)
          .build(),
    );
    _socketUrl = nextSocketUrl;

    _socket!.onConnect((_) {
      debugPrint('Socket connecte: ${_socket?.id}');
      if (_campaignId != null) {
        _socket?.emit('join_campaign', _campaignId);
      }
    });

    _socket!.onConnectError(
      (data) => debugPrint("Erreur connexion socket: $data"),
    );
    _socket!.onError((data) => debugPrint("Erreur socket: $data"));
    _socket!.onDisconnect((_) => debugPrint('Socket deconnecte'));

    _socket!.connect();
    _isInit = true;
  }

  void sendMove(int campaignId, String mapId, String charId, int x, int y) {
    _socket?.emit('move_token', {
      'campaignId': campaignId,
      'mapId': mapId,
      'charId': charId,
      'x': x,
      'y': y,
    });
  }

  void onTokenMoved(Function(dynamic) callback) {
    _socket?.off('token_moved');
    _socket?.on('token_moved', callback);
  }

  void sendDiceRoll(int campaignId, String user, String result) {
    _socket?.emit('dice_roll', {
      'campaignId': campaignId,
      'user': user,
      'result': result,
    });
  }

  void onSessionLog(Function(dynamic) callback) {
    _socket?.off('new_log');
    _socket?.on('new_log', callback);
  }

  void onMapTokensUpdated(Function(dynamic) callback) {
    _socket?.off('map_tokens_updated');
    _socket?.on('map_tokens_updated', callback);
  }

  void onDiceRoll(Function(dynamic) callback) {
    onSessionLog(callback);
  }

  void dispose() {
    if (!_isInit) return;
    _resetSocket(clearCampaign: true);
  }

  void _resetSocket({required bool clearCampaign}) {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _socketUrl = null;
    if (clearCampaign) {
      _campaignId = null;
    }
    _isInit = false;
  }
}

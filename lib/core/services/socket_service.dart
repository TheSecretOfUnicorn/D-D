import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter/foundation.dart';

class SocketService {
  // Singleton (Instance unique pour toute l'appli)
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  late io.Socket socket;
  bool _isInit = false;

  // Initialiser la connexion
  void init(int campaignId) {
    if (_isInit) return;

    const String serverUrl = 'http://sc2tphk4284.universe.wf/api_jdr';

    socket = io.io(serverUrl, io.OptionBuilder()
        // 👇 CHANGEMENT CLÉ : On autorise 'polling' en premier pour passer les pare-feu
        .setTransports(['polling', 'websocket']) 
        .disableAutoConnect()
        .setReconnectionAttempts(double.infinity) // Réessaie tout le temps
        .build());

    // Debug avancé pour comprendre ce qui coince
    socket.onConnectError((data) => debugPrint("⚠️ Erreur Connexion: $data"));
    socket.on('connect_timeout', (data) => debugPrint("⏱️ Timeout Connexion"));
    socket.onError((data) => debugPrint("❌ Erreur Générale: $data"));

    socket.connect();

    socket.onConnect((_) {
      debugPrint('🟢 Socket Connecté ! (Transport: ${socket.io.engine?.transport?.name})');
      socket.emit('join_campaign', campaignId);
    });

    socket.onDisconnect((_) => debugPrint('🔴 Socket Déconnecté'));

    _isInit = true;
  }

  // 1. Émettre un mouvement de pion
  void sendMove(int campaignId, String charId, int x, int y) {
    socket.emit('move_token', {
      'campaignId': campaignId,
      'charId': charId,
      'x': x,
      'y': y,
    });
  }

  // 2. Écouter les mouvements des autres
  void onTokenMoved(Function(dynamic) callback) {
    socket.on('token_moved', callback);
  }

  // 3. Émettre un lancer de dé
  void sendDiceRoll(int campaignId, String user, String result) {
    socket.emit('dice_roll', {
      'campaignId': campaignId,
      'user': user,
      'result': result, // ex: "1d20 = 18"
    });
  }

  // 4. Écouter les lancers des autres
  void onDiceRoll(Function(dynamic) callback) {
    socket.on('new_log', callback);
  }

  // Quitter proprement
  void dispose() {
    socket.disconnect();
    _isInit = false;
  }
}
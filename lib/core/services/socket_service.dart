import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter/foundation.dart';

class SocketService {
  // Singleton (Instance unique)
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  late io.Socket socket;
  bool _isInit = false;

  // Initialiser la connexion
  void init(int campaignId) {
    if (_isInit) return; // Évite de reconnecter si déjà connecté

    // L'adresse de votre serveur
    const String serverUrl = 'http://sc2tphk4284.universe.wf';

    socket = io.io(serverUrl, io.OptionBuilder()
        .setTransports(['websocket']) // Force le WebSocket (plus rapide)
        .disableAutoConnect()         // On connecte manuellement
        .build());

    socket.connect();

    socket.onConnect((_) {
      debugPrint('🟢 Socket Connecté ! ID: ${socket.id}');
      // On rejoint la "salle" de la campagne
      socket.emit('join_campaign', campaignId);
    });

    socket.onDisconnect((_) => debugPrint('🔴 Socket Déconnecté'));
    socket.onError((data) => debugPrint('❌ Erreur Socket: $data'));

    _isInit = true;
  }

  // Émettre un mouvement de pion
  void sendMove(int campaignId, String charId, int x, int y) {
    socket.emit('move_token', {
      'campaignId': campaignId,
      'charId': charId,
      'x': x,
      'y': y,
    });
  }

  // Écouter les mouvements des autres
  void onTokenMoved(Function(dynamic) callback) {
    socket.on('token_moved', callback);
  }

  // Quitter proprement
  void dispose() {
    socket.disconnect();
    _isInit = false;
  }
}
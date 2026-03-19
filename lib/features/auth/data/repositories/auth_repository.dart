import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/config/api_config.dart';
import '../../../../core/services/session_service.dart';

class AuthRepository {
  final SessionService _sessionService = SessionService();
  final String baseUrl = ApiConfig.baseUrl;

  /// Inscription : Retourne le QR Code (base64) et le Secret
  Future<Map<String, dynamic>> register(String username) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": username}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      } else {
        throw Exception(jsonDecode(response.body)['error'] ?? "Erreur serveur");
      }
    } catch (e) {
      throw Exception("Erreur connexion: $e");
    }
  }

  /// Login : Vérifie le code TOTP
  Future<bool> login(String username, String code) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": username, "token": code}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        await _sessionService.saveSession(
          userId: data['userId'],
          username: username,
        );
        return true;
      } else {
        return false;
      }
    } catch (e) {
      throw Exception("Erreur connexion: $e");
    }
  }

  /// Déconnexion
  Future<void> logout() async {
    await _sessionService.clearSession();
  }
  
  /// Vérifie si on est déjà connecté
  Future<bool> checkSession() => _sessionService.hasSession();
}

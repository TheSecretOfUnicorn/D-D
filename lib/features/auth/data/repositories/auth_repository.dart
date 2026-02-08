import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthRepository {
  // ⚠️ REMPLACE PAR TON URL cPANEL
  final String baseUrl = "http://sc2tphk4284.universe.wf/api_jdr"; 

  /// Inscription : Retourne le QR Code (base64) et le Secret
  Future<Map<String, dynamic>> register(String username) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": username}),
      );

      if (response.statusCode == 200) {
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

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // On sauvegarde l'ID utilisateur et le Username en local pour la session
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('user_id', data['userId']);
        await prefs.setString('username', username);
        
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
  
  /// Vérifie si on est déjà connecté
  Future<bool> checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('user_id');
  }
}
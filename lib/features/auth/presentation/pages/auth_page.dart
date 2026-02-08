import 'dart:convert';
import 'package:flutter/material.dart';
import '../../data/repositories/auth_repository.dart';
import '../../../campaign_manager/presentation/pages/campaign_dashboard_page.dart'; // Ta page d'accueil

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final AuthRepository _authRepo = AuthRepository();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _codeController = TextEditingController(); // Pour le 2FA
  
  bool _isLoading = false;
  String? _qrCodeBase64; // Pour afficher le QR Code lors de l'inscription
  String? _manualSecret; // Au cas où le scan ne marche pas

  // --- ACTIONS ---

  void _login() async {
    setState(() => _isLoading = true);
    try {
      final success = await _authRepo.login(_userController.text, _codeController.text);
      if (success) {
        if (mounted) {
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (_) => const CampaignDashboardPage())
          );
        }
      } else {
        _showError("Code invalide ou utilisateur inconnu");
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _register() async {
    setState(() => _isLoading = true);
    try {
      final data = await _authRepo.register(_userController.text);
      setState(() {
        // L'API renvoie "data:image/png;base64,....."
        // On doit nettoyer la string pour Flutter
        String rawImg = data['qr_code'];
        _qrCodeBase64 = rawImg.split(',').last; 
        _manualSecret = data['manual_secret'];
      });
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Portail JDR"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Connexion"),
              Tab(text: "Inscription"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildLoginForm(),
            _buildRegisterForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.security, size: 80, color: Colors.blueAccent),
          const SizedBox(height: 30),
          TextField(
            controller: _userController,
            decoration: const InputDecoration(
              labelText: "Nom d'utilisateur", 
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person)
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: "Code Authenticator (6 chiffres)", 
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock_clock)
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _login,
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white) 
                : const Text("ENTRER"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    if (_qrCodeBase64 != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.check_circle, size: 60, color: Colors.green),
            const SizedBox(height: 20),
            const Text("Compte créé !", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Scannez ce code avec Google Authenticator :", textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Image.memory(base64Decode(_qrCodeBase64!), height: 200),
            const SizedBox(height: 20),
            SelectableText("Clé manuelle : $_manualSecret", style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                // Reset pour aller se connecter
                setState(() {
                  _qrCodeBase64 = null;
                });
                DefaultTabController.of(context).animateTo(0); // Va à l'onglet Connexion
              }, 
              child: const Text("J'ai scanné, me connecter")
            )
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_add, size: 80, color: Colors.orange),
          const SizedBox(height: 30),
          TextField(
            controller: _userController,
            decoration: const InputDecoration(
              labelText: "Choisir un pseudo", 
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person)
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _register,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white) 
                : const Text("CRÉER COMPTE & QR CODE"),
            ),
          ),
        ],
      ),
    );
  }
}
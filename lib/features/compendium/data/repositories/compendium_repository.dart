import 'dart:convert';
import 'package:http/http.dart' as http;

class CompendiumRepository {
  // ⚠️ Remplace par ton IP locale (ex: 10.0.2.2 pour émulateur Android, ou ton IP LAN)
  // Si tu es sur le même PC en web : http://localhost:3000
  final String baseUrl = "http://sc2tphk4284.universe.wf/api_jdr"; 

  /// Récupère tout le compendium (ou filtré par campagne)
  Future<Map<String, List<Map<String, dynamic>>>> fetchFullCompendium(String? campaignId) async {
    // Si pas de campagne, on envoie "0" ou on gère le null côté serveur
    final String url = "$baseUrl/compendium/${campaignId ?? '0'}";
    
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> rawData = jsonDecode(response.body);
        
        // On trie les données dans deux listes : Objets et Sorts
        List<Map<String, dynamic>> items = [];
        List<Map<String, dynamic>> spells = [];

        for (var entry in rawData) {
          // On s'assure que 'data' est bien un Map
          Map<String, dynamic> content = entry['data'] != null ? Map<String, dynamic>.from(entry['data']) : {};
          
          // On ajoute le nom et les tags à l'objet 'data' pour faciliter l'affichage
          content['name'] = entry['name'];
          content['type'] = entry['type'];
          content['tags'] = entry['tags'];
          
          if (entry['type'] == 'item') {
            items.add(content);
          } else if (entry['type'] == 'spell') {
            spells.add(content);
          }
        }

        return {
          'items': items,
          'spells': spells,
        };
      } else {
        print("Erreur serveur: ${response.statusCode}");
        return {'items': [], 'spells': []};
      }
    } catch (e) {
      print("Erreur connexion compendium: $e");
      return {'items': [], 'spells': []};
    }
  }
}
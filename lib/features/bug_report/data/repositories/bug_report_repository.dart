import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/config/api_config.dart';
import '../../../../core/services/session_service.dart';

class BugReportRepository {
  final SessionService _sessionService = SessionService();
  final String baseUrl = ApiConfig.baseUrl;

  Future<Map<String, String>> _headers() => _sessionService.authHeaders();

  Future<bool> submitReport({
    required String title,
    required String category,
    required String severity,
    required String actual,
    String expected = '',
    String steps = '',
    required String sourcePage,
    int? campaignId,
    String? mapId,
    String? characterId,
    Map<String, dynamic> extraContext = const {},
  }) async {
    final headers = await _headers();
    final response = await http.post(
      Uri.parse('$baseUrl/bug-reports'),
      headers: headers,
      body: jsonEncode({
        'title': title.trim(),
        'category': category,
        'severity': severity,
        'actual': actual.trim(),
        'expected': expected.trim(),
        'steps': steps.trim(),
        'source_page': sourcePage,
        'campaign_id': campaignId,
        'map_id': mapId,
        'character_id': characterId,
        'extra_context': extraContext,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return true;
    }

    final body = response.body.trim();
    if (body.isNotEmpty) {
      try {
        final data = jsonDecode(body);
        if (data is Map<String, dynamic> && data['error'] != null) {
          throw Exception(data['error'].toString());
        }
      } catch (_) {
        throw Exception(body);
      }
    }

    throw Exception('Erreur serveur (${response.statusCode})');
  }
}

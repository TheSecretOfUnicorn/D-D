import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/config/api_config.dart';
import '../../../../core/services/session_service.dart';
import '../models/knowledge_entry_model.dart';

class KnowledgeRepository {
  final SessionService _sessionService = SessionService();
  final String baseUrl = ApiConfig.baseUrl;

  Future<Map<String, String>> _getHeaders() => _sessionService.authHeaders();

  Future<List<KnowledgeEntryModel>> fetchEntries(int campaignId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse("$baseUrl/campaigns/$campaignId/notes"),
        headers: headers,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .map((entry) => KnowledgeEntryModel.fromJson(
                  Map<String, dynamic>.from(entry),
                ))
            .toList(growable: false);
      }
    } catch (_) {}

    return const [];
  }

  Future<bool> createEntry(
    int campaignId, {
    required String title,
    required String content,
    required KnowledgeVisibility visibility,
    List<int> sharedWith = const [],
  }) async {
    try {
      final headers = await _getHeaders();
      final isPublic = visibility == KnowledgeVisibility.group;
      final response = await http.post(
        Uri.parse("$baseUrl/campaigns/$campaignId/notes"),
        headers: headers,
        body: jsonEncode({
          "title": title,
          "content": content,
          "is_public": isPublic,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }

      final created = Map<String, dynamic>.from(jsonDecode(response.body));
      final noteId = created['id'];
      if (noteId == null) return true;

      if (visibility == KnowledgeVisibility.group) {
        return true;
      }

      final shareResponse = await http.patch(
        Uri.parse("$baseUrl/notes/$noteId/share"),
        headers: headers,
        body: jsonEncode({
          "is_public": false,
          "shared_with": visibility == KnowledgeVisibility.targeted
              ? sharedWith
              : <int>[],
        }),
      );

      return shareResponse.statusCode >= 200 && shareResponse.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateVisibility(
    int noteId, {
    required KnowledgeVisibility visibility,
    List<int> sharedWith = const [],
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse("$baseUrl/notes/$noteId/share"),
        headers: headers,
        body: jsonEncode({
          "is_public": visibility == KnowledgeVisibility.group,
          "shared_with": visibility == KnowledgeVisibility.targeted
              ? sharedWith
              : <int>[],
        }),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteEntry(int noteId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse("$baseUrl/notes/$noteId"),
        headers: headers,
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}

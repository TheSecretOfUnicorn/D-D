import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const String userIdKey = 'user_id';
  static const String usernameKey = 'username';
  static const String activeCampaignIdKey = 'active_campaign_id';

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<void> saveSession({
    required dynamic userId,
    required String username,
  }) async {
    final prefs = await _prefs();
    await prefs.setString(userIdKey, userId.toString());
    await prefs.setString(usernameKey, username);
  }

  Future<void> clearSession() async {
    final prefs = await _prefs();
    await prefs.clear();
  }

  Future<String?> getUserId() async {
    final prefs = await _prefs();
    return prefs.get(userIdKey)?.toString();
  }

  Future<bool> hasSession() async {
    final userId = await getUserId();
    return userId != null && userId.isNotEmpty;
  }

  Future<void> setActiveCampaignId(int? campaignId) async {
    final prefs = await _prefs();
    if (campaignId == null) {
      await prefs.remove(activeCampaignIdKey);
      return;
    }
    await prefs.setInt(activeCampaignIdKey, campaignId);
  }

  Future<int?> getActiveCampaignId() async {
    final prefs = await _prefs();
    return prefs.getInt(activeCampaignIdKey);
  }

  Future<Map<String, String>> authHeaders({
    bool requireUser = true,
    bool includeJsonContentType = true,
  }) async {
    final headers = <String, String>{};
    if (includeJsonContentType) {
      headers['Content-Type'] = 'application/json';
    }

    final userId = await getUserId();
    if (userId == null || userId.isEmpty) {
      if (requireUser) {
        throw Exception('Utilisateur non connecte');
      }
      return headers;
    }

    headers['x-user-id'] = userId;
    return headers;
  }
}

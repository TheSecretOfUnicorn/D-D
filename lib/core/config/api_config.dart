class ApiConfig {
  static const String _defaultBaseUrl = 'http://sc2tphk4284.universe.wf/api_jdr';
  static const String _defaultSocketUrl = 'http://sc2tphk4284.universe.wf';

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  static String get socketUrl {
    const override = String.fromEnvironment('SOCKET_URL', defaultValue: '');
    if (override.isNotEmpty) {
      return override;
    }

    final baseUri = Uri.parse(baseUrl);
    if (baseUri.hasScheme && baseUri.host.isNotEmpty) {
      final port = baseUri.hasPort ? ':${baseUri.port}' : '';
      return '${baseUri.scheme}://${baseUri.host}$port';
    }

    return _defaultSocketUrl;
  }
}

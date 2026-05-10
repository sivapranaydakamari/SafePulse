class AppConfig {
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://10.34.186.36:5000',
  );

  static String get realtimeUrl {
    final uri = Uri.parse(baseUrl);
    return uri
        .replace(
          scheme: uri.scheme == 'https' ? 'wss' : 'ws',
          path: '/ws/tracking',
          query: '',
        )
        .toString();
  }
}

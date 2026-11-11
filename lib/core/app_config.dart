class AppConfig {
  const AppConfig._();

  static const appwriteEndpoint = String.fromEnvironment(
    'APPWRITE_ENDPOINT',
    defaultValue: 'https://cloud.appwrite.io/v1',
  );
  static const appwriteProjectId = String.fromEnvironment(
    'APPWRITE_PROJECT_ID',
    defaultValue: '6af01d97002875d6d7bd',
  );
  static const backendApiUrl = String.fromEnvironment(
    'TESTAGRAM_API_URL',
    defaultValue: 'https://8080-agq4me2xgrgx5ge52ts437tqea.instabox.tech',
  );
  static const siteUrl = String.fromEnvironment(
    'TESTAGRAM_SITE_URL',
    defaultValue: 'https://testagram.site',
  );

  static const enableTvCatalogue = bool.fromEnvironment(
    'TESTAGRAM_TV_ENABLED',
    defaultValue: false,
  );

  static const tvPlaybackHostsRaw = String.fromEnvironment(
    'TESTAGRAM_TV_PLAYBACK_HOSTS',
    defaultValue: 'media.testagram.site',
  );

  static Set<String> get tvPlaybackHosts => tvPlaybackHostsRaw
      .split(',')
      .map((host) => host.trim().toLowerCase())
      .where((host) => host.isNotEmpty)
      .toSet();

  static bool get isConfigured =>
      _isHttpsUrl(appwriteEndpoint) &&
      appwriteProjectId.trim().isNotEmpty &&
      _isHttpsUrl(backendApiUrl) &&
      _isHttpsUrl(siteUrl);

  static Uri get backendOrigin => Uri.parse(backendApiUrl);

  static bool _isHttpsUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }
}

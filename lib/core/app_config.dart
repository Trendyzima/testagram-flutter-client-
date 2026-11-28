class AppConfig {
  const AppConfig._();

  static const termsVersion = String.fromEnvironment(
    'TESTAGRAM_TERMS_VERSION',
    defaultValue: '2026-11-11',
  );
  static const privacyVersion = String.fromEnvironment(
    'TESTAGRAM_PRIVACY_VERSION',
    defaultValue: '2026-11-11',
  );
  static const backendApiUrl = String.fromEnvironment(
    'TESTAGRAM_API_URL',
    defaultValue: 'https://api.testagram.site',
  );
  static const siteUrl = String.fromEnvironment(
    'TESTAGRAM_SITE_URL',
    defaultValue: 'https://testagram.site',
  );

  // Public identity-review enrollment is deliberately disabled in every build.
  // Re-enabling it requires an explicit reviewed source change and CI policy update;
  // no --dart-define or deployment environment variable can turn it back on.
  static const enableIdentityRegistrationUi = false;

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

  // All client video operations use the canonical Backend origin.
  // The private Data Centre video service is never configured in Flutter.
  static String get videoApiUrl => backendApiUrl;
  static Uri get videoApiOrigin => backendOrigin;

  static bool get isConfigured =>
      _isHttpsUrl(backendApiUrl) && _isHttpsUrl(siteUrl);

  static Uri get backendOrigin => Uri.parse(backendApiUrl);

  static bool _isHttpsUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment;
  }
}

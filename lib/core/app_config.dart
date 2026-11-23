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

  static const enableIdentityRegistrationUi = bool.fromEnvironment(
    'TESTAGRAM_IDENTITY_REGISTRATION_UI_ENABLED',
    defaultValue: true,
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

  // The video service is routed by Caddy under the same HTTPS API origin.
  // A separate origin remains overridable for staging or dedicated deployments.
  static const videoApiUrl = String.fromEnvironment(
    'TESTAGRAM_VIDEO_API_URL',
    defaultValue: backendApiUrl,
  );

  static Uri? get videoApiOrigin {
    final value = videoApiUrl.trim();
    if (value.isEmpty || !_isHttpsUrl(value)) return null;
    return Uri.parse(value);
  }

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

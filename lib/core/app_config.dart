class AppConfig {
  const AppConfig._();

  static const appwriteEndpoint = String.fromEnvironment('APPWRITE_ENDPOINT');
  static const appwriteProjectId = String.fromEnvironment('APPWRITE_PROJECT_ID');
  static const backendApiUrl = String.fromEnvironment('TESTAGRAM_API_URL');

  static bool get isConfigured =>
      _isHttpUrl(appwriteEndpoint) &&
      appwriteProjectId.trim().isNotEmpty &&
      _isHttpUrl(backendApiUrl);

  static Uri get backendOrigin => Uri.parse(backendApiUrl);

  static bool _isHttpUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }
}

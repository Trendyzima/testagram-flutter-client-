/// A strictly allow-listed destination parsed from an incoming Testagram link.
/// This parser never accepts arbitrary hosts, redirect URLs or payment parameters.
enum TestagramDeepLinkKind { profileUsername, profileId, wallet }

class TestagramDeepLink {
  const TestagramDeepLink._({
    required this.kind,
    this.username,
    this.userId,
  });

  final TestagramDeepLinkKind kind;
  final String? username;
  final String? userId;

  static final RegExp _username = RegExp(r'^[A-Za-z0-9_.]{2,30}$');
  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  static TestagramDeepLink? parse(String raw) {
    final value = raw.trim();
    if (value.isEmpty || value.length > 2048) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || uri.hasFragment || uri.userInfo.isNotEmpty) return null;

    final isWeb = uri.scheme == 'https' &&
        const {'testagram.site', 'www.testagram.site'}.contains(uri.host.toLowerCase()) &&
        uri.port == 443;
    final isCustom = uri.scheme == 'testagram' &&
        uri.port == 0 &&
        uri.userInfo.isEmpty;
    final isLocalRoute = uri.scheme.isEmpty &&
        uri.host.isEmpty &&
        !value.startsWith('//');
    if (!isWeb && !isCustom && !isLocalRoute) return null;

    if (isCustom && uri.host.toLowerCase() == 'wallet' && uri.pathSegments.isEmpty) {
      return const TestagramDeepLink._(kind: TestagramDeepLinkKind.wallet);
    }
    if (isCustom && uri.host.toLowerCase() == 'profile' && uri.pathSegments.length == 1) {
      return _profileUsername(uri.pathSegments.single);
    }

    final segments = uri.pathSegments;
    if (segments.length == 1 && segments.single.toLowerCase() == 'wallet') {
      return const TestagramDeepLink._(kind: TestagramDeepLinkKind.wallet);
    }
    if (segments.length == 1 && segments.single.startsWith('@')) {
      return _profileUsername(segments.single.substring(1));
    }
    if (segments.length == 2 && segments.first.toLowerCase() == 'u') {
      return _profileUsername(segments[1]);
    }
    if (segments.length == 2 && segments.first.toLowerCase() == 'profile') {
      final id = segments[1].toLowerCase();
      if (!_uuid.hasMatch(id)) return null;
      return TestagramDeepLink._(
        kind: TestagramDeepLinkKind.profileId,
        userId: id,
      );
    }
    return null;
  }

  static TestagramDeepLink? _profileUsername(String raw) {
    final username = raw.startsWith('@') ? raw.substring(1) : raw;
    if (!_username.hasMatch(username)) return null;
    return TestagramDeepLink._(
      kind: TestagramDeepLinkKind.profileUsername,
      username: username,
    );
  }
}

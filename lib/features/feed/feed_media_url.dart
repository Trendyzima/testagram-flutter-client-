/// Canonicalizes legacy first-party media URLs before feed rendering.
///
/// Older Testagram rows can contain `/users/...` URLs. The CDN preserves
/// those paths through its backward-compatible `/media/` alias, which maps to
/// the canonical `/v1/` origin route. Private media authorization headers must
/// be normalized with the same function so their URL keys continue to match.
class FeedMediaUrl {
  const FeedMediaUrl._();

  static const cdnHost = 'media.testagram.site';

  static String? normalize(dynamic value) {
    if (value is! String) return null;
    final raw = value.trim();
    if (raw.isEmpty) return null;

    final parsed = Uri.tryParse(raw);
    if (parsed == null ||
        !parsed.hasAuthority ||
        parsed.host.toLowerCase() != cdnHost ||
        (parsed.scheme != 'https' && parsed.scheme != 'http') ||
        parsed.userInfo.isNotEmpty ||
        parsed.hasFragment ||
        (parsed.scheme == 'https' && parsed.port != 443) ||
        (parsed.scheme == 'http' && parsed.port != 80)) {
      return null;
    }

    var uri = parsed;
    if (uri.scheme == 'http') {
      uri = uri.replace(scheme: 'https', port: 443);
    }
    if (uri.path.startsWith('/users/')) {
      uri = uri.replace(path: '/media${uri.path}');
    }
    return uri.toString();
  }
}

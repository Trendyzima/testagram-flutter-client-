import 'dart:convert';

/// Persistence rules for the public IPTV catalogue.
///
/// This policy deliberately excludes signed URLs, private/user-owned streams,
/// credentials and unbounded cache payloads. It does not authorize playback;
/// the Backend/CDN remains authoritative for media access.
class TvChannelCachePolicy {
  const TvChannelCachePolicy._();

  static const cacheKey = 'testagram.iptv.public_catalog.v1';
  static const maxAge = Duration(hours: 24);
  static const maxChannels = 250;
  static const maxEncodedBytes = 1024 * 1024;

  static const _sensitiveQueryFragments = <String>[
    'token', 'signature', 'expires', 'authorization', 'auth', 'jwt',
    'credential', 'key', 'hdnts', 'hdnea', 'x-amz-', 'policy',
  ];

  static bool isPublicCacheUrl(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return false;
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return false;
    }
    for (final key in uri.queryParameters.keys) {
      final normalized = key.toLowerCase();
      if (_sensitiveQueryFragments.any(
        (fragment) => normalized.contains(fragment),
      )) {
        return false;
      }
    }
    return true;
  }

  static List<Map<String, dynamic>> sanitizeChannels(
    Iterable<Map<String, dynamic>> channels,
  ) {
    final output = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final channel in channels) {
      if (channel['_sourceType'] != 'catalog') continue;
      final url = '${channel['playback_url'] ?? channel['stream_url'] ?? channel['url'] ?? ''}'.trim();
      if (!isPublicCacheUrl(url)) continue;
      final id = '${channel['id'] ?? url}';
      if (!seen.add(id)) continue;
      final thumbnail = channel['thumbnail_url'];
      output.add(<String, dynamic>{
        'id': id,
        'title': '${channel['title'] ?? channel['name'] ?? 'Live channel'}',
        'name': '${channel['name'] ?? channel['title'] ?? 'Live channel'}',
        'description': '${channel['description'] ?? channel['category'] ?? 'Public channel'}',
        'thumbnail_url': isPublicCacheUrl(thumbnail) ? thumbnail : null,
        'playback_url': url,
        'category': '${channel['category'] ?? 'Live TV'}',
        '_sourceType': 'catalog',
        'is_live': true,
      });
      if (output.length >= maxChannels) break;
    }
    return output;
  }

  static String? encode(
    Iterable<Map<String, dynamic>> channels, {
    DateTime? now,
  }) {
    final safe = sanitizeChannels(channels);
    if (safe.isEmpty) return null;
    final encoded = jsonEncode({
      'savedAt': (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch,
      'channels': safe,
    });
    if (encoded.length > maxEncodedBytes) return null;
    return encoded;
  }

  static List<Map<String, dynamic>> decode(
    String? raw, {
    DateTime? now,
  }) {
    if (raw == null || raw.isEmpty || raw.length > maxEncodedBytes) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map ||
          decoded['savedAt'] is! num ||
          decoded['channels'] is! List) {
        return const [];
      }
      final current = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
      final savedAt = (decoded['savedAt'] as num).toInt();
      final age = current - savedAt;
      if (age < -const Duration(minutes: 5).inMilliseconds ||
          age > maxAge.inMilliseconds) {
        return const [];
      }
      final rows = (decoded['channels'] as List)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      return sanitizeChannels(rows);
    } catch (_) {
      return const [];
    }
  }
}

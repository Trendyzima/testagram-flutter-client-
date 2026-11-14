import 'dart:convert';

/// Safe persistence rules for public, catalog-owned IPTV entries.
///
/// This policy does not fetch streams or persist anything itself. Callers must
/// obtain entries from an authorized public catalogue before marking them
/// with `_sourceType: catalog`. User-owned live streams are never cacheable.
class TvChannelCachePolicy {
  const TvChannelCachePolicy._();

  static const cacheKey = 'testagram.iptv.public_catalog.v1';
  static const maxAge = Duration(hours: 24);
  static const maxChannels = 250;
  static const maxEncodedBytes = 1024 * 1024;

  static const _sensitiveQuery = <String>[
    'token',
    'signature',
    'expires',
    'authorization',
    'auth',
    'jwt',
    'credential',
    'key',
    'hdnts',
    'hdnea',
    'policy',
  ];

  static bool _isLocalOrPrivateHost(String rawHost) {
    final host = rawHost.toLowerCase().replaceAll('[', '').replaceAll(']', '');
    if (host.startsWith('::ffff:')) {
      return _isLocalOrPrivateHost(host.substring(7));
    }
    if (host == 'localhost' ||
        host.endsWith('.localhost') ||
        host.endsWith('.local') ||
        host.endsWith('.internal') ||
        host == '::' ||
        host == '::1' ||
        host.startsWith('fc') ||
        host.startsWith('fd') ||
        host.startsWith('fe80:') ||
        host.startsWith('ff')) {
      return true;
    }

    final parts = host.split('.');
    if (parts.length != 4) return false;
    final octets = parts.map(int.tryParse).toList(growable: false);
    if (octets.any((value) => value == null || value! < 0 || value > 255)) {
      return false;
    }

    final a = octets[0]!;
    final b = octets[1]!;
    final c = octets[2]!;
    return a == 0 ||
        a == 10 ||
        a == 127 ||
        a >= 224 ||
        (a == 100 && b >= 64 && b <= 127) ||
        (a == 169 && b == 254) ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && (b == 0 || b == 2 || b == 168)) ||
        (a == 198 && (b == 18 || b == 19 || b == 51)) ||
        (a == 203 && b == 0 && c == 113);
  }
  static bool isPublicCacheUrl(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return false;
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        _isLocalOrPrivateHost(uri.host)) {
      return false;
    }

    for (final key in uri.queryParameters.keys) {
      final normalized = key.toLowerCase();
      if (_sensitiveQuery.contains(normalized) ||
          normalized.startsWith('x-amz-') ||
          normalized.contains('token') ||
          normalized.contains('signature') ||
          normalized.contains('credential') ||
          normalized.contains('authorization') ||
          normalized.contains('expires') ||
          normalized.contains('jwt') ||
          normalized.contains('hdnts') ||
          normalized.contains('hdnea')) {
        return false;
      }
    }
    return true;
  }

  static String _boundedText(Object? value, {required String fallback, int max = 512}) {
    final text = value is String ? value.trim() : '';
    if (text.isEmpty) return fallback;
    return text.length <= max ? text : text.substring(0, max);
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

      final id = '${channel['id'] ?? url}'.trim();
      if (id.isEmpty || id.length > 128 || !seen.add(id)) continue;

      final thumbnail = channel['thumbnail_url'];
      output.add(<String, dynamic>{
        'id': id,
        'title': _boundedText(
          channel['title'] ?? channel['name'],
          fallback: 'Live channel',
          max: 160,
        ),
        'name': _boundedText(
          channel['name'] ?? channel['title'],
          fallback: 'Live channel',
          max: 160,
        ),
        'description': _boundedText(
          channel['description'] ?? channel['category'],
          fallback: 'Public live channel',
        ),
        'thumbnail_url': isPublicCacheUrl(thumbnail) ? thumbnail : null,
        'playback_url': url,
        'stream_url': url,
        'url': url,
        'category': _boundedText(
          channel['category'],
          fallback: 'Live TV',
          max: 80,
        ),
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
    if (utf8.encode(encoded).length > maxEncodedBytes) return null;
    return encoded;
  }

  static List<Map<String, dynamic>> decode(
    String? raw, {
    DateTime? now,
  }) {
    if (raw == null || raw.isEmpty || utf8.encode(raw).length > maxEncodedBytes) {
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
          .toList(growable: false);
      return sanitizeChannels(rows);
    } catch (_) {
      return const [];
    }
  }
}

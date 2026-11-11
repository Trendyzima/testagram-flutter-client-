import 'dart:convert';

/// Safe offline cache for normalized public catalogue metadata only.
///
/// Deliberately never stores playback URLs, source URLs, tokens, credentials,
/// owner-private records, or any field that could become a playback capability.
/// A playback grant must always be requested from Backend immediately before
/// playback, so cached data can never authorize access to a stream.
class TvChannelCachePolicy {
  const TvChannelCachePolicy._();

  static const cacheKey = 'testagram.tv.public_catalog_metadata.v2';
  static const maxAge = Duration(hours: 24);
  static const maxChannels = 250;
  static const maxEncodedBytes = 1024 * 1024;

  static bool _safeHttpsUrl(Object? raw) {
    if (raw == null) return false;
    if (raw is! String || raw.trim().isEmpty) return false;
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      return false;
    }
    final sensitive = RegExp(
      r'(token|signature|expires|authorization|credential|secret|jwt|hdnts|hdnea|x-amz|policy|key)',
      caseSensitive: false,
    );
    return !uri.queryParameters.keys.any((key) => sensitive.hasMatch(key));
  }

  static List<Map<String, dynamic>> sanitizeChannels(
    Iterable<Map<String, dynamic>> channels,
  ) {
    final output = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final channel in channels) {
      final id = channel['id'];
      final name = channel['name'];
      final playbackType = channel['playback_type'];
      final availability = channel['availability'];
      if (id is! String ||
          id.trim().isEmpty ||
          id.length > 256 ||
          name is! String ||
          name.trim().isEmpty ||
          name.length > 160 ||
          !const {'hls', 'dash', 'mp4', 'external'}.contains(playbackType) ||
          !const {'available', 'degraded', 'offline', 'scheduled', 'unknown'}
              .contains(availability)) {
        continue;
      }
      if (!seen.add(id)) continue;
      final logo = channel['logo_url'];
      final website = channel['website_url'];
      final categories = channel['categories'];
      output.add(<String, dynamic>{
        'id': id,
        'name': name,
        'description': channel['description'] is String
            ? (channel['description'] as String).substring(
                0,
                (channel['description'] as String).length.clamp(0, 2000),
              )
            : '',
        'logo_url': _safeHttpsUrl(logo) ? logo : null,
        'country_code': channel['country_code'] is String &&
                RegExp(r'^[A-Z]{2}$').hasMatch(channel['country_code'] as String)
            ? channel['country_code']
            : null,
        'language': channel['language'] is String
            ? (channel['language'] as String).substring(
                0,
                (channel['language'] as String).length.clamp(0, 16),
              )
            : null,
        'categories': categories is List
            ? categories.whereType<String>().map((v) => v.trim())
                .where((v) => v.isNotEmpty && v.length <= 64).take(20).toList()
            : <String>[],
        'website_url': _safeHttpsUrl(website) ? website : null,
        'playback_type': playbackType,
        'availability': availability,
        'health_checked_at': channel['health_checked_at'] is String
            ? channel['health_checked_at']
            : null,
        'updated_at': channel['updated_at'] is String ? channel['updated_at'] : null,
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
    if (utf8.encode(encoded).length > maxEncodedBytes) {
      return null;
    }
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
          decoded['channels'] is! List ||
          (decoded['channels'] as List).length > maxChannels) {
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


String _boundedText(String value, int maxLength) =>
    value.length > maxLength ? value.substring(0, maxLength) : value;

import 'package:flutter/foundation.dart';

/// Normalized catalogue metadata. It deliberately has no upstream stream URL.
@immutable
class TvChannel {
  const TvChannel({
    required this.id,
    required this.name,
    required this.playbackType,
    required this.availability,
    required this.updatedAt,
    this.description = '',
    this.logoUrl,
    this.countryCode,
    this.language,
    this.categories = const [],
    this.websiteUrl,
    this.healthCheckedAt,
  });

  final String id;
  final String name;
  final String description;
  final Uri? logoUrl;
  final String? countryCode;
  final String? language;
  final List<String> categories;
  final Uri? websiteUrl;
  final String playbackType;
  final String availability;
  final DateTime? healthCheckedAt;
  final DateTime updatedAt;

  factory TvChannel.fromJson(Map<String, dynamic> json) {
    final id = _requiredText(json, 'id', 256);
    final name = _requiredText(json, 'name', 160);
    final playbackType = _requiredText(json, 'playback_type', 16);
    if (!const {'hls', 'dash', 'mp4', 'external'}.contains(playbackType)) {
      throw const FormatException('Unsupported TV playback type');
    }
    final availability = _requiredText(json, 'availability', 16);
    if (!const {'available', 'degraded', 'offline', 'scheduled', 'unknown'}
        .contains(availability)) {
      throw const FormatException('Unsupported TV channel availability');
    }
    final country = _optionalText(json['country_code'], 2);
    if (country != null && !RegExp(r'^[A-Z]{2}$').hasMatch(country)) {
      throw const FormatException('Invalid TV channel country code');
    }
    final rawCategories = json['categories'];
    if (rawCategories != null && rawCategories is! List) {
      throw const FormatException('Invalid TV channel categories');
    }
    final categories = (rawCategories as List? ?? const [])
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty && value.length <= 64)
        .take(20)
        .toList(growable: false);
    return TvChannel(
      id: id,
      name: name,
      description: _optionalText(json['description'], 2000) ?? '',
      logoUrl: _safeHttpsUri(json['logo_url']),
      countryCode: country,
      language: _optionalText(json['language'], 16),
      categories: categories,
      websiteUrl: _safeHttpsUri(json['website_url']),
      playbackType: playbackType,
      availability: availability,
      healthCheckedAt: _optionalDate(json['health_checked_at']),
      updatedAt: _requiredDate(json['updated_at']),
    );
  }
}

@immutable
class TvChannelPage {
  const TvChannelPage({required this.items, this.nextCursor});

  final List<TvChannel> items;
  final String? nextCursor;

  factory TvChannelPage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    if (raw is! List || raw.length > 50) {
      throw const FormatException('Invalid TV catalogue page');
    }
    final cursor = _optionalText(json['next_cursor'], 2048);
    return TvChannelPage(
      items: raw.map((item) {
        if (item is! Map) throw const FormatException('Invalid TV channel record');
        return TvChannel.fromJson(Map<String, dynamic>.from(item));
      }).toList(growable: false),
      nextCursor: cursor,
    );
  }
}

@immutable
class TvPlaybackGrant {
  const TvPlaybackGrant({
    required this.channelId,
    required this.playbackUrl,
    required this.expiresAt,
    required this.playbackType,
    this.requiredHeaders = const {},
  });

  final String channelId;
  final Uri playbackUrl;
  final DateTime expiresAt;
  final String playbackType;
  final Map<String, String> requiredHeaders;

  factory TvPlaybackGrant.fromJson(
    Map<String, dynamic> json, {
    required Set<String> allowedHosts,
    DateTime? now,
  }) {
    final channelId = _requiredText(json, 'channel_id', 256);
    final rawUrl = _requiredText(json, 'playback_url', 2048);
    final uri = Uri.tryParse(rawUrl);
    final hosts = allowedHosts.map((host) => host.toLowerCase()).toSet();
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !hosts.contains(uri.host.toLowerCase())) {
      throw const FormatException('Playback URL is not on an approved HTTPS media host');
    }
    final expiresAt = _requiredDate(json['expires_at']);
    final current = (now ?? DateTime.now()).toUtc();
    if (!expiresAt.isAfter(current) ||
        expiresAt.isAfter(current.add(const Duration(minutes: 15)))) {
      throw const FormatException('Playback grant expiry is outside the allowed window');
    }
    final playbackType = _requiredText(json, 'playback_type', 16);
    if (!const {'hls', 'dash', 'mp4', 'external'}.contains(playbackType)) {
      throw const FormatException('Unsupported TV playback type');
    }
    final rawHeaders = json['required_headers'];
    if (rawHeaders != null && rawHeaders is! Map) {
      throw const FormatException('Invalid playback headers');
    }
    final headers = <String, String>{};
    for (final entry in (rawHeaders as Map? ?? const {}).entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (!RegExp(r'^[A-Za-z0-9-]{1,64}$').hasMatch(key) ||
          value is! String ||
          value.length > 512 ||
          RegExp(r'[\r\n]').hasMatch(value) ||
          headers.length >= 8) {
        throw const FormatException('Invalid playback header');
      }
      headers[key] = value;
    }
    return TvPlaybackGrant(
      channelId: channelId,
      playbackUrl: uri,
      expiresAt: expiresAt,
      playbackType: playbackType,
      requiredHeaders: Map.unmodifiable(headers),
    );
  }
}

String _requiredText(Map<String, dynamic> json, String key, int maxLength) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty || value.length > maxLength) {
    throw FormatException('Invalid TV field: $key');
  }
  return value.trim();
}

String? _optionalText(Object? value, int maxLength) {
  if (value == null) return null;
  if (value is! String || value.length > maxLength) {
    throw const FormatException('Invalid optional TV text field');
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

Uri? _safeHttpsUri(Object? value) {
  if (value == null) return null;
  if (value is! String) throw const FormatException('Invalid TV URL');
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme.toLowerCase() != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment) {
    throw const FormatException('TV metadata URLs must use HTTPS');
  }
  return uri;
}

DateTime _requiredDate(Object? value) {
  final parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed == null) throw const FormatException('Invalid TV timestamp');
  return parsed.toUtc();
}

DateTime? _optionalDate(Object? value) {
  if (value == null) return null;
  return _requiredDate(value);
}

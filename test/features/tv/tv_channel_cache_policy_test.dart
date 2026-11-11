import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:testagram/features/tv/tv_channel_cache_policy.dart';

void main() {
  final now = DateTime.utc(2026, 11, 11, 12);

  Map<String, dynamic> channel({
    String id = 'channel-1',
    String logo = 'https://images.testagram.site/logo.webp',
  }) => {
    'id': id,
    'name': 'Test TV',
    'description': 'Public channel',
    'logo_url': logo,
    'country_code': 'KE',
    'language': 'en',
    'categories': ['News', 'Local'],
    'website_url': 'https://broadcaster.example',
    'playback_type': 'hls',
    'availability': 'available',
    'health_checked_at': now.toIso8601String(),
    'updated_at': now.toIso8601String(),
  };

  test('caches normalized public metadata and never playback capabilities', () {
    final row = {
      ...channel(),
      'playback_url': 'https://media.example/master.m3u8?token=secret',
      'stream_url': 'https://origin.example/live.m3u8',
      'source_url': 'https://origin.example/live.m3u8',
      'provider_credentials': 'must-not-persist',
    };
    final safe = TvChannelCachePolicy.sanitizeChannels([row]);
    expect(safe, hasLength(1));
    expect(safe.single['id'], 'channel-1');
    final encoded = TvChannelCachePolicy.encode([row], now: now)!;
    expect(encoded, isNot(contains('playback_url')));
    expect(encoded, isNot(contains('stream_url')));
    expect(encoded, isNot(contains('secret')));
    expect(encoded, isNot(contains('must-not-persist')));
  });

  test('rejects unsafe metadata URLs and strips them from cache', () {
    for (final url in [
      'http://images.example/logo.png',
      'https://user:pass@images.example/logo.png',
      'https://images.example/logo.png?token=secret',
      'https://images.example/logo.png?X-Amz-Signature=secret',
      'https://images.example/logo.png#fragment',
    ]) {
      final safe = TvChannelCachePolicy.sanitizeChannels([channel(logo: url)]);
      expect(safe.single['logo_url'], isNull, reason: url);
    }
  });

  test('round trips fresh metadata and expires after the TTL', () {
    final encoded = TvChannelCachePolicy.encode([channel()], now: now);
    expect(encoded, isNotNull);
    expect(
      TvChannelCachePolicy.decode(encoded, now: now.add(const Duration(hours: 1))),
      hasLength(1),
    );
    expect(
      TvChannelCachePolicy.decode(encoded, now: now.add(const Duration(hours: 25))),
      isEmpty,
    );
  });

  test('rejects future-dated malformed and oversized cache entries', () {
    final encoded = TvChannelCachePolicy.encode([channel()], now: now)!;
    expect(
      TvChannelCachePolicy.decode(encoded, now: now.subtract(const Duration(hours: 1))),
      isEmpty,
    );
    expect(TvChannelCachePolicy.decode('{not json', now: now), isEmpty);
    expect(
      TvChannelCachePolicy.decode(
        List.filled(TvChannelCachePolicy.maxEncodedBytes + 1, 'x').join(),
        now: now,
      ),
      isEmpty,
    );
  });

  test('rejects oversized UTF-8 payloads', () {
    final huge = channel();
    huge['description'] = List.filled(300000, '💡').join();
    expect(TvChannelCachePolicy.encode([huge], now: now), isNull);
  });

  test('deduplicates and caps metadata rows', () {
    final rows = List.generate(300, (index) => channel(id: 'channel-$index'));
    expect(TvChannelCachePolicy.sanitizeChannels(rows), hasLength(250));
    expect(
      TvChannelCachePolicy.sanitizeChannels([channel(), channel()]),
      hasLength(1),
    );
  });

  test('rejects records without normalized TV identifiers and enums', () {
    expect(
      TvChannelCachePolicy.sanitizeChannels([{
        ...channel(),
        'playback_type': 'rtmp',
      }]),
      isEmpty,
    );
    expect(
      TvChannelCachePolicy.sanitizeChannels([{
        ...channel(),
        'availability': 'made-up',
      }]),
      isEmpty,
    );
    expect(
      TvChannelCachePolicy.sanitizeChannels([{
        ...channel(),
        'id': '',
      }]),
      isEmpty,
    );
  });

  test('does not accidentally serialize unknown fields', () {
    final encoded = TvChannelCachePolicy.encode([{
      ...channel(),
      'owner_email': 'private@example.test',
      'private_origin': 's3://private-bucket/key',
    }], now: now)!;
    expect(encoded, isNot(contains('owner_email')));
    expect(encoded, isNot(contains('private_origin')));
    expect(jsonDecode(encoded)['channels'].single.keys,
      isNot(contains('private_origin')));
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:testagram/features/tv/tv_channel_cache_policy.dart';

void main() {
  final now = DateTime.utc(2026, 10, 14, 12);

  Map<String, dynamic> channel({
    String url = 'https://streams.example/live.m3u8',
    String id = 'channel-1',
    String sourceType = 'catalog',
  }) =>
      {
        'id': id,
        'title': 'Test channel',
        'description': 'Public channel',
        'playback_url': url,
        'thumbnail_url': 'https://images.example/logo.png',
        '_sourceType': sourceType,
      };

  test('persists only public HTTPS catalogue URLs without signed credentials', () {
    final safe = TvChannelCachePolicy.sanitizeChannels([
      channel(),
      channel(id: 'signed', url: 'https://streams.example/live.m3u8?token=secret'),
      channel(id: 'http', url: 'http://streams.example/live.m3u8'),
      channel(id: 'user', sourceType: 'testagram-live'),
      channel(id: 'localhost', url: 'https://localhost/live.m3u8'),
      channel(id: 'private-ip', url: 'https://192.168.1.10/live.m3u8'),
    ]);

    expect(safe, hasLength(1));
    expect(safe.single['id'], 'channel-1');
    expect(jsonEncode(safe), isNot(contains('secret')));
  });

  test('round trips cached channels within the TTL', () {
    final encoded = TvChannelCachePolicy.encode([channel()], now: now);
    expect(encoded, isNotNull);

    final decoded = TvChannelCachePolicy.decode(
      encoded,
      now: now.add(const Duration(hours: 1)),
    );
    expect(decoded, hasLength(1));
    expect(decoded.single['playback_url'], 'https://streams.example/live.m3u8');
  });

  test('rejects expired, future-dated, malformed and oversized cache entries', () {
    final encoded = TvChannelCachePolicy.encode([channel()], now: now)!;
    expect(
      TvChannelCachePolicy.decode(
        encoded,
        now: now.add(const Duration(hours: 25)),
      ),
      isEmpty,
    );
    expect(
      TvChannelCachePolicy.decode(
        encoded,
        now: now.subtract(const Duration(hours: 1)),
      ),
      isEmpty,
    );
    expect(TvChannelCachePolicy.decode('{not json', now: now), isEmpty);

    final oversizedUtf8 = jsonEncode({
      'savedAt': now.millisecondsSinceEpoch,
      'channels': [
        {'id': 'large', 'title': List.filled(300000, '😀').join()},
      ],
    });
    expect(
      oversizedUtf8.length,
      lessThan(TvChannelCachePolicy.maxEncodedBytes),
    );
    expect(
      utf8.encode(oversizedUtf8).length,
      greaterThan(TvChannelCachePolicy.maxEncodedBytes),
    );
    expect(TvChannelCachePolicy.decode(oversizedUtf8, now: now), isEmpty);
  });

  test('caps the number of persisted channels and rejects URL credentials', () {
    final rows = List.generate(
      300,
      (index) => channel(id: 'channel-$index'),
    );
    expect(TvChannelCachePolicy.sanitizeChannels(rows), hasLength(250));

    expect(
      TvChannelCachePolicy.isPublicCacheUrl(
        'https://user:pass@streams.example/live.m3u8',
      ),
      isFalse,
    );
    expect(
      TvChannelCachePolicy.isPublicCacheUrl(
        'https://streams.example/live.m3u8?X-Amz-Signature=secret',
      ),
      isFalse,
    );
    expect(
      TvChannelCachePolicy.isPublicCacheUrl('https://[::1]/live.m3u8'),
      isFalse,
    );
  });

  test('drops duplicate channel identities and bounds display text', () {
    final safe = TvChannelCachePolicy.sanitizeChannels([
      channel(),
      channel(url: 'https://streams.example/other.m3u8'),
      channel(id: 'long-title')..['title'] = List.filled(200, 'x').join(),
    ]);

    expect(safe, hasLength(2));
    expect((safe.last['title'] as String).length, 160);
  });
}

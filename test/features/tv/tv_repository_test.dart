import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:testagram/core/backend_api.dart';
import 'package:testagram/features/tv/tv_models.dart';
import 'package:testagram/features/tv/tv_repository.dart';

void main() {
  final now = DateTime.utc(2026, 11, 11, 12);

  Map<String, dynamic> channel({
    String id = 'channel-1',
    String name = 'Test TV',
    String logo = 'https://images.testagram.site/tv/logo.webp',
  }) => {
    'id': id,
    'name': name,
    'logo_url': logo,
    'country_code': 'KE',
    'language': 'en',
    'categories': ['News', 'Local'],
    'playback_type': 'hls',
    'availability': 'available',
    'health_checked_at': now.toIso8601String(),
    'updated_at': now.toIso8601String(),
  };

  test('parses a bounded normalized catalogue without playback URLs', () {
    final page = TvChannelPage.fromJson({
      'items': [channel()],
      'next_cursor': 'next-1',
    });
    expect(page.items.single.id, 'channel-1');
    expect(page.items.single.logoUrl?.scheme, 'https');
    expect(page.items.single.categories, ['News', 'Local']);
    expect(page.nextCursor, 'next-1');
  });

  test('rejects malformed channel and non-HTTPS metadata URL', () {
    expect(
      () => TvChannel.fromJson({...channel(), 'logo_url': 'http://bad.example/logo'}),
      throwsFormatException,
    );
    expect(
      () => TvChannel.fromJson({...channel(), 'availability': 'unknown-value'}),
      throwsFormatException,
    );
    expect(
      () => TvChannelPage.fromJson({'items': List.filled(51, channel())}),
      throwsFormatException,
    );
  });

  test('playback grant requires allowlisted HTTPS host and short future expiry', () {
    final valid = TvPlaybackGrant.fromJson({
      'channel_id': 'channel-1',
      'playback_url': 'https://media.testagram.site/hls/tokenized/master.m3u8',
      'expires_at': now.add(const Duration(minutes: 5)).toIso8601String(),
      'playback_type': 'hls',
      'required_headers': {'X-Playback-Token': 'opaque-token'},
    }, allowedHosts: {'media.testagram.site'}, now: now);
    expect(valid.playbackUrl.host, 'media.testagram.site');
    expect(valid.requiredHeaders['X-Playback-Token'], 'opaque-token');

    for (final url in [
      'http://media.testagram.site/stream.m3u8',
      'https://evil.example/stream.m3u8',
      'https://user:pass@media.testagram.site/stream.m3u8',
      'https://media.testagram.site/stream.m3u8#fragment',
    ]) {
      expect(
        () => TvPlaybackGrant.fromJson({
          'channel_id': 'channel-1',
          'playback_url': url,
          'expires_at': now.add(const Duration(minutes: 5)).toIso8601String(),
          'playback_type': 'hls',
        }, allowedHosts: {'media.testagram.site'}, now: now),
        throwsFormatException,
      );
    }

    expect(
      () => TvPlaybackGrant.fromJson({
        'channel_id': 'channel-1',
        'playback_url': 'https://media.testagram.site/stream.m3u8',
        'expires_at': now.add(const Duration(hours: 1)).toIso8601String(),
        'playback_type': 'hls',
      }, allowedHosts: {'media.testagram.site'}, now: now),
      throwsFormatException,
    );
  });

  test('repository uses authenticated Backend routes and never accepts a source URL', () async {
    final requests = <http.Request>[];
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getJwt: () async => 'appwrite-jwt',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/tv/channels') {
          return http.Response(jsonEncode({
            'ok': true,
            'data': {'items': [channel()], 'next_cursor': null},
            'error': null,
            'request_id': 'req-1',
          }), 200);
        }
        if (request.url.path == '/api/tv/channels/channel-1') {
          return http.Response(jsonEncode({
            'ok': true, 'data': channel(), 'error': null, 'request_id': 'req-2',
          }), 200);
        }
        return http.Response(jsonEncode({
          'ok': true,
          'data': {
            'channel_id': 'channel-1',
            'playback_url': 'https://media.testagram.site/hls/signed/master.m3u8',
            'expires_at': now.add(const Duration(minutes: 3)).toIso8601String(),
            'playback_type': 'hls',
          },
          'error': null,
          'request_id': 'req-3',
        }), 200);
      }),
    );
    final repository = TvRepository(
      api: api,
      allowedPlaybackHosts: {'media.testagram.site'},
    );

    final page = await repository.listChannels(limit: 10, country: 'ke', category: 'news');
    final detail = await repository.getChannel('channel-1');
    final grant = await repository.requestPlayback('channel-1', now: now);

    expect(page.items.single.name, 'Test TV');
    expect(detail.id, 'channel-1');
    expect(grant.playbackUrl.host, 'media.testagram.site');
    expect(requests, hasLength(3));
    expect(requests[0].url.path, '/api/tv/channels');
    expect(requests[0].url.queryParameters['country'], 'KE');
    expect(requests.every((request) =>
      request.headers['authorization'] == 'Bearer appwrite-jwt'), isTrue);
    expect(requests[2].method, 'POST');
    expect(requests[2].url.path, '/api/tv/channels/channel-1/playback');
    expect(jsonDecode(requests[2].body), {'playback_profile': 'auto'});
    api.close();
  });

  test('Backend API rejects invalid TV filters and playback profile locally', () {
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getJwt: () async => 'jwt',
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    expect(() => api.listTvChannels(limit: 51), throwsArgumentError);
    expect(() => api.listTvChannels(country: 'KEN'), throwsArgumentError);
    expect(() => api.getTvChannel(' '), throwsArgumentError);
    expect(() => api.createTvPlaybackGrant('channel-1', playbackProfile: 'ultra'), throwsArgumentError);
    api.close();
  });
}

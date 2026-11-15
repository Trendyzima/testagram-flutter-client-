import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:testagram/core/video_api.dart';

void main() {
  test('video feed exposes only public, ready records', () async {
    final api = VideoApi(
      baseUri: Uri.parse('https://video.example.test'),
      getJwt: () async => 'session-jwt',
      client: MockClient((request) async {
        expect(request.url.path, '/v1/feed');
        return http.Response(jsonEncode([
          {'id': 'ready-public', 'status': 'ready', 'visibility': 'public'},
          {'id': 'processing', 'status': 'processing', 'visibility': 'public'},
          {'id': 'private', 'status': 'ready', 'visibility': 'private'},
          {'id': '', 'status': 'ready', 'visibility': 'public'},
        ]), 200);
      }),
    );

    final items = await api.feed();
    expect(items.map((item) => item['id']), ['ready-public']);
    expect(api.manifestUri('video-1').path, '/v1/videos/video-1/manifest');
    api.close();
  });

  test('video likes require and forward the active session JWT', () async {
    final api = VideoApi(
      baseUri: Uri.parse('https://video.example.test'),
      getJwt: () async => 'active-session-token',
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/v1/videos/abc/like');
        expect(request.headers['authorization'], 'Bearer active-session-token');
        return http.Response(jsonEncode({'liked': true}), 200);
      }),
    );

    expect(await api.like('abc'), isTrue);
    api.close();
  });

  test('video likes fail closed when there is no session token', () async {
    final api = VideoApi(
      baseUri: Uri.parse('https://video.example.test'),
      getJwt: () async => '',
      client: MockClient((_) async => http.Response('{}', 200)),
    );

    await expectLater(api.like('abc'), throwsA(isA<VideoApiException>()));
    api.close();
  });
}

import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:testagram/core/video_api.dart';

void main() {
  test('video feed exposes only public, ready records', () async {
    final api = VideoApi(
      baseUri: Uri.parse('https://video.example.test'),
      getAccessToken: ({bool forceRefresh = false}) async => 'session-jwt',
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
      getAccessToken: ({bool forceRefresh = false}) async => 'active-session-token',
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

  test('video likes refresh a native session once after a 401', () async {
    final refreshCalls = <bool>[];
    var requestCount = 0;
    final api = VideoApi(
      baseUri: Uri.parse('https://video.example.test'),
      getAccessToken: ({bool forceRefresh = false}) async {
        refreshCalls.add(forceRefresh);
        return forceRefresh ? 'fresh-native-access-token' : 'expired-native-access-token';
      },
      client: MockClient((request) async {
        requestCount++;
        if (requestCount == 1) {
          expect(request.headers['authorization'], 'Bearer expired-native-access-token');
          return http.Response(jsonEncode({'error': 'expired'}), 401);
        }
        expect(request.headers['authorization'], 'Bearer fresh-native-access-token');
        return http.Response(jsonEncode({'liked': true}), 200);
      }),
    );

    expect(await api.like('abc'), isTrue);
    expect(requestCount, 2);
    expect(refreshCalls, [false, true]);
    api.close();
  });

  test('video likes fail closed when there is no session token', () async {
    final api = VideoApi(
      baseUri: Uri.parse('https://video.example.test'),
      getAccessToken: ({bool forceRefresh = false}) async => '',
      client: MockClient((_) async => http.Response('{}', 200)),
    );

    await expectLater(api.like('abc'), throwsA(isA<VideoApiException>()));
    api.close();
  });

  test('creator channel and video status actions use native authorization', () async {
    final requests = <http.Request>[];
    final api = VideoApi(
      baseUri: Uri.parse('https://video.example.test'),
      getAccessToken: ({bool forceRefresh = false}) async => 'native-video-token',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/v1/channels' && request.method == 'GET') {
          return http.Response(jsonEncode({
            'items': [{'id': 'channel-1', 'handle': 'creator', 'name': 'Creator'}],
          }), 200);
        }
        if (request.url.path == '/v1/channels' && request.method == 'POST') {
          return http.Response(jsonEncode({'id': 'channel-2'}), 201);
        }
        if (request.url.path == '/v1/videos/video-1/status') {
          return http.Response(jsonEncode({'id': 'video-1', 'status': 'ready', 'visibility': 'private'}), 200);
        }
        if (request.url.path == '/v1/videos/video-1/publish') {
          return http.Response(jsonEncode({'status': 'public'}), 200);
        }
        return http.Response('not found', 404);
      }),
    );

    expect((await api.channels()).single['id'], 'channel-1');
    expect((await api.createChannel(handle: '@creator2', name: 'Creator Two'))['id'], 'channel-2');
    expect((await api.videoStatus('video-1'))['status'], 'ready');
    expect((await api.publishVideo('video-1'))['status'], 'public');
    expect(requests.map((request) => request.url.path), [
      '/v1/channels',
      '/v1/channels',
      '/v1/videos/video-1/status',
      '/v1/videos/video-1/publish',
    ]);
    for (final request in requests) {
      expect(request.headers['authorization'], 'Bearer native-video-token');
    }
    expect(jsonDecode(requests[1].body)['handle'], 'creator2');
    api.close();
  });

  test('creator upload streams a selected video as authenticated multipart', () async {
    final directory = await Directory.systemTemp.createTemp('testagram-video-upload-');
    final file = File('${directory.path}/clip.mp4');
    await file.writeAsBytes([0, 1, 2, 3, 4]);
    try {
      final api = VideoApi(
        baseUri: Uri.parse('https://video.example.test'),
        getAccessToken: ({bool forceRefresh = false}) async => 'native-video-token',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/v1/videos');
          expect(request.headers['authorization'], 'Bearer native-video-token');
          expect(request.headers['content-type'], contains('multipart/form-data'));
          expect(request.body, contains('channel_id'));
          expect(request.body, contains('channel-1'));
          expect(request.body, contains('A creator clip'));
          expect(request.body, contains('clip.mp4'));
          return http.Response(jsonEncode({'id': 'video-1', 'status': 'queued'}), 202);
        }),
      );

      final result = await api.uploadVideo(
        filePath: file.path,
        channelId: 'channel-1',
        title: 'A creator clip',
        description: 'Test upload',
      );
      expect(result['id'], 'video-1');
      expect(result['status'], 'queued');
      api.close();
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('creator channel validation rejects unsafe handles before network access', () async {
    var requests = 0;
    final api = VideoApi(
      baseUri: Uri.parse('https://video.example.test'),
      getAccessToken: ({bool forceRefresh = false}) async => 'token',
      client: MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }),
    );
    await expectLater(
      api.createChannel(handle: 'bad handle', name: 'Channel'),
      throwsA(isA<VideoApiException>()),
    );
    expect(requests, 0);
    api.close();
  });

}

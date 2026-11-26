import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:testagram/core/backend_api.dart';

void main() {
  test('uploadPublicVideo uses the authenticated verified media lifecycle', () async {
    final requests = <http.Request>[];
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getAccessToken: ({bool forceRefresh = false}) async => 'session-jwt',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/media/upload-intent') {
          return http.Response(jsonEncode({
            'ok': true,
            'data': {
              'key': 'users/test-user/0123456789abcdef0123456789abcdef',
              'url': '/api/media/upload?key=users%2Ftest-user%2F0123456789abcdef0123456789abcdef',
            },
          }), 201);
        }
        if (request.url.path == '/api/media/upload') {
          return http.Response('', 204);
        }
        if (request.url.path == '/api/media/complete') {
          return http.Response(jsonEncode({
            'ok': true,
            'data': {
              'key': 'users/test-user/0123456789abcdef0123456789abcdef',
              'status': 'ready',
              'media_type': 'video',
              'content_type': 'video/mp4',
            },
          }), 200);
        }
        return http.Response(jsonEncode({'ok': false}), 404);
      }),
    );

    final asset = await api.uploadPublicVideo(
      name: 'short.mp4',
      contentType: 'video/mp4',
      bytes: List<int>.filled(1024, 7),
    );

    expect(asset['status'], 'ready');
    expect(asset['media_type'], 'video');
    final intent = requests.firstWhere((request) => request.url.path == '/api/media/upload-intent');
    expect(intent.method, 'POST');
    expect(intent.headers['authorization'], 'Bearer session-jwt');
    expect(jsonDecode(intent.body), {
      'name': 'short.mp4',
      'content_type': 'video/mp4',
      'visibility': 'public',
      'size_bytes': 1024,
    });
    final upload = requests.firstWhere((request) => request.url.path == '/api/media/upload');
    expect(upload.method, 'PUT');
    expect(upload.headers['content-type'], 'video/mp4');
    final complete = requests.firstWhere((request) => request.url.path == '/api/media/complete');
    expect(jsonDecode(complete.body)['content_type'], 'video/mp4');
    expect(jsonDecode(complete.body)['checksum_sha256'], isNotEmpty);
    api.close();
  });

  test('uploadPublicVideo rejects unsupported media before making a request', () async {
    var requestCount = 0;
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getAccessToken: ({bool forceRefresh = false}) async => 'session-jwt',
      client: MockClient((request) async {
        requestCount++;
        return http.Response('{}', 500);
      }),
    );

    await expectLater(
      api.uploadPublicVideo(
        name: 'clip.mov',
        contentType: 'video/quicktime',
        bytes: [1, 2, 3],
      ),
      throwsA(isA<BackendApiException>()),
    );
    expect(requestCount, 0);
    api.close();
  });

  test('creator video channel and status actions use canonical Backend routes', () async {
    final requests = <http.Request>[];
    final api = BackendApi(
      baseUri: Uri.parse('https://api.example.test'),
      getAccessToken: ({bool forceRefresh = false}) async => 'native-session-token',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/video/channels' && request.method == 'GET') {
          return http.Response(jsonEncode({
            'items': [{'id': 'channel-1', 'handle': 'creator', 'name': 'Creator'}],
          }), 200);
        }
        if (request.url.path == '/api/video/channels' && request.method == 'POST') {
          return http.Response(jsonEncode({'id': 'channel-2'}), 201);
        }
        if (request.url.path == '/api/video/uploads/video-1') {
          return http.Response(jsonEncode({'id': 'video-1', 'status': 'ready', 'visibility': 'private'}), 200);
        }
        if (request.url.path == '/api/video/uploads/video-1/publish') {
          return http.Response(jsonEncode({'id': 'video-1', 'visibility': 'public'}), 200);
        }
        return http.Response('not found', 404);
      }),
    );

    expect((await api.getCreatorVideoChannels()).single['id'], 'channel-1');
    expect((await api.createCreatorVideoChannel(handle: '@creator2', name: 'Creator Two'))['id'], 'channel-2');
    expect((await api.getCreatorVideoStatus('video-1'))['status'], 'ready');
    expect((await api.publishCreatorVideo('video-1'))['visibility'], 'public');
    expect(requests.map((request) => request.url.path), [
      '/api/video/channels',
      '/api/video/channels',
      '/api/video/uploads/video-1',
      '/api/video/uploads/video-1/publish',
    ]);
    for (final request in requests) {
      expect(request.headers['authorization'], 'Bearer native-session-token');
    }
    expect(jsonDecode(requests[1].body)['handle'], 'creator2');
    api.close();
  });

  test('creator video upload streams multipart through the Backend', () async {
    final directory = await Directory.systemTemp.createTemp('testagram-backend-video-');
    final file = File('${directory.path}/clip.mp4');
    await file.writeAsBytes([0, 1, 2, 3, 4]);
    try {
      final api = BackendApi(
        baseUri: Uri.parse('https://api.example.test'),
        getAccessToken: ({bool forceRefresh = false}) async => 'native-session-token',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/video/uploads');
          expect(request.headers['authorization'], 'Bearer native-session-token');
          expect(request.headers['content-type'], contains('multipart/form-data'));
          expect(request.body, contains('channel_id'));
          expect(request.body, contains('channel-1'));
          expect(request.body, contains('A creator clip'));
          expect(request.body, contains('clip.mp4'));
          return http.Response(jsonEncode({'id': 'video-1', 'status': 'queued'}), 202);
        }),
      );

      final result = await api.uploadCreatorVideo(
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

  test('creator video upload refreshes a rejected native token once', () async {
    final directory = await Directory.systemTemp.createTemp('testagram-video-refresh-');
    final file = File('${directory.path}/clip.mp4');
    await file.writeAsBytes([1, 2, 3]);
    var refreshCalls = 0;
    var requestCalls = 0;
    try {
      final api = BackendApi(
        baseUri: Uri.parse('https://api.example.test'),
        getAccessToken: ({bool forceRefresh = false}) async {
          if (forceRefresh) refreshCalls++;
          return forceRefresh ? 'rotated-native-token' : 'expired-native-token';
        },
        client: MockClient((request) async {
          requestCalls++;
          if (requestCalls == 1) {
            return http.Response(jsonEncode({'error': 'AUTH_REQUIRED'}), 401);
          }
          expect(request.headers['authorization'], 'Bearer rotated-native-token');
          return http.Response(jsonEncode({'id': 'video-2', 'status': 'queued'}), 202);
        }),
      );
      final result = await api.uploadCreatorVideo(
        filePath: file.path,
        channelId: 'channel-1',
        title: 'Refresh token upload',
      );
      expect(result['id'], 'video-2');
      expect(refreshCalls, 1);
      expect(requestCalls, 2);
      api.close();
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('creator channel validation rejects invalid handles before network access', () async {
    var requests = 0;
    final api = BackendApi(
      baseUri: Uri.parse('https://api.example.test'),
      getAccessToken: ({bool forceRefresh = false}) async => 'native-session-token',
      client: MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }),
    );
    expect(
      () => api.createCreatorVideoChannel(handle: 'bad handle', name: 'Channel'),
      throwsArgumentError,
    );
    expect(requests, 0);
    api.close();
  });


  test('video feed, playback manifest, views, likes and comments stay on Backend routes', () async {
    final requests = <http.Request>[];
    final api = BackendApi(
      baseUri: Uri.parse('https://api.example.test'),
      getAccessToken: ({bool forceRefresh = false}) async => 'native-video-token',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/video/feed') {
          return http.Response(jsonEncode([{'id': 'video-1', 'status': 'ready', 'visibility': 'public'}]), 200);
        }
        if (request.url.path.endsWith('/view')) {
          return http.Response(jsonEncode({'counted': true}), 202);
        }
        if (request.url.path.endsWith('/like')) {
          return http.Response(jsonEncode({'liked': true}), 200);
        }
        if (request.url.path.endsWith('/comments') && request.method == 'GET') {
          return http.Response(jsonEncode([{'id': 'comment-1', 'body': 'Nice'}]), 200);
        }
        if (request.url.path.endsWith('/comments') && request.method == 'POST') {
          return http.Response(jsonEncode({'id': 'comment-2'}), 201);
        }
        return http.Response('{}', 404);
      }),
    );

    expect((await api.getVideoFeed()).single['id'], 'video-1');
    expect(api.videoManifestUri('video-1').path, '/api/video/uploads/video-1/manifest');
    await api.recordVideoView('video-1', 'session-123');
    expect(await api.likeVideo('video-1'), isTrue);
    expect((await api.getVideoComments('video-1')).single['body'], 'Nice');
    await api.addVideoComment('video-1', 'Hello');
    expect(requests.map((request) => request.url.path), [
      '/api/video/feed',
      '/api/video/uploads/video-1/view',
      '/api/video/uploads/video-1/like',
      '/api/video/uploads/video-1/comments',
      '/api/video/uploads/video-1/comments',
    ]);
    expect(requests[0].headers.containsKey('authorization'), isFalse);
    expect(requests[1].headers.containsKey('authorization'), isFalse);
    expect(requests[1].headers['x-playback-session'], 'session-123');
    expect(requests[2].headers['authorization'], 'Bearer native-video-token');
    expect(requests[3].headers['authorization'], 'Bearer native-video-token');
    expect(jsonDecode(requests[4].body)['body'], 'Hello');
    api.close();
  });


  test('public TV feed, manifest and views work without a native account session', () async {
    final requests = <http.Request>[];
    final api = BackendApi(
      baseUri: Uri.parse('https://api.example.test'),
      getAccessToken: ({bool forceRefresh = false}) async => null,
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/video/feed') return http.Response('[]', 200);
        if (request.url.path.endsWith('/view')) return http.Response(jsonEncode({'counted': true}), 202);
        return http.Response('not found', 404);
      }),
    );
    expect(await api.getVideoFeed(), isEmpty);
    expect(api.videoManifestUri('video-1').path, '/api/video/uploads/video-1/manifest');
    expect(await api.videoPlaybackHeaders(), isEmpty);
    await api.recordVideoView('video-1', 'playback-session-123');
    expect(requests.map((r) => r.url.path), ['/api/video/feed', '/api/video/uploads/video-1/view']);
    for (final request in requests) {
      expect(request.headers.containsKey('authorization'), isFalse);
    }
    expect(requests.last.headers['x-playback-session'], 'playback-session-123');
    api.close();
  });

  test('public playback session identifiers are validated before requests', () async {
    var requests = 0;
    final api = BackendApi(
      baseUri: Uri.parse('https://api.example.test'),
      getAccessToken: ({bool forceRefresh = false}) async => null,
      client: MockClient((request) async {
        requests++;
        return http.Response(jsonEncode({'counted': true}), 202);
      }),
    );
    await expectLater(
      api.recordVideoView('video-1', 'bad session'),
      throwsArgumentError,
    );
    expect(requests, 0);
    api.close();
  });

  test('creator video deletion accepts a 204 response and uses the authenticated route', () async {
    http.Request? captured;
    final api = BackendApi(
      baseUri: Uri.parse('https://api.example.test'),
      getAccessToken: ({bool forceRefresh = false}) async => 'native-session-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response('', 204);
      }),
    );

    await api.deleteCreatorVideo('2c6e2d3a-61c1-4e8f-8d41-92f1a0d13b62');

    expect(captured?.method, 'DELETE');
    expect(captured?.url.path, '/api/video/uploads/2c6e2d3a-61c1-4e8f-8d41-92f1a0d13b62');
    expect(captured?.headers['authorization'], 'Bearer native-session-token');
    api.close();
  });

  test('creator video deletion rejects malformed IDs before making a request', () async {
    var requestCount = 0;
    final api = BackendApi(
      baseUri: Uri.parse('https://api.example.test'),
      getAccessToken: ({bool forceRefresh = false}) async => 'native-session-token',
      client: MockClient((request) async {
        requestCount++;
        return http.Response('', 204);
      }),
    );

    await expectLater(api.deleteCreatorVideo('../other-video'), throwsArgumentError);
    expect(requestCount, 0);
    api.close();
  });

  test('creator video library uses the authenticated Backend list route', () async {
    http.Request? captured;
    final api = BackendApi(
      baseUri: Uri.parse('https://api.example.test'),
      getAccessToken: ({bool forceRefresh = false}) async => 'native-session-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode({
          'items': [
            {'id': 'video-1', 'title': 'My upload', 'status': 'ready'}
          ],
        }), 200);
      }),
    );

    final videos = await api.getCreatorVideos();

    expect(videos, hasLength(1));
    expect(videos.single['title'], 'My upload');
    expect(captured?.method, 'GET');
    expect(captured?.url.path, '/api/video/uploads');
    expect(captured?.headers['authorization'], 'Bearer native-session-token');
    api.close();
  });


}

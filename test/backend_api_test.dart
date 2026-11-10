import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:testagram/core/backend_api.dart';

void main() {
  group('BackendApi', () {
    test('loads the canonical post feed using an Appwrite JWT', () async {
      late http.Request captured;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'appwrite-session-jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({
            'ok': true,
            'data': {
              'posts': [{'id': 'post-1', 'content': 'Hello Testagram'}],
              'next_cursor': 'cursor-2',
              'has_more': true,
            },
            'error': null,
          }), 200);
        }),
      );

      final response = await api.getHomeFeed(limit: 20, followingOnly: true);
      expect(captured.method, 'GET');
      expect(captured.url.path, '/api/feed/home');
      expect(captured.url.queryParameters['following_only'], 'true');
      expect(captured.headers['authorization'], 'Bearer appwrite-session-jwt');
      expect((response['data'] as Map)['posts'], hasLength(1));
      api.close();
    });

    test('loads a privacy-filtered post detail using the Appwrite JWT', () async {
      late http.Request captured;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'appwrite-session-jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({
            'ok': true,
            'data': {
              'id': '00000000-0000-4000-8000-000000000001',
              'content': 'A privacy-filtered post',
              'likes_count': 3,
            },
          }), 200);
        }),
      );

      final response = await api.getPost('00000000-0000-4000-8000-000000000001');
      expect(captured.method, 'GET');
      expect(captured.url.path,
          '/api/social/posts/00000000-0000-4000-8000-000000000001');
      expect(captured.headers['authorization'], 'Bearer appwrite-session-jwt');
      expect((response['data'] as Map)['content'], 'A privacy-filtered post');
      api.close();
    });

    test('sends reactions only through the authenticated social API', () async {
      late http.Request captured;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'ok': true, 'data': {'is_liked': true}}), 200);
        }),
      );

      await api.reactToPost('00000000-0000-4000-8000-000000000001');
      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/social/posts/00000000-0000-4000-8000-000000000001/reaction');
      expect(jsonDecode(captured.body), {'emoji': '❤️'});
      expect(captured.headers['authorization'], 'Bearer jwt');
      api.close();
    });

    test('creates replies through the canonical social API', () async {
      late http.Request captured;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'ok': true, 'data': {'id': 'reply-1'}}), 201);
        }),
      );

      await api.createPostReply('post-id', 'A reply');
      expect(captured.url.path, '/api/social/posts/post-id/replies');
      expect(jsonDecode(captured.body), {'content': 'A reply'});
      api.close();
    });

    test('searches people and posts through the Backend search route', () async {
      late http.Request captured;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'ok': true, 'data': {'users': [], 'posts': []}}), 200);
        }),
      );
      await api.search(query: 'testagram', kind: 'all');
      expect(captured.url.path, '/api/search');
      expect(captured.url.queryParameters['q'], 'testagram');
      expect(captured.url.queryParameters['kind'], 'all');
      api.close();
    });

    test('creates threads through the dedicated threads endpoint', () async {
      late http.Request captured;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'ok': true, 'data': {'id': 'thread-1'}}), 201);
        }),
      );
      await api.createThread('A separate thread');
      expect(captured.url.path, '/api/threads');
      expect(jsonDecode(captured.body), {'body': 'A separate thread', 'visibility': 'public'});
      api.close();
    });

    test('lists public polls using bounded offset pagination', () async {
      late http.Request captured;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({
            'ok': true,
            'data': {'items': [], 'next_offset': 20, 'has_more': true},
          }), 200);
        }),
      );

      await api.listPolls(limit: 20, offset: 20);
      expect(captured.method, 'GET');
      expect(captured.url.path, '/api/social/polls');
      expect(captured.url.queryParameters, {'limit': '20', 'offset': '20'});
      expect(captured.headers['authorization'], 'Bearer jwt');
      api.close();
    });

    test('creates polls using the validated Backend payload', () async {
      late http.Request captured;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'ok': true, 'data': {'id': 'poll-1'}}), 201);
        }),
      );

      await api.createPoll(
        question: 'Which feature next?',
        description: 'Choose one',
        options: ['Messages', 'Communities'],
      );
      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/social/polls');
      expect(jsonDecode(captured.body), {
        'question': 'Which feature next?',
        'description': 'Choose one',
        'options': ['Messages', 'Communities'],
      });
      api.close();
    });

    test('votes on a poll using the selected option UUID', () async {
      late http.Request captured;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'ok': true, 'data': {'voted': true}}), 200);
        }),
      );

      await api.votePoll(
        '00000000-0000-4000-8000-000000000001',
        '00000000-0000-4000-8000-000000000002',
      );
      expect(captured.method, 'POST');
      expect(captured.url.path,
          '/api/social/polls/00000000-0000-4000-8000-000000000001/vote');
      expect(jsonDecode(captured.body), {
        'option_id': '00000000-0000-4000-8000-000000000002',
      });
      api.close();
    });

    test('paginates notifications using the Backend cursor', () async {
      late http.Request captured;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'ok': true, 'data': {'items': [], 'next_cursor': ''}}), 200);
        }),
      );
      await api.listNotifications(limit: 30, cursor: 'opaque-cursor');
      expect(captured.url.path, '/api/social/notifications');
      expect(captured.url.queryParameters['limit'], '30');
      expect(captured.url.queryParameters['cursor'], 'opaque-cursor');
      api.close();
    });

    test('loads saved threads using the canonical thread tab and cursor', () async {
      late http.Request captured;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'ok': true, 'data': {'items': [], 'next_cursor': '', 'has_more': false}}), 200);
        }),
      );
      await api.getThreads(tab: 'saved', limit: 20, cursor: 'thread-cursor');
      expect(captured.url.path, '/api/threads');
      expect(captured.url.queryParameters['tab'], 'saved');
      expect(captured.url.queryParameters['cursor'], 'thread-cursor');
      expect(captured.headers['authorization'], 'Bearer jwt');
      api.close();
    });


    test('uploads an image through the bounded gateway and verifies its checksum', () async {
      final requests = <http.Request>[];
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'jwt',
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/api/media/upload-intent') {
            return http.Response(jsonEncode({
              'ok': true,
              'data': {'key': 'media/key-1', 'url': '/api/media/upload?key=media%2Fkey-1'},
            }), 201);
          }
          if (request.method == 'PUT') return http.Response('', 204);
          if (request.url.path == '/api/media/complete') {
            return http.Response(jsonEncode({
              'ok': true,
              'data': {'key': 'media/key-1', 'public_url': 'https://cdn.testagram.site/key-1'},
            }), 201);
          }
          return http.Response('unexpected request', 500);
        }),
      );

      final asset = await api.uploadPublicImage(
        name: 'photo.png',
        contentType: 'image/png',
        bytes: [1, 2, 3],
      );

      expect(asset['key'], 'media/key-1');
      expect(requests.map((request) => request.method), ['POST', 'PUT', 'POST']);
      expect(requests[0].url.path, '/api/media/upload-intent');
      expect(jsonDecode(requests[0].body), {
        'name': 'photo.png',
        'content_type': 'image/png',
        'visibility': 'public',
        'size_bytes': 3,
      });
      expect(requests[1].url.path, '/api/media/upload');
      expect(requests[1].headers['authorization'], 'Bearer jwt');
      expect(requests[1].headers['content-type'], 'image/png');
      expect(requests[1].bodyBytes, [1, 2, 3]);
      expect(jsonDecode(requests[2].body), {
        'key': 'media/key-1',
        'visibility': 'public',
        'content_type': 'image/png',
        'checksum_sha256': '039058c6f2c0cb492c533b0a4d14ef77cc0f78abccced5287d84a1a2011cfb81',
      });
      api.close();
    });

    test('attaches only a ready media key through the thread media endpoint', () async {
      late http.Request captured;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'ok': true, 'data': {'attached': true}}), 200);
        }),
      );

      await api.attachThreadMedia('thread-1', 'media/key-1');
      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/threads/thread-1/media');
      expect(jsonDecode(captured.body), {'key': 'media/key-1'});
      api.close();
    });

    test('rejects unsupported image types before creating an upload intent', () async {
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'jwt',
        client: MockClient((_) async => http.Response('{}', 200)),
      );

      await expectLater(
        api.uploadPublicImage(name: 'bad.svg', contentType: 'image/svg+xml', bytes: [1]),
        throwsA(isA<BackendApiException>()),
      );
      api.close();
    });

    test('normalizes backend request timeouts into a readable API error', () async {
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'jwt',
        client: MockClient((_) async {
          throw TimeoutException('test timeout');
        }),
      );

      await expectLater(
        api.getHomeFeed(),
        throwsA(isA<BackendApiException>().having(
          (error) => error.message,
          'message',
          'The request timed out. Check your connection and try again.',
        )),
      );
      api.close();
    });

    test('surfaces structured Backend errors', () async {
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'jwt',
        client: MockClient((_) async => http.Response(
          jsonEncode({'error': {'code': 'AUTH_REQUIRED', 'message': 'Sign in again'}}),
          401,
        )),
      );
      await expectLater(
        api.getHomeFeed(),
        throwsA(isA<BackendApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.message, 'message', 'Sign in again')),
      );
      api.close();
    });
  });
}

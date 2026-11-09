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

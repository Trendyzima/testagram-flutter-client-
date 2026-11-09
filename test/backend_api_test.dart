import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:testagram/core/backend_api.dart';

void main() {
  group('BackendApi', () {
    test('loads the canonical thread timeline with an Appwrite JWT', () async {
      late http.Request captured;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'appwrite-session-jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'ok': true,
              'data': {
                'items': [
                  {'id': 'thread-1', 'body': 'Hello Testagram'}
                ],
                'next_cursor': '',
                'has_more': false,
              },
              'error': null,
            }),
            200,
          );
        }),
      );

      final response = await api.getHomeFeed();

      expect(captured.method, 'GET');
      expect(captured.url.path, '/api/threads');
      expect(captured.url.queryParameters['tab'], 'for-you');
      expect(captured.headers['authorization'], 'Bearer appwrite-session-jwt');
      expect((response['data'] as Map)['items'], hasLength(1));
      api.close();
    });

    test('creates a thread using the Backend request contract', () async {
      late http.Request captured;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'ok': true,
              'data': {'id': 'thread-2', 'body': 'A new post'},
              'error': null,
            }),
            201,
          );
        }),
      );

      await api.createPost(content: 'A new post');

      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/threads');
      expect(jsonDecode(captured.body), {'body': 'A new post', 'visibility': 'public'});
      api.close();
    });

    test('surfaces Backend errors rather than fabricating success', () async {
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
        throwsA(isA<BackendApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
      api.close();
    });
  });
}

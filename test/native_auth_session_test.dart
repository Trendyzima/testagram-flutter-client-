import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:testagram/core/native_auth_session.dart';

class MemoryTokenStore implements NativeAuthTokenStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

void main() {
  group('NativeAuthSession', () {
    test('stores native tokens and rotates refresh token before expiry', () async {
      final store = MemoryTokenStore();
      var now = DateTime.utc(2026, 11, 15, 12);
      var refreshCalls = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/api/auth/login') {
          expect(jsonDecode(request.body), {
            'email': 'user@example.com',
            'password': 'correct horse battery staple',
          });
          return http.Response(jsonEncode({
            'ok': true,
            'data': {
              'access_token': 'access-1',
              'refresh_token': 'r' * 43,
              'expires_in': 900,
              'token_type': 'Bearer',
            },
          }), 200);
        }
        if (request.url.path == '/api/auth/refresh') {
          refreshCalls++;
          expect(jsonDecode(request.body), {'refresh_token': 'r' * 43});
          return http.Response(jsonEncode({
            'ok': true,
            'data': {
              'access_token': 'access-2',
              'refresh_token': 's' * 43,
              'expires_in': 900,
              'token_type': 'Bearer',
            },
          }), 200);
        }
        return http.Response('{}', 404);
      });
      final session = NativeAuthSession(
        backendOrigin: Uri.parse('https://api.testagram.site'),
        tokenStore: store,
        client: client,
        clock: () => now,
      );

      await session.signIn(email: ' User@Example.com ', password: 'correct horse battery staple');
      expect(await session.getAccessToken(), 'access-1');
      now = now.add(const Duration(minutes: 15));
      expect(await session.getAccessToken(), 'access-2');
      expect(refreshCalls, 1);
      expect(store.values.values, contains('s' * 43));
      expect(store.values.values, isNot(contains('r' * 43)));
    });

    test('clears local session after refresh rejection to avoid reusing a rotated token', () async {
      final store = MemoryTokenStore()
        ..values['testagram.native.access.v1'] = 'expired'
        ..values['testagram.native.refresh.v1'] = 'r' * 43
        ..values['testagram.native.expiry.v1'] = DateTime.utc(2026, 1).toIso8601String();
      final session = NativeAuthSession(
        backendOrigin: Uri.parse('https://api.testagram.site'),
        tokenStore: store,
        client: MockClient((_) async => http.Response(jsonEncode({
          'ok': false,
          'error': {'code': 'INVALID_REFRESH_TOKEN', 'message': 'Invalid token'},
        }), 401)),
      );

      await expectLater(session.getAccessToken(), throwsA(isA<NativeAuthException>()));
      expect(store.values, isEmpty);
    });

    test('logout always clears secure storage after the backend request', () async {
      final store = MemoryTokenStore()
        ..values['testagram.native.access.v1'] = 'access'
        ..values['testagram.native.refresh.v1'] = 'r' * 43
        ..values['testagram.native.expiry.v1'] = DateTime.utc(2026, 12).toIso8601String();
      final session = NativeAuthSession(
        backendOrigin: Uri.parse('https://api.testagram.site'),
        tokenStore: store,
        client: MockClient((request) async {
          expect(request.url.path, '/api/auth/logout');
          expect(request.headers['authorization'], 'Bearer access');
          return http.Response(jsonEncode({'ok': true, 'data': {'revoked': true}}), 200);
        }),
        clock: () => DateTime.utc(2026, 11, 15),
      );

      await session.signOut();
      expect(store.values, isEmpty);
    });

    test('rejects incomplete or unreasonable token responses', () async {
      final session = NativeAuthSession(
        backendOrigin: Uri.parse('https://api.testagram.site'),
        tokenStore: MemoryTokenStore(),
        client: MockClient((_) async => http.Response(jsonEncode({
          'ok': true,
          'data': {'access_token': 'access', 'refresh_token': 'short', 'expires_in': 900},
        }), 200)),
      );

      await expectLater(
        session.signIn(email: 'user@example.com', password: 'password'),
        throwsA(isA<NativeAuthException>()),
      );
    });
  });
}

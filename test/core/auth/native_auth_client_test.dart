import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:testagram/core/auth/native_auth_client.dart';

class _FailingDeleteNativeAuthStorage implements NativeAuthStorage {
  @override
  Future<String?> read({required String key}) async => null;

  @override
  Future<void> write({required String key, required String value}) async {}

  @override
  Future<void> delete({required String key}) async {
    throw StateError('secure storage delete unavailable');
  }
}

class _FailingNativeAuthStorage implements NativeAuthStorage {
  @override
  Future<String?> read({required String key}) async => null;

  @override
  Future<void> write({required String key, required String value}) async {
    throw StateError('secure storage unavailable');
  }

  @override
  Future<void> delete({required String key}) async {}
}

class _MemoryNativeAuthStorage implements NativeAuthStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }
}

void main() {
  const origin = 'https://api.testagram.site';
  final accessOne = List<String>.filled(64, 'a').join();
  final accessTwo = List<String>.filled(64, 'b').join();
  final refreshOne = List<String>.filled(64, 'r').join();
  final refreshTwo = List<String>.filled(64, 's').join();

  Map<String, dynamic> session(String access, String refresh) => {
        'ok': true,
        'data': {
          'access_token': access,
          'refresh_token': refresh,
          'expires_in': 900,
        },
      };

  test('stores only the refresh token and keeps access token in memory', () async {
    final storage = _MemoryNativeAuthStorage();
    late http.Request seen;
    final client = NativeAuthClient(
      baseUri: Uri.parse(origin),
      storage: storage,
      httpClient: MockClient((request) async {
        seen = request;
        return http.Response(jsonEncode(session(accessOne, refreshOne)), 200);
      }),
    );

    await client.signIn(email: 'user@example.test', password: 'correct-password-123');
    expect(seen.url.path, '/api/auth/login');
    expect(storage.values, {'testagram.auth.refresh.v1': refreshOne});
    expect(await client.accessToken(), accessOne);
    client.close();
  });

  test('shows the wake state and never automatically replays a login POST', () async {
    final storage = _MemoryNativeAuthStorage();
    var loginRequests = 0;
    final client = NativeAuthClient(
      baseUri: Uri.parse(origin),
      storage: storage,
      httpClient: MockClient((request) async {
        loginRequests++;
        expect(request.url.path, '/api/auth/login');
        return http.Response(
          jsonEncode({
            'ok': false,
            'error': {
              'code': 'api_origin_unavailable',
              'message': 'Testagram API is waking or temporarily unavailable.',
            },
          }),
          503,
          headers: {
            'x-testagram-recovery': 'attempted',
            'retry-after': '2',
          },
        );
      }),
    );

    await expectLater(
      client.signIn(email: 'user@example.test', password: 'correct-password-123'),
      throwsA(
        isA<NativeAuthException>()
            .having((error) => error.statusCode, 'statusCode', 503)
            .having((error) => error.code, 'code', 'API_ORIGIN_WAKING')
            .having((error) => error.message, 'message', contains('2 seconds')),
      ),
    );
    expect(loginRequests, 1);
    expect(storage.values, isEmpty);
    client.close();
  });

  test('preserves login intent after the edge confirms application readiness without replaying credentials', () async {
    final storage = _MemoryNativeAuthStorage();
    var loginRequests = 0;
    final seenBodies = <String>[];
    final client = NativeAuthClient(
      baseUri: Uri.parse(origin),
      storage: storage,
      httpClient: MockClient((request) async {
        loginRequests++;
        expect(request.url.path, '/api/auth/login');
        seenBodies.add(request.body);
        if (loginRequests == 1) {
          return http.Response(
            jsonEncode({'ok': false, 'error': 'machine_awake_retry_required'}),
            503,
            headers: {
              'x-testagram-recovery': 'ready',
              'retry-after': '1',
            },
          );
        }
        return http.Response(jsonEncode(session(accessOne, refreshOne)), 200);
      }),
    );

    await expectLater(
      client.signIn(email: 'User@example.test', password: 'correct-password-123'),
      throwsA(
        isA<NativeAuthException>()
            .having((error) => error.code, 'code', 'API_ORIGIN_RETRY_READY')
            .having((error) => error.message, 'message', contains('database is ready')),
      ),
    );
    expect(loginRequests, 1);
    expect(storage.values, isEmpty);

    // This second call represents the user's explicit retry on the still-open
    // login form. No password was persisted or automatically replayed.
    await client.signIn(email: 'User@example.test', password: 'correct-password-123');
    expect(loginRequests, 2);
    expect(seenBodies[0], seenBodies[1]);
    expect(storage.values, {'testagram.auth.refresh.v1': refreshOne});
    client.close();
  });

  test('force refresh rotates the refresh token and replaces the in-memory access token', () async {
    final storage = _MemoryNativeAuthStorage();
    var refreshCalls = 0;
    final client = NativeAuthClient(
      baseUri: Uri.parse(origin),
      storage: storage,
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/login')) {
          return http.Response(jsonEncode(session(accessOne, refreshOne)), 200);
        }
        if (request.url.path.endsWith('/refresh')) {
          refreshCalls++;
          expect(jsonDecode(request.body), {'refresh_token': refreshOne});
          return http.Response(jsonEncode(session(accessTwo, refreshTwo)), 200);
        }
        return http.Response('unexpected route', 404);
      }),
    );

    await client.signIn(email: 'user@example.test', password: 'correct-password-123');
    expect(await client.accessToken(forceRefresh: true), accessTwo);
    expect(refreshCalls, 1);
    expect(storage.values['testagram.auth.refresh.v1'], refreshTwo);
    expect(await client.accessToken(), accessTwo);
    expect(refreshCalls, 1);
    client.close();
  });

  test('revokes with the access token and clears the refresh token on sign out', () async {
    final storage = _MemoryNativeAuthStorage();
    final requests = <http.Request>[];
    final client = NativeAuthClient(
      baseUri: Uri.parse(origin),
      storage: storage,
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/login')) {
          return http.Response(jsonEncode(session(accessOne, refreshOne)), 200);
        }
        if (request.url.path.endsWith('/logout')) {
          return http.Response(jsonEncode({'ok': true, 'data': {'revoked': true}}), 200);
        }
        return http.Response('unexpected route', 404);
      }),
    );

    await client.signIn(email: 'user@example.test', password: 'correct-password-123');
    await client.signOut();
    final logout = requests.last;
    expect(logout.url.path, '/api/auth/logout');
    expect(logout.headers['Authorization'], 'Bearer $accessOne');
    expect(storage.values.containsKey('testagram.auth.refresh.v1'), isFalse);
    client.close();
  });

  test('does not expose an access token if secure refresh storage fails', () async {
    final client = NativeAuthClient(
      baseUri: Uri.parse(origin),
      storage: _FailingNativeAuthStorage(),
      httpClient: MockClient((request) async =>
          http.Response(jsonEncode(session(accessOne, refreshOne)), 200)),
    );

    await expectLater(
      client.signIn(email: 'user@example.test', password: 'correct-password-123'),
      throwsA(isA<NativeAuthException>()),
    );
    expect(await client.accessToken(), isNull);
    client.close();
  });

  test('clears in-memory access even when secure-storage deletion fails on sign out', () async {
    final client = NativeAuthClient(
      baseUri: Uri.parse(origin),
      storage: _FailingDeleteNativeAuthStorage(),
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/login')) {
          return http.Response(jsonEncode(session(accessOne, refreshOne)), 200);
        }
        if (request.url.path.endsWith('/logout')) {
          return http.Response(jsonEncode({'ok': true, 'data': {'revoked': true}}), 200);
        }
        return http.Response('unexpected route', 404);
      }),
    );

    await client.signIn(email: 'user@example.test', password: 'correct-password-123');
    await expectLater(client.signOut(), throwsA(isA<StateError>()));
    expect(await client.accessToken(), isNull);
    client.close();
  });

  test('clears a refresh token rejected by the Backend', () async {
    final storage = _MemoryNativeAuthStorage()
      ..values['testagram.auth.refresh.v1'] = refreshOne;
    final client = NativeAuthClient(
      baseUri: Uri.parse(origin),
      storage: storage,
      httpClient: MockClient((request) async => http.Response(
            jsonEncode({
              'ok': false,
              'error': {'code': 'INVALID_REFRESH_TOKEN', 'message': 'invalid'},
            }),
            401,
          )),
    );

    expect(await client.accessToken(), isNull);
    expect(storage.values.containsKey('testagram.auth.refresh.v1'), isFalse);
    client.close();
  });
  test('requests password recovery with a normalized email and no account disclosure', () async {
    final storage = _MemoryNativeAuthStorage();
    late http.Request seen;
    final client = NativeAuthClient(
      baseUri: Uri.parse(origin),
      storage: storage,
      httpClient: MockClient((request) async {
        seen = request;
        return http.Response(
          jsonEncode({
            'ok': true,
            'message': 'If the account exists, password recovery instructions will be sent.',
          }),
          202,
        );
      }),
    );

    await client.requestPasswordReset('  User@Example.Test  ');
    expect(seen.url.path, '/api/auth/forgot-password');
    expect(jsonDecode(seen.body), {'email': 'user@example.test'});
    expect(storage.values, isEmpty);
    client.close();
  });

  test('submits a reset capability once and clears the saved session after success', () async {
    final storage = _MemoryNativeAuthStorage();
    final requests = <http.Request>[];
    final client = NativeAuthClient(
      baseUri: Uri.parse(origin),
      storage: storage,
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/login')) {
          return http.Response(jsonEncode(session(accessOne, refreshOne)), 200);
        }
        if (request.url.path.endsWith('/reset-password')) {
          return http.Response(
            jsonEncode({'ok': true, 'message': 'Password reset. Sign in with your new password.'}),
            200,
          );
        }
        return http.Response('unexpected route', 404);
      }),
    );

    await client.signIn(email: 'user@example.test', password: 'OldPassword-123!');
    await client.resetPassword(
      token: 'single-use-recovery-capability',
      password: 'NewPassword-456!',
    );

    final reset = requests.last;
    expect(reset.url.path, '/api/auth/reset-password');
    expect(jsonDecode(reset.body), {
      'token': 'single-use-recovery-capability',
      'password': 'NewPassword-456!',
    });
    expect(reset.headers.containsKey('Authorization'), isFalse);
    expect(storage.values, isEmpty);
    expect(await client.accessToken(), isNull);
    client.close();
  });


  test('retains refresh credential and permits retry when Backend logout is unavailable', () async {
    final storage = _MemoryNativeAuthStorage();
    var backendAvailable = false;
    final client = NativeAuthClient(
      baseUri: Uri.parse(origin),
      storage: storage,
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/login')) {
          return http.Response(jsonEncode(session(accessOne, refreshOne)), 200);
        }
        if (request.url.path.endsWith('/logout')) {
          if (!backendAvailable) return http.Response('unavailable', 503);
          return http.Response(jsonEncode({'ok': true}), 200);
        }
        return http.Response('unexpected route', 404);
      }),
    );

    await client.signIn(email: 'user@example.test', password: 'correct-password-123');
    await expectLater(client.signOut(), throwsA(isA<NativeAuthException>()));
    expect(storage.values['testagram.auth.refresh.v1'], refreshOne);
    expect(await client.accessToken(), accessOne);

    backendAvailable = true;
    await client.signOut();
    expect(storage.values.containsKey('testagram.auth.refresh.v1'), isFalse);
    expect(await client.accessToken(), isNull);
    client.close();
  });

  test('clears local credentials when Backend confirms the session is already invalid', () async {
    final storage = _MemoryNativeAuthStorage();
    final client = NativeAuthClient(
      baseUri: Uri.parse(origin),
      storage: storage,
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/login')) {
          return http.Response(jsonEncode(session(accessOne, refreshOne)), 200);
        }
        if (request.url.path.endsWith('/logout')) {
          return http.Response('invalid session', 401);
        }
        return http.Response('unexpected route', 404);
      }),
    );

    await client.signIn(email: 'user@example.test', password: 'correct-password-123');
    await client.signOut();
    expect(storage.values.containsKey('testagram.auth.refresh.v1'), isFalse);
    expect(await client.accessToken(), isNull);
    client.close();
  });

}

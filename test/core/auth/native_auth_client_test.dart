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

  test('automatically retries authentication while an InstaBox public port wakes the machine', () async {
    final storage = _MemoryNativeAuthStorage();
    final requests = <http.Request>[];
    final waits = <Duration>[];
    final statuses = <String?>[];
    NativeAuthWakeAware? wakeAware;
    final client = NativeAuthClient(
      baseUri: Uri.parse(origin),
      storage: storage,
      waitBeforeWakeRetry: (delay) async {
        waits.add(delay);
        statuses.add(wakeAware!.wakeStatus.value);
      },
      httpClient: MockClient((request) async {
        requests.add(request);
        if (requests.length == 1) {
          return http.Response(
            'Sandbox is waking up',
            503,
            headers: {'retry-after': '3'},
          );
        }
        return http.Response(jsonEncode(session(accessOne, refreshOne)), 200);
      }),
    );
    wakeAware = client;

    await client.signIn(email: 'user@example.test', password: 'correct-password-123');

    expect(requests, hasLength(2));
    expect(requests.first.url.path, '/api/auth/login');
    expect(requests.last.url.path, '/api/auth/login');
    expect(requests.first.body, requests.last.body);
    expect(waits, [const Duration(seconds: 3)]);
    expect(statuses, ['Waking Testagram… reconnecting automatically.']);
    expect(wakeAware.wakeStatus.value, isNull);
    expect(storage.values, {'testagram.auth.refresh.v1': refreshOne});
    client.close();
  });

  test('web waits for the published port wake response before submitting credentials', () async {
    final storage = _MemoryNativeAuthStorage();
    final requests = <http.Request>[];
    final waits = <Duration>[];
    final statuses = <String?>[];
    NativeAuthWakeAware? wakeAware;
    var healthCalls = 0;
    final client = NativeAuthClient(
      baseUri: Uri.parse(origin),
      storage: storage,
      isWeb: true,
      waitBeforeWakeRetry: (delay) async {
        waits.add(delay);
        statuses.add(wakeAware!.wakeStatus.value);
      },
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' && request.url.path == '/healthz') {
          healthCalls++;
          if (healthCalls == 1) {
            return http.Response(
              'Sandbox is waking up',
              503,
              headers: {'retry-after': '4'},
            );
          }
          return http.Response('ok', 200);
        }
        return http.Response(jsonEncode(session(accessOne, refreshOne)), 200);
      }),
    );
    wakeAware = client;

    await client.signIn(
      email: 'user@example.test',
      password: 'correct-password-123',
    );

    expect(requests.map((request) => request.method), ['GET', 'GET', 'POST']);
    expect(requests.last.url.path, '/api/auth/login');
    expect(waits, [const Duration(seconds: 4)]);
    expect(statuses, ['Waking Testagram… reconnecting automatically.']);
    expect(storage.values, {'testagram.auth.refresh.v1': refreshOne});
    client.close();
  });

  test('web retries only the safe health GET when the proxy wake response is CORS-opaque', () async {
    final requests = <http.Request>[];
    final waits = <Duration>[];
    var healthCalls = 0;
    final client = NativeAuthClient(
      baseUri: Uri.parse(origin),
      storage: _MemoryNativeAuthStorage(),
      isWeb: true,
      waitBeforeWakeRetry: (delay) async => waits.add(delay),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' && request.url.path == '/healthz') {
          healthCalls++;
          if (healthCalls == 1) {
            throw http.ClientException('Browser hid proxy 503 because CORS headers were absent');
          }
          return http.Response('ok', 200);
        }
        return http.Response(jsonEncode(session(accessOne, refreshOne)), 200);
      }),
    );

    await client.signIn(
      email: 'user@example.test',
      password: 'correct-password-123',
    );

    expect(requests.map((request) => request.method), ['GET', 'GET', 'POST']);
    expect(waits, [const Duration(seconds: 2)]);
    expect(requests.where((request) => request.method == 'POST'), hasLength(1));
    client.close();
  });

  test('web does not submit credentials when InstaBox reports a manual offline state', () async {
    final requests = <http.Request>[];
    final client = NativeAuthClient(
      baseUri: Uri.parse(origin),
      storage: _MemoryNativeAuthStorage(),
      isWeb: true,
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response('Sandbox offline', 503);
      }),
    );

    await expectLater(
      client.signIn(email: 'user@example.test', password: 'correct-password-123'),
      throwsA(isA<NativeAuthException>()
          .having((error) => error.code, 'code', 'MACHINE_OFFLINE')),
    );
    expect(requests.map((request) => request.method), ['GET']);
    client.close();
  });

  test('web does not submit credentials during maximum-runtime cooldown', () async {
    final requests = <http.Request>[];
    final client = NativeAuthClient(
      baseUri: Uri.parse(origin),
      storage: _MemoryNativeAuthStorage(),
      isWeb: true,
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({'error': {'code': 'machine_cooldown'}}),
          409,
          headers: {'retry-after': '300'},
        );
      }),
    );

    await expectLater(
      client.signIn(email: 'user@example.test', password: 'correct-password-123'),
      throwsA(isA<NativeAuthException>()
          .having((error) => error.code, 'code', 'MACHINE_COOLDOWN')),
    );
    expect(requests.map((request) => request.method), ['GET']);
    client.close();
  });

  test('honors the full InstaBox Retry-After value without shortening it', () async {
    final waits = <Duration>[];
    var calls = 0;
    final client = NativeAuthClient(
      baseUri: Uri.parse(origin),
      storage: _MemoryNativeAuthStorage(),
      waitBeforeWakeRetry: (delay) async => waits.add(delay),
      httpClient: MockClient((_) async {
        calls++;
        if (calls == 1) {
          return http.Response(
            'Sandbox is waking up',
            503,
            headers: {'retry-after': '20'},
          );
        }
        return http.Response(jsonEncode(session(accessOne, refreshOne)), 200);
      }),
    );

    await client.signIn(
      email: 'user@example.test',
      password: 'correct-password-123',
    );

    expect(calls, 2);
    expect(waits, [const Duration(seconds: 20)]);
    client.close();
  });

  test('does not retry when InstaBox Retry-After exceeds the bounded wake window', () async {
    var calls = 0;
    final client = NativeAuthClient(
      baseUri: Uri.parse(origin),
      storage: _MemoryNativeAuthStorage(),
      waitBeforeWakeRetry: (_) async => fail('must not retry beyond wake window'),
      httpClient: MockClient((_) async {
        calls++;
        return http.Response(
          'Sandbox is waking up',
          503,
          headers: {'retry-after': '180'},
        );
      }),
    );

    await expectLater(
      client.signIn(
        email: 'user@example.test',
        password: 'correct-password-123',
      ),
      throwsA(
        isA<NativeAuthException>()
            .having((error) => error.code, 'code', 'SANDBOX_WAKING_UP'),
      ),
    );
    expect(calls, 1);
    client.close();
  });

  test('does not retry an InstaBox max-runtime cooldown response', () async {
    var calls = 0;
    final client = NativeAuthClient(
      baseUri: Uri.parse(origin),
      storage: _MemoryNativeAuthStorage(),
      waitBeforeWakeRetry: (_) async => fail('cooldown is not an idle wake'),
      httpClient: MockClient((_) async {
        calls++;
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'machine_cooldown',
              'message': 'Machine is in cooldown after maximum runtime.',
              'retryable': true,
            },
          }),
          409,
          headers: {'retry-after': '300'},
        );
      }),
    );

    await expectLater(
      client.signIn(
        email: 'user@example.test',
        password: 'correct-password-123',
      ),
      throwsA(
        isA<NativeAuthException>()
            .having((error) => error.statusCode, 'statusCode', 409),
      ),
    );
    expect(calls, 1);
    client.close();
  });

  test('does not retry ordinary application 503 responses', () async {
    var calls = 0;
    final client = NativeAuthClient(
      baseUri: Uri.parse(origin),
      storage: _MemoryNativeAuthStorage(),
      waitBeforeWakeRetry: (_) async => fail('ordinary 503 must not be retried'),
      httpClient: MockClient((_) async {
        calls++;
        return http.Response(
          jsonEncode({
            'ok': false,
            'error': {'code': 'SERVICE_UNAVAILABLE', 'message': 'Authentication is temporarily unavailable.'},
          }),
          503,
          headers: {'retry-after': '2'},
        );
      }),
    );

    await expectLater(
      client.signIn(email: 'user@example.test', password: 'correct-password-123'),
      throwsA(isA<NativeAuthException>().having((error) => error.statusCode, 'statusCode', 503)),
    );
    expect(calls, 1);
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
}

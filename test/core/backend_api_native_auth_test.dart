import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:testagram/core/backend_api.dart';

void main() {
  test('BackendApi refreshes a native token once after 401', () async {
    final refreshCalls = <bool>[];
    var requestCount = 0;
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getAccessToken: ({bool forceRefresh = false}) async {
        refreshCalls.add(forceRefresh);
        return forceRefresh ? 'fresh-native-token' : 'expired-native-token';
      },
      client: MockClient((request) async {
        requestCount++;
        if (requestCount == 1) {
          expect(request.headers['authorization'], 'Bearer expired-native-token');
          return http.Response(jsonEncode({
            'error': {'code': 'AUTH_REQUIRED', 'message': 'expired'},
          }), 401);
        }
        expect(request.headers['authorization'], 'Bearer fresh-native-token');
        return http.Response(jsonEncode({'data': {'items': []}}), 200);
      }),
    );

    final result = await api.getHomeFeed();
    expect(result['data'], {'items': []});
    expect(requestCount, 2);
    expect(refreshCalls, [false, true]);
    api.close();
  });

  test('BackendApi never retries repeatedly after a second 401', () async {
    var requestCount = 0;
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getAccessToken: ({bool forceRefresh = false}) async =>
          forceRefresh ? 'refreshed-token' : 'expired-token',
      client: MockClient((request) async {
        requestCount++;
        return http.Response(jsonEncode({
          'error': {'code': 'AUTH_REQUIRED', 'message': 'expired'},
        }), 401);
      }),
    );

    await expectLater(
      api.getHomeFeed(),
      throwsA(isA<BackendApiException>().having((error) => error.statusCode, 'statusCode', 401)),
    );
    expect(requestCount, 2);
    api.close();
  });
}

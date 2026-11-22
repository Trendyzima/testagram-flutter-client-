import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:testagram/core/backend_api.dart';

void main() {
  group('BackendApi profile safety', () {
    test('blocks and unblocks through the authenticated Backend routes', () async {
      final requests = <http.Request>[];
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getAccessToken: ({bool forceRefresh = false}) async => 'native-testagram-token',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({'ok': true, 'data': {'blocked': true}}),
            200,
          );
        }),
      );

      const target = '123e4567-e89b-42d3-a456-426614174000';
      await api.blockUser(target.toUpperCase());
      await api.unblockUser(target.toUpperCase());

      expect(requests, hasLength(2));
      expect(requests[0].method, 'POST');
      expect(requests[0].url.path, '/api/social/blocks');
      expect(jsonDecode(requests[0].body), {'target_user_id': target});
      expect(requests[1].method, 'DELETE');
      expect(requests[1].url.path, '/api/social/blocks/$target');
      expect(requests.every((request) =>
          request.headers['authorization'] == 'Bearer native-testagram-token'), isTrue);
      api.close();
    });

    test('rejects invalid account IDs before network access', () {
      var sent = false;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getAccessToken: ({bool forceRefresh = false}) async => 'jwt',
        client: MockClient((_) async {
          sent = true;
          return http.Response('{}', 200);
        }),
      );

      expect(() => api.blockUser('not-a-uuid'), throwsArgumentError);
      expect(() => api.unblockUser('not-a-uuid'), throwsArgumentError);
      expect(sent, isFalse);
      api.close();
    });
  });
}

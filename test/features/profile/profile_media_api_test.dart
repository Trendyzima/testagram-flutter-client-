import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:testagram/core/backend_api.dart';

void main() {
  test('requests server-filtered media profile timeline pages', () async {
    final requests = <http.Request>[];
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getAccessToken: ({bool forceRefresh = false}) async => 'native-token',
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode({
          'ok': true,
          'data': {'posts': [], 'has_more': false, 'next_cursor': ''},
        }), 200);
      }),
    );

    await api.getProfilePosts(
      '123e4567-e89b-42d3-a456-426614174000',
      mediaOnly: true,
    );

    expect(requests.single.url.path,
        '/api/social/profiles/123e4567-e89b-42d3-a456-426614174000/posts');
    expect(requests.single.url.queryParameters['media_only'], 'true');
    api.close();
  });
}

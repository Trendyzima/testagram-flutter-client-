import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:testagram/core/backend_api.dart';

void main() {
  test('requests bounded Testagram account suggestions', () async {
    http.Request? captured;
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getAccessToken: ({bool forceRefresh = false}) async => 'native-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode({
          'ok': true,
          'data': {
            'items': [
              {
                'id': '123e4567-e89b-42d3-a456-426614174000',
                'username': 'community_member',
                'display_name': 'Community Member',
                'mutual_followers_count': 2,
                'reason': 'followed_by_people_you_follow',
              },
            ],
          },
        }), 200, headers: {'content-type': 'application/json'});
      }),
    );

    final response = await api.getSocialSuggestions(limit: 5);

    expect(captured?.url.path, '/api/social/suggestions');
    expect(captured?.url.queryParameters['limit'], '5');
    expect(captured?.headers['authorization'], 'Bearer native-token');
    expect((response['data'] as Map)['items'], hasLength(1));
    api.close();
  });
}

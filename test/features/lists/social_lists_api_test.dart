import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:testagram/core/backend_api.dart';

void main() {
  test('curated lists API uses the authenticated native session', () async {
    final requests = <http.Request>[];
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getAccessToken: ({bool forceRefresh = false}) async => 'native-session-token',
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode({'ok': true, 'data': {'items': []}}), 200);
      }),
    );

    await api.getSocialLists();
    await api.createSocialList(name: 'Kenya builders', description: 'People building useful things', visibility: 'public');
    await api.getSocialList('123e4567-e89b-42d3-a456-426614174000');
    await api.getSocialListMembers('123e4567-e89b-42d3-a456-426614174000');
    await api.addSocialListMember(listId: '123e4567-e89b-42d3-a456-426614174000', userId: '223e4567-e89b-42d3-a456-426614174000');
    await api.removeSocialListMember(listId: '123e4567-e89b-42d3-a456-426614174000', userId: '223e4567-e89b-42d3-a456-426614174000');
    await api.updateSocialListPin('123e4567-e89b-42d3-a456-426614174000', pinned: true);
    await api.deleteSocialList('123e4567-e89b-42d3-a456-426614174000');

    expect(requests, hasLength(8));
    expect(requests[0].url.path, '/api/social/lists');
    expect(requests[1].method, 'POST');
    expect(requests[1].url.path, '/api/social/lists');
    expect(jsonDecode(requests[1].body), {
      'name': 'Kenya builders',
      'description': 'People building useful things',
      'visibility': 'public',
    });
    expect(requests[2].url.path, '/api/social/lists/123e4567-e89b-42d3-a456-426614174000');
    expect(requests[3].url.path, '/api/social/lists/123e4567-e89b-42d3-a456-426614174000/members');
    expect(requests[4].url.path, '/api/social/lists/123e4567-e89b-42d3-a456-426614174000/members');
    expect(jsonDecode(requests[4].body), {'user_id': '223e4567-e89b-42d3-a456-426614174000'});
    expect(requests[5].method, 'DELETE');
    expect(requests[5].url.path, '/api/social/lists/123e4567-e89b-42d3-a456-426614174000/members/223e4567-e89b-42d3-a456-426614174000');
    expect(requests[6].method, 'PUT');
    expect(requests[6].url.path, '/api/social/lists/123e4567-e89b-42d3-a456-426614174000/pin');
    expect(jsonDecode(requests[6].body), {'pinned': true});
    expect(requests[7].method, 'DELETE');
    expect(requests.every((r) => r.headers['authorization'] == 'Bearer native-session-token'), isTrue);
    api.close();
  });
}

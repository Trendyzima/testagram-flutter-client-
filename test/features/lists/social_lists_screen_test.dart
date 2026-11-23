import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:testagram/core/backend_api.dart';
import 'package:testagram/features/lists/social_lists_screen.dart';

void main() {
  testWidgets('opens a List-scoped custom feed without losing List context', (tester) async {
    const listId = '123e4567-e89b-42d3-a456-426614174000';
    final requests = <http.Request>[];
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getAccessToken: ({bool forceRefresh = false}) async => 'native-token',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/social/lists') {
          return http.Response(jsonEncode({
            'ok': true,
            'data': {
              'items': [
                {'id': listId, 'name': 'Kenya builders', 'visibility': 'public', 'members_count': 2},
              ],
            },
          }), 200);
        }
        if (request.url.path.endsWith('/members')) {
          return http.Response(jsonEncode({'ok': true, 'data': {'items': []}}), 200);
        }
        if (request.url.path == '/api/feed/home') {
          return http.Response(jsonEncode({
            'ok': true,
            'data': {
              'posts': [],
              'next_cursor': null,
              'has_more': false,
              'ranking_mode': 'chronological',
              'feed_mode': 'for_you',
              'list_id': listId,
            },
          }), 200);
        }
        return http.Response(jsonEncode({'ok': true, 'data': {}}), 200);
      }),
    );
    addTearDown(api.close);

    await tester.pumpWidget(MaterialApp(
      home: SocialListsScreen(api: api, onSignOut: () async {}),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kenya builders'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Open custom feed'), findsOneWidget);
    await tester.tap(find.byTooltip('Open custom feed'));
    await tester.pumpAndSettle();

    expect(find.text('Kenya builders'), findsOneWidget);
    expect(
      requests.any((request) =>
          request.url.path == '/api/feed/home' &&
          request.url.queryParameters['list_id'] == listId),
      isTrue,
    );
  });

  testWidgets('Lists screen explains curated lists and opens creation flow', (tester) async {
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getAccessToken: ({bool forceRefresh = false}) async => 'native-token',
      client: MockClient((request) async => http.Response(
        jsonEncode({'ok': true, 'data': {'items': []}}),
        200,
      )),
    );

    await tester.pumpWidget(MaterialApp(home: SocialListsScreen(api: api, onSignOut: () async {})));
    await tester.pumpAndSettle();

    expect(find.text('Your lists'), findsOneWidget);
    expect(find.text('Organize the accounts you follow'), findsOneWidget);
    expect(find.text('Create your first list'), findsOneWidget);

    await tester.tap(find.text('Create your first list'));
    await tester.pumpAndSettle();
    expect(find.text('Create a list'), findsOneWidget);
    expect(find.text('Who can view this list?'), findsOneWidget);
    expect(find.text('Create list'), findsOneWidget);
    api.close();
  });
}

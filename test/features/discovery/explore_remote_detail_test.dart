import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:testagram/core/backend_api.dart';
import 'package:testagram/features/discovery/explore_screen.dart';

void main() {
  testWidgets('remote discovery result opens read-only detail without local UUID lookup',
      (tester) async {
    final requestedPaths = <String>[];
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getAccessToken: ({bool forceRefresh = false}) async => 'native-token',
      client: MockClient((request) async {
        requestedPaths.add(request.url.path);
        if (request.url.path == '/api/hashtags/trending') {
          return http.Response(jsonEncode({
            'ok': true,
            'data': {'items': []},
          }), 200);
        }
        if (request.url.path == '/api/search') {
          return http.Response(jsonEncode({
            'ok': true,
            'data': {
              'posts': [
                {
                  'id': 'at://did:plc:example/app.bsky.feed.post/record-1',
                  'origin': 'atproto',
                  'visibility': 'unlisted',
                  'canonical_uri': 'at://did:plc:example/app.bsky.feed.post/record-1',
                  'content': 'A remote post found through discovery',
                  'created_at': '2026-11-22T03:00:00Z',
                  'author': {
                    'id': 'did:plc:example',
                    'username': 'alice.bsky.social',
                    'display_name': 'Alice',
                  },
                },
              ],
              'users': [],
              'next_cursor': null,
            },
          }), 200);
        }
        return http.Response(jsonEncode({
          'ok': false,
          'error': {'code': 'NOT_FOUND', 'message': 'Not found'},
        }), 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: ExploreScreen(api: api)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'remote post');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();

    expect(find.text('A remote post found through discovery'), findsOneWidget);
    await tester.tap(find.text('A remote post found through discovery'));
    await tester.pumpAndSettle();

    expect(find.text('Remote post'), findsOneWidget);
    expect(find.text('Unlisted'), findsOneWidget);
    expect(find.text('Public'), findsNothing);
    expect(find.textContaining('Read-only remote snapshot'), findsOneWidget);
    expect(
      find.text('at://did:plc:example/app.bsky.feed.post/record-1'),
      findsOneWidget,
    );
    expect(
      requestedPaths.where((path) => path.startsWith('/api/social/posts/')),
      isEmpty,
    );
    api.close();
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:testagram/core/backend_api.dart';
import 'package:testagram/features/feed/feed_screen.dart';

void main() {
  testWidgets('main-feed composer exposes privacy and image attachment controls', (tester) async {
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getJwt: () async => 'jwt',
      client: MockClient((request) async => http.Response(jsonEncode({
        'ok': true,
        'data': {'posts': [], 'has_more': false, 'next_cursor': ''},
      }), 200)),
    );

    await tester.pumpWidget(MaterialApp(
      home: FeedScreen(api: api, onSignOut: () async {}),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Compose post'));
    await tester.pumpAndSettle();

    expect(find.text('Create a post'), findsOneWidget);
    expect(find.text('Everyone'), findsOneWidget);
    expect(find.text('Followers'), findsOneWidget);
    expect(find.text('Only me'), findsOneWidget);
    expect(find.text('Add photo (0/4)'), findsOneWidget);
    expect(find.text('Publish'), findsOneWidget);
    api.close();
  });

  testWidgets('main-feed composer publishes through the canonical Backend route', (tester) async {
    final requests = <http.Request>[];
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getJwt: () async => 'appwrite-session-jwt',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/feed/home') {
          return http.Response(jsonEncode({
            'ok': true,
            'data': {'posts': [], 'has_more': false, 'next_cursor': ''},
          }), 200);
        }
        if (request.url.path == '/api/social/posts') {
          return http.Response(jsonEncode({
            'ok': true,
            'data': {'id': 'post-created-1'},
          }), 201);
        }
        return http.Response(jsonEncode({'ok': false}), 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: FeedScreen(api: api, onSignOut: () async {}),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Compose post'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Hello from Testagram #BuildInPublic');
    await tester.pumpAndSettle();
    final publishButton = find.widgetWithText(FilledButton, 'Publish');
    expect(publishButton, findsOneWidget);
    expect(tester.widget<FilledButton>(publishButton).onPressed, isNotNull);
    await tester.ensureVisible(publishButton);
    await tester.tap(publishButton);
    await tester.pumpAndSettle();
    expect(find.text('Create a post'), findsNothing);

    final createRequest = requests.firstWhere((request) => request.url.path == '/api/social/posts');
    expect(createRequest.method, 'POST');
    expect(createRequest.headers['authorization'], 'Bearer appwrite-session-jwt');
    expect(createRequest.headers['idempotency-key'], isNotEmpty);
    expect(jsonDecode(createRequest.body), {
      'content': 'Hello from Testagram #BuildInPublic',
      'visibility': 'public',
    });
    expect(find.text('Your post was published.'), findsOneWidget);
    api.close();
  });
}

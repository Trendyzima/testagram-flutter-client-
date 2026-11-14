import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:testagram/core/backend_api.dart';
import 'package:testagram/features/feed/feed_screen.dart';

void main() {
  testWidgets('X-inspired feed tabs query Following and desktop topics come from real posts', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final requestedUris = <Uri>[];
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getJwt: () async => 'jwt',
      client: MockClient((request) async {
        requestedUris.add(request.url);
        if (request.url.path == '/api/feed/home') {
          return http.Response(jsonEncode({
            'ok': true,
            'data': {
              'posts': [{
                'id': 'topic-post',
                'content': 'Building in public #KenyaTech #BuildInPublic',
                'created_at': '2026-11-14T09:00:00Z',
                'author': {'username': 'builder', 'display_name': 'Builder'},
              }],
              'has_more': false,
              'next_cursor': '',
            },
          }), 200);
        }
        if (request.url.path.endsWith('/interaction-summary')) {
          return http.Response(jsonEncode({
            'ok': true,
            'data': {'likes': 2, 'replies': 1, 'reposts': 0},
          }), 200);
        }
        return http.Response(jsonEncode({'ok': false}), 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: FeedScreen(api: api, onSignOut: () async {}),
    ));
    await tester.pumpAndSettle();

    expect(find.text('For you'), findsOneWidget);
    expect(find.text('Following'), findsOneWidget);
    expect(find.text("What's happening?"), findsOneWidget);
    expect(find.text("What's happening"), findsOneWidget);
    expect(find.text('#kenyatech'), findsOneWidget);
    expect(find.text('#buildinpublic'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Following'));
    await tester.pumpAndSettle();
    expect(requestedUris.any((uri) => uri.queryParameters['following_only'] == 'true'), isTrue);
    expect(tester.takeException(), isNull);
    api.close();
  });

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

  testWidgets('main feed renders all attached images in a post gallery', (tester) async {
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getJwt: () async => 'jwt',
      client: MockClient((request) async {
        if (request.url.path == '/api/feed/home') {
          return http.Response(jsonEncode({
            'ok': true,
            'data': {
              'posts': [{
                'id': 'post-with-gallery',
                'content': 'A gallery post',
                'created_at': '2026-11-12T09:00:00Z',
                'media_urls': [
                  'https://media.testagram.site/one.webp',
                  'https://media.testagram.site/two.webp',
                ],
                'author': {'username': 'alice', 'display_name': 'Alice'},
              }],
              'has_more': false,
              'next_cursor': '',
            },
          }), 200);
        }
        if (request.url.path.endsWith('/interaction-summary')) {
          return http.Response(jsonEncode({
            'ok': true,
            'data': {'likes': 0, 'replies': 0, 'reposts': 0},
          }), 200);
        }
        return http.Response(jsonEncode({'ok': false}), 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: FeedScreen(api: api, onSignOut: () async {}),
    ));
    await tester.pumpAndSettle();

    expect(find.text('A gallery post'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
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

  testWidgets('main-feed composer publishes and reads the created post back', (tester) async {
    var created = false;
    final requests = <http.Request>[];
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getJwt: () async => 'staging-shaped-appwrite-jwt',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/feed/home') {
          return http.Response(jsonEncode({
            'ok': true,
            'data': {
              'posts': created ? [{
                'id': 'post-read-back-1',
                'content': 'Read-back verified from the Backend',
                'created_at': '2026-11-14T12:00:00Z',
                'author': {'username': 'staging_member', 'display_name': 'Staging Member'},
              }] : [],
              'has_more': false,
              'next_cursor': '',
            },
          }), 200);
        }
        if (request.url.path == '/api/social/posts') {
          created = true;
          return http.Response(jsonEncode({
            'ok': true,
            'data': {'id': 'post-read-back-1'},
          }), 201);
        }
        if (request.url.path.endsWith('/interaction-summary')) {
          return http.Response(jsonEncode({
            'ok': true,
            'data': {'likes': 0, 'replies': 0, 'reposts': 0},
          }), 200);
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
    await tester.enterText(find.byType(TextField), 'Read-back verified from the Backend');
    await tester.pumpAndSettle();
    final publishButton = find.widgetWithText(FilledButton, 'Publish');
    await tester.ensureVisible(publishButton);
    await tester.tap(publishButton);
    await tester.pumpAndSettle();

    expect(find.text('Your post was published.'), findsOneWidget);
    expect(find.text('Read-back verified from the Backend'), findsOneWidget);
    expect(requests.where((r) => r.url.path == '/api/social/posts').length, 1);
    expect(requests.where((r) => r.url.path == '/api/feed/home').length, greaterThanOrEqualTo(2));
    expect(requests.firstWhere((r) => r.url.path == '/api/social/posts').headers['authorization'],
        'Bearer staging-shaped-appwrite-jwt');
    api.close();
  });

}

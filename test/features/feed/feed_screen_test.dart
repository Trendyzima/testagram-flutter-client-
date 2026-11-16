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
      getAccessToken: ({bool forceRefresh = false}) async => 'jwt',
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
    expect(find.text('Latest'), findsOneWidget);
    expect(find.text('Media'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text("What's happening?"), findsOneWidget);
    expect(find.text("What's happening"), findsOneWidget);
    expect(find.text('#kenyatech'), findsOneWidget);
    expect(find.text('#buildinpublic'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Following'));
    await tester.pumpAndSettle();
    expect(requestedUris.any((uri) =>
        uri.queryParameters['following_only'] == 'true' &&
        uri.queryParameters['feed'] == 'following'), isTrue);
    expect(tester.takeException(), isNull);
    api.close();
  });

  testWidgets('main-feed composer exposes privacy and image attachment controls', (tester) async {
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getAccessToken: ({bool forceRefresh = false}) async => 'jwt',
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
    expect(find.text('Add video (0/1)'), findsOneWidget);
    expect(find.text('Publish'), findsOneWidget);
    api.close();
  });

  testWidgets('main feed renders all attached images in a post gallery', (tester) async {
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getAccessToken: ({bool forceRefresh = false}) async => 'jwt',
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
                  'https://media.testagram.site/users/u1/one.webp',
                  'https://media.testagram.site/users/u1/two.webp',
                ],
                'media_auth_headers': {
                  'https://media.testagram.site/users/u1/one.webp': 'Bearer v1.test',
                },
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
    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images, hasLength(2));
    final firstProvider = images.first.image;
    expect(firstProvider, isA<NetworkImage>());
    final normalizedImage = firstProvider as NetworkImage;
    expect(
      normalizedImage.url,
      'https://media.testagram.site/media/users/u1/one.webp',
    );
    expect(normalizedImage.headers?['Authorization'], 'Bearer v1.test');
    api.close();
  });

  testWidgets('video posts open Shorts instead of being decoded as images', (tester) async {
    final requestedUris = <Uri>[];
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getAccessToken: ({bool forceRefresh = false}) async => 'jwt',
      client: MockClient((request) async {
        requestedUris.add(request.url);
        if (request.url.path == '/api/feed/home' &&
            request.url.queryParameters['video_only'] == 'true') {
          return http.Response(jsonEncode({
            'ok': true,
            'data': {'posts': [], 'has_more': false, 'next_cursor': ''},
          }), 200);
        }
        if (request.url.path == '/api/feed/home') {
          return http.Response(jsonEncode({
            'ok': true,
            'data': {
              'posts': [{
                'id': 'video-post-1',
                'content': 'A short video',
                'is_video': true,
                'created_at': '2026-11-15T09:00:00Z',
                'media_urls': ['https://cdn.testagram.site/video.mp4'],
                'media_content_types': ['video/mp4'],
                'media_urls': ['https://cdn.testagram.site/video.mp4'],
                'author': {'id': 'creator-id', 'username': 'creator', 'display_name': 'Creator'},
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

    expect(find.text('Watch in Shorts'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    // The video URL is never sent to Image.network; tapping opens the native
    // Shorts route, whose platform player is exercised by device/integration tests.
    expect(requestedUris.any((uri) => uri.queryParameters['video_only'] == 'true'), isFalse);
    expect(tester.takeException(), isNull);
    api.close();
  });

  testWidgets('main-feed composer publishes through the canonical Backend route', (tester) async {
    final requests = <http.Request>[];
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getAccessToken: ({bool forceRefresh = false}) async => 'testagram-native-access-token',
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
    expect(createRequest.headers['authorization'], 'Bearer testagram-native-access-token');
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
      getAccessToken: ({bool forceRefresh = false}) async => 'staging-shaped-native-access-token',
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
        'Bearer staging-shaped-native-access-token');
    api.close();
  });

  testWidgets('post menu publishes a quote through the canonical repost endpoint', (tester) async {
    final requests = <http.Request>[];
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getAccessToken: ({bool forceRefresh = false}) async => 'jwt',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/feed/home') {
          return http.Response(jsonEncode({
            'ok': true,
            'data': {
              'posts': [{
                'id': 'quote-source-1',
                'content': 'Original post to quote',
                'created_at': '2026-11-14T09:00:00Z',
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
            'data': {'is_reposted': true, 'reposts': 1},
          }), 200);
        }
        if (request.url.path == '/api/social/posts/quote-source-1/reposts') {
          return http.Response(jsonEncode({'ok': true, 'data': {'id': 'quote-1'}}), 201);
        }
        return http.Response(jsonEncode({'ok': false}), 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: FeedScreen(api: api, onSignOut: () async {}),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Post actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quote post'));
    await tester.pumpAndSettle();

    expect(find.text('Original post to quote'), findsAtLeastNWidgets(1));
    await tester.enterText(find.byType(TextField).last, 'Adding my perspective');
    await tester.pumpAndSettle();
    final publish = find.widgetWithText(FilledButton, 'Publish quote');
    expect(tester.widget<FilledButton>(publish).onPressed, isNotNull);
    await tester.tap(publish);
    await tester.pumpAndSettle();

    final quoteRequest = requests.firstWhere(
      (request) => request.url.path == '/api/social/posts/quote-source-1/reposts',
    );
    expect(quoteRequest.method, 'POST');
    expect(jsonDecode(quoteRequest.body), {'quote': 'Adding my perspective'});
    expect(find.text('Your quote was published.'), findsOneWidget);
    api.close();
  });

  testWidgets('remote Bluesky cards show provenance and hide unsupported interactions', (tester) async {
    final requestedPaths = <String>[];
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getAccessToken: ({bool forceRefresh = false}) async => 'jwt',
      client: MockClient((request) async {
        requestedPaths.add(request.url.path);
        if (request.url.path == '/api/feed/home') {
          return http.Response(jsonEncode({
            'ok': true,
            'data': {
              'posts': [{
                'id': 'at://did:plc:example/app.bsky.feed.post/1',
                'content': 'A public Bluesky post',
                'origin': 'atproto',
                'created_at': '2026-11-16T09:00:00Z',
                'author': {
                  'id': 'did:plc:example',
                  'username': 'alice.bsky.social',
                  'display_name': 'Alice',
                  'protected_account': false,
                },
                'capabilities': {
                  'like': false,
                  'reply': false,
                  'repost': false,
                  'quote': false,
                  'follow_author': false,
                },
              }],
              'has_more': false,
              'next_cursor': '',
            },
          }), 200);
        }
        return http.Response(jsonEncode({'ok': true, 'data': {}}), 200);
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: FeedScreen(api: api, onSignOut: () async {}),
    ));
    await tester.pumpAndSettle();

    expect(requestedPaths.where((path) => path.endsWith('/interaction-summary')), isEmpty);
    expect(find.text('via Bluesky'), findsOneWidget);
    expect(find.text('A public Bluesky post'), findsOneWidget);
    expect(find.byIcon(Icons.mode_comment_outlined), findsNothing);
    expect(find.byIcon(Icons.repeat_rounded), findsNothing);
    expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
    expect(find.byIcon(Icons.bookmark_border_rounded), findsNothing);

    final menuFinder = find.ancestor(
      of: find.byTooltip('Post actions'),
      matching: find.byType(PopupMenuButton<String>),
    );
    expect(menuFinder, findsOneWidget);
    final menu = tester.widget<PopupMenuButton<String>>(menuFinder);
    final menuContext = tester.element(menuFinder);
    final entries = menu.itemBuilder(menuContext);
    final quote = entries.whereType<PopupMenuItem<String>>()
        .firstWhere((entry) => entry.value == 'quote');
    expect(quote.enabled, isFalse);
    api.close();
  });


}

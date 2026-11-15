import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:testagram/core/backend_api.dart';
import 'package:testagram/features/shorts/shorts_screen.dart';

void main() {
  testWidgets('Shorts requests the authenticated video-only feed', (tester) async {
    final requested = <Uri>[];
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getJwt: () async => 'session-jwt',
      client: MockClient((request) async {
        requested.add(request.url);
        if (request.url.path == '/api/feed/home') {
          return http.Response(jsonEncode({
            'ok': true,
            'data': {
              'posts': [],
              'has_more': false,
              'next_cursor': '',
              'video_only': true,
            },
          }), 200);
        }
        return http.Response(jsonEncode({'ok': false}), 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: ShortsScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('SHORTS'), findsNothing);
    expect(find.text('No short videos yet'), findsOneWidget);
    expect(requested, hasLength(1));
    expect(requested.single.path, '/api/feed/home');
    expect(requested.single.queryParameters['video_only'], 'true');
    expect(tester.takeException(), isNull);
    api.close();
  });

  testWidgets('Shorts offers a retry state when the Backend feed is unavailable', (tester) async {
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getJwt: () async => 'session-jwt',
      client: MockClient((request) async => http.Response(
        jsonEncode({'ok': false, 'error': {'message': 'temporarily unavailable'}}),
        503,
      )),
    );

    await tester.pumpWidget(MaterialApp(home: ShortsScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Could not load videos'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.takeException(), isNull);
    api.close();
  });
}

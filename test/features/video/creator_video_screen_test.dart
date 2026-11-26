import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:testagram/core/backend_api.dart';
import 'package:testagram/features/video/creator_video_screen.dart';

void main() {
  testWidgets('creator screen loads owned channels and creates a channel', (tester) async {
    final requests = <http.Request>[];
    final api = BackendApi(
      baseUri: Uri.parse('https://api.example.test'),
      getAccessToken: ({bool forceRefresh = false}) async => 'native-session-token',
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' && request.url.path == '/api/video/channels') {
          return http.Response(jsonEncode({'items': []}), 200);
        }
        if (request.method == 'POST' && request.url.path == '/api/video/channels') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['handle'], 'mychannel');
          expect(body['name'], 'My Channel');
          return http.Response(jsonEncode({'id': 'channel-1'}), 201);
        }
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: CreatorVideoScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Create your channel'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'mychannel');
    await tester.enterText(find.byType(TextField).at(1), 'My Channel');
    await tester.tap(find.text('Create channel'));
    await tester.pumpAndSettle();

    expect(find.text('Create another channel'), findsOneWidget);
    expect(requests.map((request) => request.url.path), [
      '/api/video/channels',
      '/api/video/channels',
    ]);
    for (final request in requests) {
      expect(request.headers['authorization'], 'Bearer native-session-token');
    }
    api.close();
  });

  testWidgets('creator screen lists and deletes an existing owned video', (tester) async {
    final requests = <http.Request>[];
    const videoId = '2c6e2d3a-61c1-4e8f-8d41-92f1a0d13b62';
    final api = BackendApi(
      baseUri: Uri.parse('https://api.example.test'),
      getAccessToken: ({bool forceRefresh = false}) async => 'native-session-token',
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' && request.url.path == '/api/video/channels') {
          return http.Response(jsonEncode({
            'items': [
              {'id': 'channel-1', 'handle': 'creator', 'name': 'Creator'}
            ],
          }), 200);
        }
        if (request.method == 'GET' && request.url.path == '/api/video/uploads') {
          return http.Response(jsonEncode({
            'items': [
              {
                'id': videoId,
                'channel_id': 'channel-1',
                'channel_name': 'Creator',
                'title': 'Existing upload',
                'status': 'ready',
                'visibility': 'public',
              }
            ],
          }), 200);
        }
        if (request.method == 'DELETE' &&
            request.url.path == '/api/video/uploads/$videoId') {
          return http.Response('', 204);
        }
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: CreatorVideoScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('My videos'), findsOneWidget);
    expect(find.text('Existing upload'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete video'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this video?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete video'));
    await tester.pumpAndSettle();

    expect(find.text('Existing upload'), findsNothing);
    expect(requests.any((request) =>
        request.method == 'DELETE' &&
        request.url.path == '/api/video/uploads/$videoId'), isTrue);
    for (final request in requests) {
      expect(request.headers['authorization'], 'Bearer native-session-token');
    }
    api.close();
  });

}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:testagram/core/video_api.dart';
import 'package:testagram/features/video/creator_video_screen.dart';

void main() {
  testWidgets('creator screen loads owned channels and creates a channel', (tester) async {
    final requests = <http.Request>[];
    final api = VideoApi(
      baseUri: Uri.parse('https://video.example.test'),
      getAccessToken: ({bool forceRefresh = false}) async => 'native-session-token',
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' && request.url.path == '/v1/channels') {
          return http.Response(jsonEncode({'items': []}), 200);
        }
        if (request.method == 'POST' && request.url.path == '/v1/channels') {
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
      '/v1/channels',
      '/v1/channels',
    ]);
    for (final request in requests) {
      expect(request.headers['authorization'], 'Bearer native-session-token');
    }
    api.close();
  });
}

import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:testagram/core/backend_api.dart';
import 'package:testagram/features/discovery/hashtags_screen.dart';

void main() {
  testWidgets('hashtags directory displays Backend-ranked public topics', (tester) async {
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getJwt: () async => 'appwrite-session-jwt',
      client: MockClient((request) async {
        expect(request.url.path, '/api/hashtags/trending');
        return http.Response(jsonEncode({
          'ok': true,
          'data': {
            'items': [
              {'tag': 'fediverse', 'posts_count': 42},
              {'tag': 'testagram', 'posts_count': 18},
            ],
            'window': '7d',
          },
        }), 200);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: HashtagsScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Hashtags'), findsOneWidget);
    expect(find.text('Trending this week'), findsOneWidget);
    expect(find.text('#fediverse'), findsOneWidget);
    expect(find.text('42 public posts this week'), findsOneWidget);
    api.close();
  });
}

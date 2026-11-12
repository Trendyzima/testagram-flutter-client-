import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:testagram/core/backend_api.dart';
import 'package:testagram/features/discovery/hashtag_screen.dart';

void main() {
  testWidgets('hashtag page loads its privacy-filtered timeline from Backend', (tester) async {
    late http.Request captured;
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getJwt: () async => 'appwrite-session-jwt',
      client: MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode({
          'ok': true,
          'data': {
            'tag': 'testagram',
            'posts': [
              {
                'id': 'post-1',
                'content': 'A post about #Testagram',
                'created_at': '2026-11-12T08:00:00Z',
                'likes_count': 3,
                'replies_count': 1,
                'author': {
                  'username': 'alice',
                  'display_name': 'Alice',
                },
                'media_urls': [],
              },
            ],
            'has_more': false,
            'next_cursor': '',
          },
        }), 200);
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: HashtagScreen(api: api, tag: '#Testagram'),
    ));
    await tester.pumpAndSettle();

    expect(captured.method, 'GET');
    expect(captured.url.path, '/api/hashtags/Testagram');
    expect(captured.headers['authorization'], 'Bearer appwrite-session-jwt');
    expect(find.text('#Testagram'), findsOneWidget);
    expect(find.text('A post about #Testagram'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    api.close();
  });
}

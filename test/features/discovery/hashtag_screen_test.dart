import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:testagram/core/backend_api.dart';
import 'package:testagram/features/discovery/hashtag_screen.dart';

void main() {
  testWidgets('hashtag page follows and unfollows a topic', (tester) async {
    final methods = <String>[];
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getJwt: () async => 'appwrite-session-jwt',
      client: MockClient((request) async {
        methods.add('${request.method} ${request.url.path}');
        if (request.url.path == '/api/hashtags/Testagram') {
          return http.Response(jsonEncode({
            'ok': true,
            'data': {'tag': 'testagram', 'posts': [], 'has_more': false, 'next_cursor': '', 'is_following': false},
          }), 200);
        }
        if (request.url.path == '/api/hashtags/Testagram/follow') {
          return http.Response(jsonEncode({
            'ok': true,
            'data': {'tag': 'testagram', 'is_following': request.method == 'POST'},
          }), 200);
        }
        return http.Response(jsonEncode({'ok': false}), 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: HashtagScreen(api: api, tag: 'Testagram'),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();
    expect(find.text('Following'), findsOneWidget);

    await tester.tap(find.text('Following'));
    await tester.pumpAndSettle();
    expect(find.text('Follow'), findsOneWidget);
    expect(methods, [
      'GET /api/hashtags/Testagram',
      'POST /api/hashtags/Testagram/follow',
      'DELETE /api/hashtags/Testagram/follow',
    ]);
    api.close();
  });

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

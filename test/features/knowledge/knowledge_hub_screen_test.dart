import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:testagram/core/backend_api.dart';
import 'package:testagram/features/knowledge/knowledge_hub_screen.dart';

void main() {
  testWidgets('knowledge hub loads authenticated question lanes and exposes composer', (tester) async {
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getAccessToken: ({bool forceRefresh = false}) async => 'native-token',
      client: MockClient((request) async => http.Response(
        jsonEncode({'ok': true, 'data': {'items': [], 'has_more': false}}),
        200,
      )),
    );

    await tester.pumpWidget(MaterialApp(home: KnowledgeHubScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Knowledge'), findsOneWidget);
    expect(find.text('Topics'), findsOneWidget);
    expect(find.text('For you'), findsOneWidget);
    expect(find.text('Following'), findsOneWidget);
    expect(find.text('Topic feed'), findsOneWidget);
    expect(find.text('Unanswered'), findsOneWidget);
    expect(find.text('Your questions'), findsOneWidget);
    expect(find.text('Ask a question'), findsOneWidget);
    expect(find.text('No questions here yet.'), findsOneWidget);
    api.close();
  });

  testWidgets('question composer validates title and offers visibility controls', (tester) async {
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getAccessToken: ({bool forceRefresh = false}) async => 'native-token',
      client: MockClient((request) async => http.Response(
        jsonEncode({'ok': true, 'data': {'items': []}}),
        200,
      )),
    );

    await tester.pumpWidget(MaterialApp(home: KnowledgeHubScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask a question'));
    await tester.pumpAndSettle();

    expect(find.text('Ask the community'), findsOneWidget);
    expect(find.text('Who can see this?'), findsOneWidget);
    expect(find.text('Publish question'), findsOneWidget);
    api.close();
  });

  testWidgets('Knowledge topics can be discovered, followed and opened', (tester) async {
    var following = false;
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getAccessToken: ({bool forceRefresh = false}) async => 'native-token',
      client: MockClient((request) async {
        if (request.url.path == '/api/knowledge/topics' && request.method == 'GET') {
          return http.Response(jsonEncode({
            'ok': true,
            'data': {
              'items': [{
                'id': 'topic-1',
                'slug': 'kenya',
                'name': 'Kenya',
                'description': 'Questions and knowledge about Kenya.',
                'followers_count': 12,
                'questions_count': 4,
                'is_following': following,
              }],
              'has_more': false,
              'next_cursor': '',
            },
          }), 200);
        }
        if (request.url.path == '/api/knowledge/topics/kenya/follow' && request.method == 'POST') {
          following = true;
          return http.Response(jsonEncode({'ok': true, 'data': {'slug': 'kenya', 'is_following': true}}), 200);
        }
        if (request.url.path == '/api/knowledge/topics/kenya') {
          return http.Response(jsonEncode({
            'ok': true,
            'data': {
              'id': 'topic-1',
              'slug': 'kenya',
              'name': 'Kenya',
              'description': 'Questions and knowledge about Kenya.',
              'followers_count': 13,
              'questions_count': 4,
              'is_following': following,
            },
          }), 200);
        }
        return http.Response(jsonEncode({'ok': true, 'data': {'items': [], 'has_more': false}}), 200);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: KnowledgeHubScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Topics'));
    await tester.pumpAndSettle();

    expect(find.text('Kenya'), findsOneWidget);
    expect(find.textContaining('12 followers · 4 questions'), findsOneWidget);
    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();
    expect(find.text('Following'), findsNWidgets(2));

    await tester.tap(find.text('Kenya'));
    await tester.pumpAndSettle();
    expect(find.text('Questions and knowledge about Kenya.'), findsOneWidget);
    expect(find.text('13 followers · 4 questions'), findsOneWidget);
    api.close();
  });

  testWidgets('Knowledge question feeds load the next cursor page', (tester) async {
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getAccessToken: ({bool forceRefresh = false}) async => 'native-token',
      client: MockClient((request) async {
        if (request.url.path == '/api/knowledge/questions' &&
            request.url.queryParameters['before'] == 'opaque-page-two') {
          return http.Response(jsonEncode({
            'ok': true,
            'data': {
              'items': [{
                'id': 'question-2',
                'title': 'Second page question title',
                'body': '',
                'status': 'open',
                'answers_count': 0,
                'author': {'username': 'member-two'},
                'topics': [],
              }],
              'has_more': false,
              'next_cursor': '',
            },
          }), 200);
        }
        if (request.url.path == '/api/knowledge/questions') {
          return http.Response(jsonEncode({
            'ok': true,
            'data': {
              'items': [{
                'id': 'question-1',
                'title': 'First page question title',
                'body': '',
                'status': 'open',
                'answers_count': 0,
                'author': {'username': 'member-one'},
                'topics': [],
              }],
              'has_more': true,
              'next_cursor': 'opaque-page-two',
            },
          }), 200);
        }
        return http.Response(jsonEncode({'ok': true, 'data': {'items': []}}), 200);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: KnowledgeHubScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('First page question title'), findsOneWidget);
    expect(find.text('Load more questions'), findsOneWidget);
    await tester.tap(find.text('Load more questions'));
    await tester.pumpAndSettle();

    expect(find.text('First page question title'), findsOneWidget);
    expect(find.text('Second page question title'), findsOneWidget);
    expect(find.text('Load more questions'), findsNothing);
    api.close();
  });
}

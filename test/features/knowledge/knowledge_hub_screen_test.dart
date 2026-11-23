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
    expect(find.text('For you'), findsOneWidget);
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
}

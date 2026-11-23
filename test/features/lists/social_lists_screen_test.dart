import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:testagram/core/backend_api.dart';
import 'package:testagram/features/lists/social_lists_screen.dart';

void main() {
  testWidgets('Lists screen explains curated lists and opens creation flow', (tester) async {
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getAccessToken: ({bool forceRefresh = false}) async => 'native-token',
      client: MockClient((request) async => http.Response(
        jsonEncode({'ok': true, 'data': {'items': []}}),
        200,
      )),
    );

    await tester.pumpWidget(MaterialApp(home: SocialListsScreen(api: api, onSignOut: () async {})));
    await tester.pumpAndSettle();

    expect(find.text('Your lists'), findsOneWidget);
    expect(find.text('Organize the accounts you follow'), findsOneWidget);
    expect(find.text('Create your first list'), findsOneWidget);

    await tester.tap(find.text('Create your first list'));
    await tester.pumpAndSettle();
    expect(find.text('Create a list'), findsOneWidget);
    expect(find.text('Who can view this list?'), findsOneWidget);
    expect(find.text('Create list'), findsOneWidget);
    api.close();
  });
}

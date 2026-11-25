import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:testagram/core/backend_api.dart';
import 'package:testagram/features/settings/settings_screen.dart';

void main() {
  testWidgets('My profile opens the signed-in user profile through BackendApi',
      (tester) async {
    http.Request? captured;
    final client = MockClient((request) async {
      if (request.url.path == '/api/me/profile') {
        captured = request;
        return http.Response(
          jsonEncode({
            'ok': true,
            'data': {
              'id': 'canonical-user-123',
              'username': 'test_user',
              'display_name': 'Test User',
              'is_self': true,
              'can_view_posts': false,
              'followers_count': 3,
              'following_count': 5,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path ==
          '/api/social/profiles/canonical-user-123/posts') {
        return http.Response(
          jsonEncode({
            'ok': true,
            'data': {'posts': [], 'has_more': false},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    });
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.example'),
      getAccessToken: ({bool forceRefresh = false}) async => 'test-jwt',
      client: client,
    );

    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        api: api,
        themeMode: ThemeMode.system,
        onThemeModeChanged: (_) {},
        onSignOut: () async {},
      ),
    ));

    expect(find.text('My profile'), findsOneWidget);
    await tester.tap(find.text('My profile'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Test User'), findsOneWidget);
    expect(find.text('@test_user'), findsOneWidget);
    expect(captured?.url.path, '/api/me/profile');
    expect(captured?.headers['Authorization'], 'Bearer test-jwt');

    api.close();
  });
}

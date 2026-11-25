import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:testagram/core/backend_api.dart';
import 'package:testagram/features/profile/profile_screen.dart';

void main() {
  const userId = '123e4567-e89b-42d3-a456-426614174000';

  testWidgets('loads public profile posts when permission flag is omitted',
      (tester) async {
    final requests = <http.Request>[];
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.example'),
      getAccessToken: ({bool forceRefresh = false}) async => 'test-jwt',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/social/profiles/$userId') {
          return http.Response(jsonEncode({
            'ok': true,
            'data': {
              'id': userId,
              'username': 'public_member',
              'display_name': 'Public Member',
              'protected_account': false,
            },
          }), 200);
        }
        if (request.url.path == '/api/social/profiles/$userId/posts') {
          return http.Response(jsonEncode({
            'ok': true,
            'data': {
              'posts': [
                {
                  'id': 'post-1',
                  'content': 'A public image post',
                  'media_content_types': ['image/png'],
                  'likes_count': 2,
                },
              ],
              'has_more': false,
            },
          }), 200);
        }
        return http.Response('{}', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: ProfileScreen(api: api, userId: userId),
    ));
    await tester.pumpAndSettle();

    expect(
      requests.any((request) =>
          request.url.path == '/api/social/profiles/$userId/posts'),
      isTrue,
    );
    // The profile header is taller than a phone viewport; scroll the lazy
    // ListView before asserting that its post card has been built.
    await tester.scrollUntilVisible(
      find.text('A public image post'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('A public image post'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Media'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Media'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('A public image post'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('A public image post'), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    api.close();
  });

  testWidgets('does not request posts for a protected profile without access',
      (tester) async {
    final requests = <http.Request>[];
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.example'),
      getAccessToken: ({bool forceRefresh = false}) async => 'test-jwt',
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode({
          'ok': true,
          'data': {
            'id': userId,
            'username': 'private_member',
            'display_name': 'Private Member',
            'protected_account': true,
            'can_view_posts': false,
          },
        }), 200);
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: ProfileScreen(api: api, userId: userId),
    ));
    await tester.pumpAndSettle();

    expect(find.text('This account is private. Follow to see their posts.'),
        findsOneWidget);
    expect(
      requests.any((request) =>
          request.url.path == '/api/social/profiles/$userId/posts'),
      isFalse,
    );
    api.close();
  });
}

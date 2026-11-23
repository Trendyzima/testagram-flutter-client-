import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:testagram/core/backend_api.dart';
import 'package:testagram/features/settings/email_notification_settings_screen.dart';

void main() {
  testWidgets('asks before social emails and saves only the selected consent',
      (tester) async {
    final writes = <Map<String, dynamic>>[];
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getAccessToken: ({bool forceRefresh = false}) async => 'test-access-token',
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(jsonEncode({
            'ok': true,
            'data': {
              'new_follower_email_enabled': false,
              'new_post_email_enabled': false,
              'consent_prompt_required': true,
            },
          }), 200, headers: {'content-type': 'application/json'});
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        writes.add(body);
        return http.Response(jsonEncode({
          'ok': true,
          'data': {
            'new_follower_email_enabled': body['new_follower_email_enabled'],
            'new_post_email_enabled': body['new_post_email_enabled'],
            'consent_prompt_required': false,
          },
        }), 200, headers: {'content-type': 'application/json'});
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: EmailNotificationSettingsScreen(api: api),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Choose your email updates'), findsOneWidget);
    expect(find.textContaining('Nothing is emailed until you choose the categories and save your consent.'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    expect(find.text('Choose settings'), findsOneWidget);

    await tester.tap(find.text('Choose settings'));
    await tester.pumpAndSettle();

    expect(find.text('When someone follows me'), findsOneWidget);
    expect(find.text('New posts from people I follow'), findsOneWidget);

    await tester.tap(find.text('When someone follows me'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save my choices'));
    await tester.pumpAndSettle();

    expect(writes, hasLength(1));
    expect(writes.single['new_follower_email_enabled'], isTrue);
    expect(writes.single['new_post_email_enabled'], isFalse);
    expect(find.text('Your email preferences have been saved.'), findsOneWidget);
  });

  testWidgets('Not now records no consent and leaves both email categories off',
      (tester) async {
    final writes = <Map<String, dynamic>>[];
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getAccessToken: ({bool forceRefresh = false}) async => 'test-access-token',
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(jsonEncode({
            'ok': true,
            'data': {
              'new_follower_email_enabled': false,
              'new_post_email_enabled': false,
              'consent_prompt_required': true,
            },
          }), 200, headers: {'content-type': 'application/json'});
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        writes.add(body);
        return http.Response(jsonEncode({
          'ok': true,
          'data': {
            'new_follower_email_enabled': false,
            'new_post_email_enabled': false,
            'consent_prompt_required': false,
          },
        }), 200, headers: {'content-type': 'application/json'});
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: EmailNotificationSettingsScreen(api: api),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(writes, hasLength(1));
    expect(writes.single['new_follower_email_enabled'], isFalse);
    expect(writes.single['new_post_email_enabled'], isFalse);
    expect(find.text('Email updates remain off. You can change this any time.'), findsOneWidget);
  });
}

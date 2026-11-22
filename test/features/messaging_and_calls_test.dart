import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';

import 'package:testagram/core/backend_api.dart';
import 'package:testagram/features/messaging/inbox_screen.dart';
import 'package:testagram/features/messaging/conversation_screen.dart';
import 'package:testagram/features/calls/calls_screen.dart';

BackendApi _api(http.Client client) => BackendApi(
  baseUri: Uri.parse('https://api.testagram.site'),
  getAccessToken: ({bool forceRefresh = false}) async => 'test-jwt',
  client: client,
);

void main() {
  testWidgets('inbox lists conversations without exposing ciphertext previews', (tester) async {
    final api = _api(MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(request.url.path, '/api/capability');
      expect(body['capability'], 'testagram.conversations.list');
      return http.Response(jsonEncode({
        'items': [{
          'id': 'conversation-1',
          'kind': 'direct',
          'title': '',
          'members': [{'id': 'user-1', 'username': 'member_one', 'display_name': 'Member One'}],
          'unread_count': 2,
          'latest_message': {'ciphertext': 'never-render-this-ciphertext'},
        }],
      }), 200);
    }));

    await tester.pumpWidget(MaterialApp(home: InboxScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Member One'), findsOneWidget);
    expect(find.textContaining('Encrypted message'), findsOneWidget);
    expect(find.text('never-render-this-ciphertext'), findsNothing);
    expect(find.text('2'), findsOneWidget);
    api.close();
  });

  testWidgets('conversation displays encrypted placeholders and keeps sending locked', (tester) async {
    final requested = <String>[];
    final api = _api(MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final capability = body['capability'] as String;
      requested.add(capability);
      if (capability == 'testagram.messages.list') {
        return http.Response(jsonEncode({
          'items': [{
            'id': '11111111-1111-4111-8111-111111111111',
            'conversation_id': '22222222-2222-4222-8222-222222222222',
            'sender_id': '33333333-3333-4333-8333-333333333333',
            'body': '',
            'ciphertext': 'opaque-ciphertext',
            'nonce': 'opaque-nonce',
            'e2ee_enabled': true,
            'e2ee_version': 'v1',
            'e2ee_epoch': 1,
            'created_at': '2026-11-22T10:00:00Z',
            'sender': {'username': 'member_one', 'display_name': 'Member One'},
          }],
        }), 200);
      }
      if (capability == 'testagram.messages.mark_read') {
        return http.Response(jsonEncode({'read': true}), 200);
      }
      return http.Response('{}', 404);
    }));

    await tester.pumpWidget(MaterialApp(home: ConversationScreen(
      api: api,
      conversation: {'id': '22222222-2222-4222-8222-222222222222', 'kind': 'direct'},
    )));
    await tester.pumpAndSettle();

    expect(find.text('Encrypted payload — decryption unavailable'), findsOneWidget);
    expect(find.text('opaque-ciphertext'), findsNothing);
    expect(find.textContaining('Secure sending is locked'), findsOneWidget);
    expect(requested, contains('testagram.messages.mark_read'));
    expect(requested, isNot(contains('testagram.messages.send_encrypted')));
    api.close();
  });

  testWidgets('calls page loads authenticated call history and labels session type', (tester) async {
    final api = _api(MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (body['capability'] == 'testagram.conversations.list') {
        return http.Response(jsonEncode({
          'items': [{
            'id': '22222222-2222-4222-8222-222222222222',
            'kind': 'direct',
            'title': 'Private chat',
          }],
        }), 200);
      }
      if (body['capability'] == 'testagram.calls.list') {
        return http.Response(jsonEncode({
          'items': [{
            'id': '44444444-4444-4444-8444-444444444444',
            'kind': 'voice',
            'status': 'ended',
            'created_at': '2026-11-22T10:00:00Z',
            'e2ee_enabled': true,
          }],
        }), 200);
      }
      return http.Response('{}', 404);
    }));

    await tester.pumpWidget(MaterialApp(home: CallsScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Voice call'), findsOneWidget);
    expect(find.textContaining('Private chat'), findsOneWidget);
    expect(find.textContaining('Media encryption not active in this client'), findsOneWidget);
    api.close();
  });
}

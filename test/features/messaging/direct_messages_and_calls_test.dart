import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:testagram/core/backend_api.dart';
import 'package:testagram/features/calls/call_room_screen.dart';
import 'package:testagram/features/messaging/conversation_screen.dart';
import 'package:testagram/features/messaging/direct_messages_screen.dart';

class _CommunicationApi extends BackendApi {
  _CommunicationApi()
      : super(
          baseUri: Uri.parse('https://api.testagram.invalid'),
          getAccessToken: ({bool forceRefresh = false}) async => 'test-token',
        );

  int conversationListCalls = 0;
  int messageListCalls = 0;
  int callListCalls = 0;
  int markReadCalls = 0;

  @override
  Future<Map<String, dynamic>> listConversations({int limit = 50}) async {
    conversationListCalls++;
    return {'items': [
      {
        'id': 'conversation-1',
        'kind': 'direct',
        'title': 'A private conversation',
        'members': [],
        'unread_count': 2,
        'latest_message': {'ciphertext': 'opaque-ciphertext'},
      }
    ]};
  }

  @override
  Future<Map<String, dynamic>> listMessages(String conversationId, {int limit = 50, String? cursor}) async {
    messageListCalls++;
    return {'items': [
      {
        'id': 'message-1',
        'conversation_id': conversationId,
        'sender_id': 'user-2',
        'body': '',
        'ciphertext': 'opaque-ciphertext-never-render-this',
        'nonce': 'opaque-nonce',
        'e2ee_enabled': true,
        'created_at': '2026-11-22T10:00:00Z',
        'sender': {'display_name': 'Sender'},
      }
    ]};
  }

  @override
  Future<Map<String, dynamic>> markMessageRead(String messageId) async {
    markReadCalls++;
    return {'read': true};
  }

  @override
  Future<Map<String, dynamic>> listConversationCalls(String conversationId) async {
    callListCalls++;
    return {'items': [
      {
        'id': 'call-1',
        'kind': 'voice',
        'status': 'ended',
        'created_at': '2026-11-22T10:00:00Z',
      }
    ]};
  }
}

void main() {
  testWidgets('direct messages page loads real conversation rows', (tester) async {
    final api = _CommunicationApi();
    await tester.pumpWidget(MaterialApp(home: DirectMessagesScreen(api: api)));
    await tester.pumpAndSettle();

    expect(api.conversationListCalls, 1);
    expect(find.text('Direct messages'), findsOneWidget);
    expect(find.text('A private conversation'), findsOneWidget);
    expect(find.text('Encrypted message'), findsOneWidget);
  });

  testWidgets('conversation screen never renders encrypted payload bytes as plaintext', (tester) async {
    final api = _CommunicationApi();
    await tester.pumpWidget(MaterialApp(
      home: ConversationScreen(
        api: api,
        conversationId: 'conversation-1',
        title: 'Private chat',
      ),
    ));
    await tester.pumpAndSettle();

    expect(api.messageListCalls, 1);
    expect(api.markReadCalls, 1);
    expect(find.textContaining('Encrypted message'), findsOneWidget);
    expect(find.textContaining('opaque-ciphertext-never-render-this'), findsNothing);
    expect(find.textContaining('Secure message composition is paused'), findsOneWidget);
  });

  testWidgets('call room shows call history and keeps media start disabled', (tester) async {
    final api = _CommunicationApi();
    await tester.pumpWidget(MaterialApp(
      home: CallRoomScreen(
        api: api,
        conversationId: 'conversation-1',
        conversationTitle: 'Private chat',
      ),
    ));
    await tester.pumpAndSettle();

    expect(api.callListCalls, 1);
    expect(find.text('Call history'), findsOneWidget);
    expect(find.text('VOICE call'), findsOneWidget);
    final start = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(start.onPressed, isNull);
  });
}

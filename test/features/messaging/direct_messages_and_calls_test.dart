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
  List<String> createdMembers = [];

  @override
  Future<Map<String, dynamic>> listConversations({int limit = 50}) async {
    conversationListCalls++;
    return {'items': [
      {
        'id': 'conversation-1',
        'kind': 'direct',
        'title': '',
        'members': [
          {'display_name': 'My Own Name', 'username': 'my_name'},
          {'display_name': 'Peer Name', 'username': 'peer_name'},
        ],
        'other_members': [
          {'display_name': 'Peer Name', 'username': 'peer_name'},
        ],
        'unread_count': 2,
        'updated_at': '2026-11-25T10:30:00Z',
        'latest_message': {
          'id': 'message-preview-1',
          'sender_id': 'user-2',
          'created_at': '2026-11-25T10:30:00Z',
          'ciphertext': 'opaque-ciphertext',
          'e2ee_enabled': true,
          'e2ee_version': 'v1',
          'e2ee_epoch': 1,
        },
      }
    ]};
  }

  @override
  Future<Map<String, dynamic>> resolveProfileUsername(String username) async {
    return {'data': {'id': '123e4567-e89b-42d3-a456-426614174000', 'username': username}};
  }

  @override
  Future<Map<String, dynamic>> createConversation(List<String> memberIds, {String title = ''}) async {
    createdMembers = memberIds;
    return {'data': {'conversation_id': 'conversation-2'}};
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
        'e2ee_version': 'v1',
        'e2ee_epoch': 1,
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

class _UnverifiedEnvelopeCommunicationApi extends _CommunicationApi {
  @override
  Future<Map<String, dynamic>> listConversations({int limit = 50}) async {
    return {'items': [
      {
        'id': 'conversation-unverified',
        'kind': 'direct',
        'title': 'Unverified envelope',
        'members': [],
        'unread_count': 0,
        'latest_message': {'ciphertext': 'unverified-client-bytes'},
      }
    ]};
  }
}

class _PlaintextCommunicationApi extends _CommunicationApi {
  @override
  Future<Map<String, dynamic>> listMessages(String conversationId, {int limit = 50, String? cursor}) async {
    return {'items': [
      {
        'id': 'legacy-message',
        'conversation_id': conversationId,
        'sender_id': 'legacy-sender',
        'body': 'THIS LEGACY PLAINTEXT MUST NEVER BE SHOWN',
        'ciphertext': '',
        'nonce': '',
        'e2ee_enabled': false,
        'created_at': '2026-11-22T10:00:00Z',
        'sender': {'display_name': 'Legacy sender'},
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
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Peer Name'), findsOneWidget);
    expect(find.text('My Own Name'), findsNothing);
    expect(find.text('Encrypted message'), findsNothing);
    expect(find.textContaining('Open conversation'), findsOneWidget);
    expect(find.textContaining('Updated '), findsOneWidget);
  });

  testWidgets('inbox never infers E2EE from caller-supplied envelope fields', (tester) async {
    final api = _UnverifiedEnvelopeCommunicationApi();
    await tester.pumpWidget(MaterialApp(home: DirectMessagesScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Unverified envelope'), findsOneWidget);
    expect(find.text('Encrypted message'), findsNothing);
    expect(find.text('Open conversation'), findsOneWidget);
  });

  testWidgets('new direct message resolves a Testagram handle before creating a conversation', (tester) async {
    final api = _CommunicationApi();
    await tester.pumpWidget(MaterialApp(home: DirectMessagesScreen(api: api)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('New message'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'member_two');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(api.createdMembers, ['123e4567-e89b-42d3-a456-426614174000']);
    expect(find.text('member_two'), findsOneWidget);
    expect(api.messageListCalls, 1);
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
    expect(find.text('Message unavailable'), findsOneWidget);
    expect(find.textContaining('opaque-ciphertext-never-render-this'), findsNothing);
    expect(find.textContaining('Secure message composition is paused'), findsOneWidget);
  });

  testWidgets('conversation never displays legacy plaintext body when E2EE is absent', (tester) async {
    final api = _PlaintextCommunicationApi();
    await tester.pumpWidget(MaterialApp(
      home: ConversationScreen(
        api: api,
        conversationId: 'conversation-legacy',
        title: 'Legacy conversation',
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Message unavailable'), findsOneWidget);
    expect(find.text('THIS LEGACY PLAINTEXT MUST NEVER BE SHOWN'), findsNothing);
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
    await tester.scrollUntilVisible(find.text('Call history'), 250, scrollable: find.byType(Scrollable).first);
    expect(find.text('Call history'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('VOICE call'), 250, scrollable: find.byType(Scrollable).first);
    expect(find.text('VOICE call'), findsOneWidget);
    final start = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(start.onPressed, isNull);
  });
}
